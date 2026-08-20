const { ERROR_CODES, PREMIUM_TYPES } = require('../utils/constants');
const { t } = require('../utils/i18n');
const logger = require('../utils/logger');
const { verifyAndSync } = require('../services/revenuecatService');

// getEntitlement 是移动端启动/进入付费页时的低频接口，适合触发 RevenueCat 出站校验：
// 调 RC API 实时校验订阅状态并同步本地，防止 webhook 延迟/丢失导致的状态过期。
// 校验本身 fail-open（RC 不可达沿用本地），不会阻断本接口。
const getEntitlement = async (req, res) => {
  const user = req.user;
  try {
    await verifyAndSync(user);
  } catch (e) {
    // 出站校验异常不应阻断 entitlement 查询，沿用本地状态
    logger.warn(`verifyAndSync error for ${user.userId}: ${e.message}`);
  }

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
