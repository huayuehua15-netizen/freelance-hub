const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const User = require('../models/User');
const { generateAccessToken, generateRefreshToken, verifyRefreshToken } = require('../utils/jwt');
const config = require('../config/env');
const { ERROR_CODES } = require('../utils/constants');

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const validPassword = (password) =>
  typeof password === 'string' &&
  password.length >= 8 &&
  /[A-Za-z]/.test(password) &&
  /\d/.test(password);

const invalidCredentialsResponse = (res, message) => res.status(400).json({
  code: ERROR_CODES.BAD_REQUEST,
  msg: message,
  data: null,
  timestamp: Date.now(),
});

const register = async (req, res, next) => {
  try {
    const { email, password, userName, currency, timezone } = req.body;

    if (typeof email !== 'string' || !emailPattern.test(email.trim())) {
      return invalidCredentialsResponse(res, 'A valid email address is required');
    }
    if (!validPassword(password)) {
      return invalidCredentialsResponse(res, 'Password must be at least 8 characters and include a letter and a number');
    }
    if (userName != null && (typeof userName !== 'string' || userName.trim().length > 100)) {
      return invalidCredentialsResponse(res, 'User name must be 100 characters or fewer');
    }

    const existing = await User.findOne({ userEmail: email.toLowerCase() });
    if (existing) {
      // 软删除账号 30 天宽限期内的邮箱无法注册：可复活原账号继续使用（数据不丢）。
      if (!existing.isDeleted) {
        return res.status(409).json({
          code: ERROR_CODES.CONFLICT,
          msg: 'Email already registered',
          data: null,
          timestamp: Date.now(),
        });
      }
      // 复活：重置凭据，恢复为活跃状态；业务数据（项目/工时/开支）原样保留。
      existing.isDeleted = false;
      existing.deletedAt = null;
      existing.userName = userName?.trim() || existing.userName;
      existing.currency = currency || existing.currency;
      existing.timezone = timezone || existing.timezone;
      existing.passwordHash = await bcrypt.hash(password, config.bcryptRounds);
      existing.premiumType = config.isProd ? 'free' : 'annual';
      existing.expireTime = config.isProd ? null : Date.now() + 365 * 24 * 60 * 60 * 1000;

      const accessToken = generateAccessToken(existing.userId);
      const refreshToken = generateRefreshToken(existing.userId);
      existing.refreshToken = refreshToken;
      await existing.save();

      return res.status(200).json({
        code: ERROR_CODES.SUCCESS,
        msg: 'success',
        data: {
          userId: existing.userId,
          email: existing.userEmail,
          userName: existing.userName,
          premiumType: existing.premiumType,
          currency: existing.currency,
          timezone: existing.timezone,
          accessToken,
          refreshToken,
          expiresIn: 3600,
        },
        timestamp: Date.now(),
      });
    }

    const passwordHash = await bcrypt.hash(password, config.bcryptRounds);
    const userId = uuidv4();

    const user = await User.create({
      userId,
      userEmail: email.trim().toLowerCase(),
      userName: userName?.trim() || '',
      passwordHash,
      currency: currency || 'USD',
      timezone: timezone || 'America/New_York',
      // Demo：非生产环境默认 Annual（+1年有效期），便于演示云端同步与 Web 后台；
      // 生产环境走 RevenueCat 真实订阅，注册默认为 free。
      premiumType: config.isProd ? 'free' : 'annual',
      expireTime: config.isProd ? null : Date.now() + 365 * 24 * 60 * 60 * 1000,
    });

    const accessToken = generateAccessToken(userId);
    const refreshToken = generateRefreshToken(userId);

    user.refreshToken = refreshToken;
    await user.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: 'success',
      data: {
        userId: user.userId,
        email: user.userEmail,
        userName: user.userName,
        premiumType: user.premiumType,
        currency: user.currency,
        timezone: user.timezone,
        accessToken,
        refreshToken,
        expiresIn: 3600,
      },
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (typeof email !== 'string' || !emailPattern.test(email.trim()) || typeof password !== 'string' || !password) {
      return invalidCredentialsResponse(res, 'Email and password are required');
    }

    const user = await User.findOne({ userEmail: email.trim().toLowerCase(), isDeleted: false });
    if (!user) {
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: 'Invalid email or password',
        data: null,
        timestamp: Date.now(),
      });
    }

    const isValid = await bcrypt.compare(password, user.passwordHash);
    if (!isValid) {
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: 'Invalid email or password',
        data: null,
        timestamp: Date.now(),
      });
    }

    const accessToken = generateAccessToken(user.userId);
    const refreshToken = generateRefreshToken(user.userId);

    user.refreshToken = refreshToken;
    await user.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: 'success',
      data: {
        userId: user.userId,
        email: user.userEmail,
        userName: user.userName,
        premiumType: user.premiumType,
        expireTime: user.expireTime,
        currency: user.currency,
        timezone: user.timezone,
        accessToken,
        refreshToken,
        expiresIn: 3600,
      },
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

const refresh = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: 'Refresh token required',
        data: null,
        timestamp: Date.now(),
      });
    }

    const decoded = verifyRefreshToken(refreshToken);
    const user = await User.findOne({ userId: decoded.userId, isDeleted: false });

    if (!user || user.refreshToken !== refreshToken) {
      return res.status(401).json({
        code: ERROR_CODES.REFRESH_TOKEN_EXPIRED,
        msg: 'Refresh token expired or invalid, please login again',
        data: null,
        timestamp: Date.now(),
      });
    }

    const newAccessToken = generateAccessToken(user.userId);
    const newRefreshToken = generateRefreshToken(user.userId);

    user.refreshToken = newRefreshToken;
    await user.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: 'success',
      data: {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresIn: 3600,
      },
      timestamp: Date.now(),
    });
  } catch (error) {
    return res.status(401).json({
      code: ERROR_CODES.REFRESH_TOKEN_EXPIRED,
      msg: 'Refresh token expired, please login again',
      data: null,
      timestamp: Date.now(),
    });
  }
};

const getMe = async (req, res) => {
  const user = req.user;
  return res.status(200).json({
    code: ERROR_CODES.SUCCESS,
    msg: 'success',
    data: {
      userId: user.userId,
      email: user.userEmail,
      userName: user.userName,
      premiumType: user.premiumType,
      expireTime: user.expireTime,
      trialEndTime: user.trialEndTime,
      currency: user.currency,
      timezone: user.timezone,
      lastSyncTime: user.lastSyncTime,
    },
    timestamp: Date.now(),
  });
};

const logout = async (req, res) => {
  req.user.refreshToken = null;
  await req.user.save();
  return res.status(200).json({
    code: ERROR_CODES.SUCCESS,
    msg: 'Logged out successfully',
    data: null,
    timestamp: Date.now(),
  });
};

const deleteAccount = async (req, res) => {
  req.user.isDeleted = true;
  req.user.deletedAt = new Date();
  req.user.refreshToken = null;
  await req.user.save();
  return res.status(200).json({
    code: ERROR_CODES.SUCCESS,
    msg: 'Account scheduled for deletion. Data will be permanently removed after 30 days.',
    data: null,
    timestamp: Date.now(),
  });
};

module.exports = { register, login, refresh, getMe, logout, deleteAccount };
