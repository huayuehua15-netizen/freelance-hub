const { ERROR_CODES, PREMIUM_TYPES } = require('../utils/constants');
const { t } = require('../utils/i18n');

const getEntitlement = async (req, res) => {
  const user = req.user;
  const isPremium = user.premiumType !== PREMIUM_TYPES.FREE;
  const isAnnual = user.premiumType === PREMIUM_TYPES.ANNUAL;
  const isTrial = user.trialEndTime && user.trialEndTime > Date.now();

  return res.status(200).json({
    code: ERROR_CODES.SUCCESS,
    msg: t('common.success', req.lang),
    data: {
      premiumType: user.premiumType,
      expireTime: user.expireTime,
      isTrial,
      trialEndTime: user.trialEndTime,
      entitlements: {
        unlimitedProjects: isPremium,
        monthlyReport: isPremium,
        annualReport: isAnnual,
        pdfExport: isPremium,
        cloudSync: isAnnual,
        webAccess: isAnnual,
        batchArchive: isAnnual,
        customTaxCategory: isAnnual,
      },
    },
    timestamp: Date.now(),
  });
};

module.exports = { getEntitlement };
