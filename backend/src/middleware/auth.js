const { verifyAccessToken } = require('../utils/jwt');
const { ERROR_CODES } = require('../utils/constants');
const { t } = require('../utils/i18n');
const User = require('../models/User');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: t('errors.auth.tokenRequired', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyAccessToken(token);

    const user = await User.findOne({ userId: decoded.userId, isDeleted: false });
    if (!user) {
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: t('errors.auth.userNotFound', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    // An expiry webhook can be delayed or temporarily unavailable.  Never
    // continue granting paid API access merely because the persisted plan name
    // has not yet been updated by RevenueCat.
    if (user.premiumType !== 'free' &&
        user.expireTime != null &&
        user.expireTime <= Date.now()) {
      user.premiumType = 'free';
      user.expireTime = null;
      user.trialEndTime = null;
      await user.save();
    }

    req.user = user;
    req.userId = user.userId;
    next();
  } catch (error) {
    // 只有 token 本身的问题才是 401。DB 瞬时故障（上面 findOne/save 因网络
    // 抖动失败）必须走 5xx：客户端对 401 的处理是判定会话失效并登出，把
    // 一次可恢复的网络抖动变成演示中途被踢下线。
    if (error?.name === 'JsonWebTokenError' || error?.name === 'TokenExpiredError' || error?.name === 'NotBeforeError') {
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: t('errors.auth.invalidToken', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    next(error);
  }
};

module.exports = authMiddleware;
