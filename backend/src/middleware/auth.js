const { verifyAccessToken } = require('../utils/jwt');
const { ERROR_CODES } = require('../utils/constants');
const User = require('../models/User');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: 'Authorization token required',
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
        msg: 'User not found',
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
    return res.status(401).json({
      code: ERROR_CODES.UNAUTHORIZED,
      msg: 'Invalid or expired token',
      data: null,
      timestamp: Date.now(),
    });
  }
};

module.exports = authMiddleware;
