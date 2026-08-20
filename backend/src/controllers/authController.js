const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const { DateTime } = require('luxon');
const User = require('../models/User');
const { generateAccessToken, generateRefreshToken, verifyRefreshToken } = require('../utils/jwt');
const config = require('../config/env');
const { ERROR_CODES } = require('../utils/constants');
const { t } = require('../utils/i18n');
const emailService = require('../services/emailService');
const logger = require('../utils/logger');

// refresh token 只存 SHA-256 哈希：数据库泄露时不暴露 30 天有效凭证，
// 客户端仍持有明文 token，校验时哈希比对，轮换逻辑不变。
const hashToken = (token) => crypto.createHash('sha256').update(String(token)).digest('hex');
const newOpaqueToken = () => crypto.randomBytes(32).toString('hex');
const RESET_TTL_MS = 60 * 60 * 1000;
// 邮箱验证 token 24h 过期：与重置 token 一致引入失效机制，避免验证链接永久有效
const VERIFY_TTL_MS = 24 * 60 * 60 * 1000;

// accessToken 有效期（秒），与 JWT_ACCESS_EXPIRES 保持一致（支持 1h/30m 等格式）
const accessExpiresSeconds = (() => {
  const raw = config.jwt.accessExpires;
  const m = /^(\d+)([smhd])$/.exec(String(raw));
  if (!m) return 3600;
  const unit = { s: 1, m: 60, h: 3600, d: 86400 }[m[2]];
  return parseInt(m[1], 10) * unit;
})();

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const validPassword = (password) =>
  typeof password === 'string' &&
  password.length >= 8 &&
  /[A-Za-z]/.test(password) &&
  /\d/.test(password);
// 时区必须是合法 IANA 标识（如 'America/New_York'），否则后续报表会归错月份。
const isValidTimezone = (tz) => typeof tz === 'string' && DateTime.now().setZone(tz).isValid;
// 货币必须是 3 位大写 ISO 4217 代码（如 'USD'、'EUR'）。
const isValidCurrency = (c) => typeof c === 'string' && /^[A-Z]{3}$/.test(c);

// 注意：本 helper 不接 req，故调用方需先 t(key, req.lang) 再传入。
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
      return invalidCredentialsResponse(res, t('errors.validation.emailRequired', req.lang));
    }
    if (!validPassword(password)) {
      return invalidCredentialsResponse(res, t('errors.validation.passwordInvalid', req.lang));
    }
    if (userName != null && (typeof userName !== 'string' || userName.trim().length > 100)) {
      return invalidCredentialsResponse(res, t('errors.validation.userNameTooLong', req.lang));
    }
    // timezone/currency 仅在用户显式传入时校验，非法值直接拒绝，避免后续报表归类错误
    if (timezone != null && !isValidTimezone(timezone)) {
      return invalidCredentialsResponse(res, t('errors.validation.invalidTimezone', req.lang));
    }
    if (currency != null && !isValidCurrency(currency)) {
      return invalidCredentialsResponse(res, t('errors.validation.invalidCurrency', req.lang));
    }

    // 查重必须与存储归一化一致(trim+lowercase)，否则带空格的邮箱会绕过复活分支、撞 unique 索引
    const existing = await User.findOne({ userEmail: email.trim().toLowerCase() });
    if (existing) {
      // 软删除账号 30 天宽限期内的邮箱无法注册：可复活原账号继续使用（数据不丢）。
      if (!existing.isDeleted) {
        return res.status(409).json({
          code: ERROR_CODES.CONFLICT,
          msg: t('errors.auth.emailExists', req.lang),
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
      // 演示开关显式开启时才默认 annual；否则一律 free（防误上线全员年卡）
      existing.premiumType = config.demoAnnualByDefault ? 'annual' : 'free';
      existing.expireTime = config.demoAnnualByDefault ? Date.now() + 365 * 24 * 60 * 60 * 1000 : null;
      // 复活时重置邮箱验证状态：旧 token 已失效/过期，残留会导致横幅状态错乱
      if (!existing.emailVerified) {
        existing.emailVerifyTokenHash = null;
        existing.emailVerifyExpiresAt = null;
        existing.lastVerificationSentAt = null;
        const verifyToken = newOpaqueToken();
        existing.emailVerifyTokenHash = hashToken(verifyToken);
        existing.emailVerifyExpiresAt = new Date(Date.now() + VERIFY_TTL_MS);
        existing.lastVerificationSentAt = new Date();
        // 非阻断：发送失败不影响注册成功，客户端可稍后重发
        emailService.sendVerificationEmail(
          existing,
          `${config.clientUrl}/verify-email?token=${verifyToken}`
        ).catch((err) => logger.warn(`verification email (reactivated) failed: ${err.message}`));
      }

      const accessToken = generateAccessToken(existing.userId);
      const refreshToken = generateRefreshToken(existing.userId);
      existing.refreshToken = hashToken(refreshToken);
      await existing.save();

      return res.status(200).json({
        code: ERROR_CODES.SUCCESS,
        msg: t('common.success', req.lang),
        data: {
          userId: existing.userId,
          email: existing.userEmail,
          userName: existing.userName,
          premiumType: existing.premiumType,
          currency: existing.currency,
          timezone: existing.timezone,
          emailVerified: existing.emailVerified === true,
          emailVerificationAvailable: emailService.isConfigured(),
          accessToken,
          refreshToken,
          expiresIn: accessExpiresSeconds,
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
      // 演示开关显式开启时才默认 annual；否则一律 free（防误上线全员年卡）
      premiumType: config.demoAnnualByDefault ? 'annual' : 'free',
      expireTime: config.demoAnnualByDefault ? Date.now() + 365 * 24 * 60 * 60 * 1000 : null,
    });

    const accessToken = generateAccessToken(userId);
    const refreshToken = generateRefreshToken(userId);

    user.refreshToken = hashToken(refreshToken);

    // 邮箱验证（非阻断）：发验证邮件但绝不阻塞注册成功——发送失败/
    // 未配置 SMTP 时用户照常使用，之后可在客户端重发。
    const verifyToken = newOpaqueToken();
    user.emailVerifyTokenHash = hashToken(verifyToken);
    user.emailVerifyExpiresAt = new Date(Date.now() + VERIFY_TTL_MS);
    user.lastVerificationSentAt = new Date();
    await user.save();
    emailService.sendVerificationEmail(
      user,
      `${config.clientUrl}/verify-email?token=${verifyToken}`
    ).catch((err) => logger.warn(`verification email failed: ${err.message}`));

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('common.success', req.lang),
      data: {
        userId: user.userId,
        email: user.userEmail,
        userName: user.userName,
        premiumType: user.premiumType,
        currency: user.currency,
        timezone: user.timezone,
        emailVerified: user.emailVerified === true,
        emailVerificationAvailable: emailService.isConfigured(),
        accessToken,
        refreshToken,
        expiresIn: accessExpiresSeconds,
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
      return invalidCredentialsResponse(res, t('errors.validation.emailPasswordRequired', req.lang));
    }

    const user = await User.findOne({ userEmail: email.trim().toLowerCase(), isDeleted: false });
    if (!user) {
      // 防用户枚举时序攻击：不存在的邮箱也执行一次等代价的 bcrypt 比较，
      // 使两种失败路径的响应时间一致。
      await bcrypt.compare(password, '$2a$12$C6UzMDM.H6dfI/f/IKcEeO7ZBk3W1j0p0Pq9U8wJ5n2sYbVxLmNq');
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: t('errors.auth.invalidCredentials', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    const isValid = await bcrypt.compare(password, user.passwordHash);
    if (!isValid) {
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: t('errors.auth.invalidCredentials', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    const accessToken = generateAccessToken(user.userId);
    const refreshToken = generateRefreshToken(user.userId);

    user.refreshToken = hashToken(refreshToken);
    await user.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('common.success', req.lang),
      data: {
        userId: user.userId,
        email: user.userEmail,
        userName: user.userName,
        premiumType: user.premiumType,
        expireTime: user.expireTime,
        currency: user.currency,
        timezone: user.timezone,
        emailVerified: user.emailVerified === true,
        emailVerificationAvailable: emailService.isConfigured(),
        accessToken,
        refreshToken,
        expiresIn: accessExpiresSeconds,
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
        msg: t('errors.auth.refreshTokenRequired', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    const decoded = verifyRefreshToken(refreshToken);

    // 原子轮换:条件带 refreshToken 哈希,只有持有旧 token 的请求能成功
    // 并发场景下第二个请求 matchedCount=0 → 401,客户端走重新登录,杜绝互相覆盖产生孤儿 token
    const newAccessToken = generateAccessToken(decoded.userId);
    const newRefreshToken = generateRefreshToken(decoded.userId);

    const updated = await User.findOneAndUpdate(
      { userId: decoded.userId, isDeleted: false, refreshToken: hashToken(refreshToken) },
      { $set: { refreshToken: hashToken(newRefreshToken) } },
      { new: true }
    );

    if (!updated) {
      return res.status(401).json({
        code: ERROR_CODES.REFRESH_TOKEN_EXPIRED,
        msg: t('errors.auth.refreshTokenInvalid', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('common.success', req.lang),
      data: {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresIn: accessExpiresSeconds,
      },
      timestamp: Date.now(),
    });
  } catch (error) {
    // 仅 token 本身的校验失败映射为 401；数据库等服务器故障走 500，
    // 避免把后端故障误报为"会话过期"触发客户端登出。
    if (error && ['JsonWebTokenError', 'TokenExpiredError', 'NotBeforeError'].includes(error.name)) {
      return res.status(401).json({
        code: ERROR_CODES.REFRESH_TOKEN_EXPIRED,
        msg: t('errors.auth.refreshTokenExpired', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    return next(error);
  }
};

const getMe = async (req, res) => {
  const user = req.user;
  return res.status(200).json({
    code: ERROR_CODES.SUCCESS,
    msg: t('common.success', req.lang),
    data: {
      userId: user.userId,
      email: user.userEmail,
      userName: user.userName,
      premiumType: user.premiumType,
      expireTime: user.expireTime,
      trialEndTime: user.trialEndTime,
      emailVerified: user.emailVerified === true,
      // SMTP 未配置时验证不可用：客户端据此隐藏验证横幅（避免无法完成的引导）
      emailVerificationAvailable: emailService.isConfigured(),
      currency: user.currency,
      timezone: user.timezone,
      lastSyncTime: user.lastSyncTime,
    },
    timestamp: Date.now(),
  });
};

const logout = async (req, res, next) => {
  try {
    req.user.refreshToken = null;
    await req.user.save();
    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('auth.loggedOut', req.lang),
      data: null,
      timestamp: Date.now(),
    });
  } catch (error) {
    return next(error);
  }
};

const deleteAccount = async (req, res, next) => {
  try {
    // 密码二次验证：access token 有效期 1 小时，被盗设备上的有效会话
    // 不应能直接删除账号（GDPR 删除权 vs 账户安全的平衡）。
    const { currentPassword } = req.body || {};
    if (typeof currentPassword !== 'string' || !currentPassword) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.auth.passwordRequired', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    const passwordOk = await bcrypt.compare(currentPassword, req.user.passwordHash);
    if (!passwordOk) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.auth.passwordMismatch', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    req.user.isDeleted = true;
    req.user.deletedAt = new Date();
    req.user.refreshToken = null;
    await req.user.save();
    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('auth.accountDeletionScheduled', req.lang),
      data: null,
      timestamp: Date.now(),
    });
  } catch (error) {
    return next(error);
  }
};

// ── 忘记密码 / 重置密码 / 邮箱验证 ─────────────────────────────

/**
 * 忘记密码：无论邮箱是否存在都返回 200（防账号枚举）。
 * 真实用户 → 生成一次性 token（明文仅存在于邮件链接，库存 32 字节哈希，
 * 1 小时过期），重复请求会覆盖旧 token（旧链接自动作废）。
 */
const forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;
    if (typeof email !== 'string' || !emailPattern.test(email.trim())) {
      return invalidCredentialsResponse(res, t('errors.validation.emailRequired', req.lang));
    }

    const user = await User.findOne({ userEmail: email.trim().toLowerCase(), isDeleted: false });
    if (user) {
      const token = newOpaqueToken();
      user.resetTokenHash = hashToken(token);
      user.resetTokenExpiresAt = new Date(Date.now() + RESET_TTL_MS);
      await user.save();
      emailService.sendPasswordResetEmail(
        user,
        `${config.clientUrl}/reset-password?token=${token}`
      ).catch((err) => logger.warn(`reset email failed for ${user.userId}: ${err.message}`));
    }
    // 统一响应，不泄露账号是否存在
    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('auth.resetLinkSent', req.lang),
      data: null,
      timestamp: Date.now(),
    });
  } catch (error) {
    return next(error);
  }
};

/**
 * 重置密码：校验 token 哈希 + 有效期，设置新密码，吊销全部现有会话
 * （refreshToken 置空），签发新会话（用户重置后自动登录），并顺带
 * 完成邮箱所有权验证（能收到重置邮件 = 邮箱真实属于该用户）。
 */
const resetPassword = async (req, res, next) => {
  try {
    const { token, newPassword } = req.body;
    if (typeof token !== 'string' || !token) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.auth.resetTokenInvalid', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    if (!validPassword(newPassword)) {
      return invalidCredentialsResponse(res, t('errors.validation.passwordInvalid', req.lang));
    }

    const user = await User.findOne({
      resetTokenHash: hashToken(token),
      isDeleted: false,
      resetTokenExpiresAt: { $gt: new Date() },
    });
    if (!user) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.auth.resetTokenInvalid', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    user.passwordHash = await bcrypt.hash(newPassword, config.bcryptRounds);
    user.resetTokenHash = null;
    user.resetTokenExpiresAt = null;
    user.emailVerified = true;
    // 自动登录：重置成功即签发新会话，免去用户再输一遍新密码
    const accessToken = generateAccessToken(user.userId);
    const refreshToken = generateRefreshToken(user.userId);
    user.refreshToken = hashToken(refreshToken);
    await user.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('auth.passwordResetSuccess', req.lang),
      data: {
        userId: user.userId,
        email: user.userEmail,
        accessToken,
        refreshToken,
        expiresIn: accessExpiresSeconds,
      },
      timestamp: Date.now(),
    });
  } catch (error) {
    return next(error);
  }
};

/** 邮箱验证落地：token 一次性使用，成功后清除。 */
const verifyEmail = async (req, res, next) => {
  try {
    const { token } = req.body;
    if (typeof token !== 'string' || !token) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.auth.verificationTokenInvalid', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    const user = await User.findOne({
      emailVerifyTokenHash: hashToken(token),
      isDeleted: false,
      // 24h 过期校验；$or 兼容历史数据 null（老 token 仍可验证，新 token 一律带过期时间）
      $or: [{ emailVerifyExpiresAt: null }, { emailVerifyExpiresAt: { $gt: new Date() } }],
    });
    if (!user) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.auth.verificationTokenInvalid', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    user.emailVerified = true;
    user.emailVerifyTokenHash = null;
    user.lastVerificationSentAt = null;
    await user.save();
    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('auth.emailVerified', req.lang),
      data: { email: user.userEmail },
      timestamp: Date.now(),
    });
  } catch (error) {
    return next(error);
  }
};

/** 重发验证邮件（已登录，60s 内只允许一次）。 */
const resendVerification = async (req, res, next) => {
  try {
    const user = req.user;
    if (user.emailVerified) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.auth.alreadyVerified', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    // 简易防轰炸：60 秒内重复请求直接拒绝。
    // 用独立字段 lastVerificationSentAt（而非 serverUpdateTime）——后者由 Mongoose
    // timestamps 维护，任何资料保存都会刷新它，会误刷新/绕过限频窗口。
    const lastSent = user.lastVerificationSentAt ? new Date(user.lastVerificationSentAt).getTime() : 0;
    if (Date.now() - lastSent < 60 * 1000) {
      return res.status(429).json({
        code: ERROR_CODES.RATE_LIMIT,
        msg: t('errors.rateLimit.tooMany', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    const token = newOpaqueToken();
    user.emailVerifyTokenHash = hashToken(token);
    user.emailVerifyExpiresAt = new Date(Date.now() + VERIFY_TTL_MS);
    user.lastVerificationSentAt = new Date();
    await user.save();
    emailService.sendVerificationEmail(user, `${config.clientUrl}/verify-email?token=${token}`)
      .catch((err) => logger.warn(`resend verification failed: ${err.message}`));
    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('auth.verificationSent', req.lang),
      data: null,
      timestamp: Date.now(),
    });
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  register,
  login,
  refresh,
  getMe,
  logout,
  deleteAccount,
  forgotPassword,
  resetPassword,
  verifyEmail,
  resendVerification,
};
