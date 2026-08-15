const { ERROR_CODES, PREMIUM_TYPES } = require('../utils/constants');
const { t } = require('../utils/i18n');

const PREMIUM_LEVELS = {
  [PREMIUM_TYPES.FREE]: 0,
  [PREMIUM_TYPES.MONTHLY]: 1,
  [PREMIUM_TYPES.ANNUAL]: 2,
};

const requirePremium = (minLevel) => {
  return (req, res, next) => {
    const user = req.user;
    if (!user) {
      return res.status(401).json({
        code: ERROR_CODES.UNAUTHORIZED,
        msg: t('errors.auth.authenticationRequired', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    const userLevel = PREMIUM_LEVELS[user.premiumType] || 0;
    const requiredLevel = PREMIUM_LEVELS[minLevel] || 0;

    if (userLevel < requiredLevel) {
      let errorCode = ERROR_CODES.NEED_MONTHLY;
      let msg = t('errors.premium.requiresMonthly', req.lang);

      if (minLevel === PREMIUM_TYPES.ANNUAL) {
        errorCode = ERROR_CODES.NEED_ANNUAL;
        msg = t('errors.premium.requiresAnnual', req.lang);
      }

      return res.status(403).json({
        code: errorCode,
        msg,
        data: null,
        timestamp: Date.now(),
      });
    }

    next();
  };
};

const requireMonthly = requirePremium(PREMIUM_TYPES.MONTHLY);
const requireAnnual = requirePremium(PREMIUM_TYPES.ANNUAL);

module.exports = { requirePremium, requireMonthly, requireAnnual };
