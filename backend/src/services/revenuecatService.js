const config = require('../config/env');
const logger = require('../utils/logger');
const { PREMIUM_TYPES } = require('../utils/constants');

const RC_API_BASE = 'https://api.revenuecat.com/v1';
// 出站校验缓存窗口：同用户 5 分钟内不重复调 RC API，避免配额耗尽与延迟叠加
const CACHE_TTL_MS = 5 * 60 * 1000;
const REQUEST_TIMEOUT_MS = 8000;

// 内存缓存：userId -> 下次允许调用 RC API 的时间戳
// 仅缓存“何时再调 RC”，不缓存订阅状态本身——状态始终以本地 DB 为准（被 verifyAndSync 同步）
const cache = new Map();

const isConfigured = () => {
  const key = config.revenuecat.apiKey;
  // 'dev_api_key' 是 env.js 的默认占位符，视为未配置
  return typeof key === 'string' && key.trim() !== '' && key !== 'dev_api_key';
};

/**
 * 调用 RevenueCat REST API 获取订阅者实时状态。
 * GET /v1/subscribers/{app_user_id}
 * 认证：Authorization: Bearer {secret_api_key}
 *
 * @param {string} appUserId RevenueCat 的 app_user_id（本系统即 user.userId）
 * @returns {Promise<object|null>} subscriber 对象；调用失败返回 null（fail-open）
 */
const fetchSubscriber = async (appUserId) => {
  const key = config.revenuecat.apiKey;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const res = await fetch(`${RC_API_BASE}/subscribers/${encodeURIComponent(appUserId)}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${key}`,
        'X-Platform': 'android',
        'Content-Type': 'application/json',
      },
      signal: controller.signal,
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      logger.warn(`RevenueCat API ${res.status} for ${appUserId}: ${body.slice(0, 200)}`);
      return null;
    }
    const json = await res.json();
    return json?.subscriber || null;
  } catch (e) {
    const msg = e.name === 'AbortError' ? `timeout after ${REQUEST_TIMEOUT_MS}ms` : e.message;
    logger.warn(`RevenueCat API call failed for ${appUserId}: ${msg}`);
    return null;
  } finally {
    clearTimeout(timer);
  }
};

/**
 * 从 RC subscriber 对象解析出本地应持久化的订阅状态。
 * 优先读 entitlements（RC 后台配置的权益），fallback 读 subscriptions。
 *
 * 判定规则：
 * - 遍历 entitlements，取第一个 is_active 的，据 product_identifier 判 monthly/annual
 * - 无 active entitlement 时查 subscriptions
 * - expiration_date 已过视为失效
 * - 都无 active → FREE
 *
 * @param {object} subscriber RC 返回的 subscriber 对象
 * @returns {{premiumType: string, expireTime: number|null}}
 */
const resolveEntitlement = (subscriber) => {
  if (!subscriber || typeof subscriber !== 'object') {
    return { premiumType: PREMIUM_TYPES.FREE, expireTime: null };
  }

  const now = Date.now();
  const entitlements = subscriber.entitlements || {};
  const subs = subscriber.subscriptions || {};

  let activeProduct = null;
  let activeExpiration = null;

  // 1) entitlements 优先
  for (const [id, ent] of Object.entries(entitlements)) {
    if (ent && ent.is_active) {
      activeProduct = ent.product_identifier || id;
      activeExpiration = ent.expiration_date ? new Date(ent.expiration_date).getTime() : null;
      break;
    }
  }

  // 2) fallback：subscriptions
  if (!activeProduct) {
    for (const [id, sub] of Object.entries(subs)) {
      if (sub && sub.is_active) {
        activeProduct = id;
        activeExpiration = sub.expires_date ? new Date(sub.expires_date).getTime() : null;
        break;
      }
    }
  }

  if (!activeProduct) {
    return { premiumType: PREMIUM_TYPES.FREE, expireTime: null };
  }

  const pid = String(activeProduct).toLowerCase();
  let premiumType = PREMIUM_TYPES.FREE;
  if (pid.includes('annual')) {
    premiumType = PREMIUM_TYPES.ANNUAL;
  } else if (pid.includes('monthly')) {
    premiumType = PREMIUM_TYPES.MONTHLY;
  }

  // 过期时间已过 → 视为失效（RC 通常也会把 is_active 置 false，这里双保险）
  if (activeExpiration && activeExpiration <= now) {
    return { premiumType: PREMIUM_TYPES.FREE, expireTime: null };
  }

  return { premiumType, expireTime: activeExpiration };
};

const hasChanged = (user, resolved) =>
  user.premiumType !== resolved.premiumType ||
  (user.expireTime || null) !== (resolved.expireTime || null);

/**
 * 出站校验：调 RC API 校验订阅状态，与本地不一致则同步更新。
 *
 * 设计原则：
 * - 低频触发（仅 getEntitlement 接口），避免每请求调 RC
 * - 5 分钟内存缓存，防止短时间重复调用打爆 RC 配额
 * - fail-open：RC 不可达 / key 未配置 / 响应异常 → 沿用本地状态，不降级付费用户
 *   （RC 故障不应误伤已付费用户；webhook 已做签名校验，本地状态可信度高）
 * - 状态变化才写库，减少 DB 写入
 *
 * @param {object} user Mongoose User 文档（会被原地修改并 save）
 * @param {{force?: boolean}} options force=true 跳过缓存强制校验
 * @returns {Promise<object>} 校验后的 user（状态已与 RC 同步）
 */
const verifyAndSync = async (user, options = {}) => {
  if (!user || !user.userId) return user;

  // key 未配置：dev 跳过；prod 告警但不阻塞启动（出站校验为增强层，非硬依赖）
  if (!isConfigured()) {
    if (config.isProd) {
      logger.warn('RevenueCat API key not configured (REVENUECAT_API_KEY missing or is dev default). Outbound verification skipped; relying on webhook + local expiry only.');
    }
    return user;
  }

  const now = Date.now();
  const nextAllowed = cache.get(user.userId) || 0;
  if (!options.force && now < nextAllowed) {
    return user; // 缓存窗口内，沿用本地
  }
  cache.set(user.userId, now + CACHE_TTL_MS);

  const subscriber = await fetchSubscriber(user.userId);
  if (!subscriber) {
    // fail-open：RC 调用失败，沿用本地，不降级
    return user;
  }

  const resolved = resolveEntitlement(subscriber);

  if (hasChanged(user, resolved)) {
    const before = `${user.premiumType}/${user.expireTime}`;
    user.premiumType = resolved.premiumType;
    user.expireTime = resolved.expireTime;
    // 降级为 free 时清试用标记，保持状态一致
    if (resolved.premiumType === PREMIUM_TYPES.FREE) {
      user.trialEndTime = null;
    }
    await user.save();
    logger.info(`RevenueCat out-of-band sync for ${user.userId}: ${before} -> ${resolved.premiumType}/${resolved.expireTime}`);
  }

  return user;
};

// 供测试清缓存
const resetCache = () => cache.clear();

module.exports = { verifyAndSync, fetchSubscriber, resolveEntitlement, isConfigured, resetCache };
