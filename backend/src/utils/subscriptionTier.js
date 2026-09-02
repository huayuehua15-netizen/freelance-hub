const { PREMIUM_TYPES } = require('./constants');

/**
 * RevenueCat 档位映射（单一真相源，webhook 与出站校验共用）。
 *
 * 判定优先级：
 * 1. entitlement ID 精确匹配（RevenueCat 后台 Entitlements 配置，
 *    见 deploy/LAUNCH_CHECKLIST.md：annual_pro / monthly_premium）
 * 2. product ID 子串匹配（小写化后含 annual/yearly/monthly）
 *
 * 历史教训：旧实现直接对原始 product_id 做 includes('annual')，
 * 大小写或命名（如 *_yearly）稍有出入即解析为 null —— INITIAL_PURCHASE
 * 照发 expireTime 但 premiumType 停在 free，付费用户拿不到权益且无自愈。
 */
const TIER_BY_ENTITLEMENT = {
  annual_pro: PREMIUM_TYPES.ANNUAL,
  monthly_premium: PREMIUM_TYPES.MONTHLY,
};

const tierFromIdentifier = (productId, entitlementIds = []) => {
  for (const id of entitlementIds) {
    const key = String(id || '').trim().toLowerCase();
    if (TIER_BY_ENTITLEMENT[key]) return TIER_BY_ENTITLEMENT[key];
  }
  if (!productId) return null;
  const pid = String(productId).trim().toLowerCase();
  if (pid.includes('annual') || pid.includes('yearly')) return PREMIUM_TYPES.ANNUAL;
  if (pid.includes('monthly')) return PREMIUM_TYPES.MONTHLY;
  return null;
};

module.exports = { tierFromIdentifier };
