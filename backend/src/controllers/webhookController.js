const crypto = require('crypto');
const User = require('../models/User');
const WebhookEvent = require('../models/WebhookEvent');
const config = require('../config/env');
const logger = require('../utils/logger');
const { PREMIUM_TYPES } = require('../utils/constants');
const { t } = require('../utils/i18n');

// 订阅档位排序：仅允许"升档"立即生效；降档（年→月）等到续费/过期事件再落地，
// 与 Google Play 的结算规则一致（升级立即生效并按比例扣费，降档下周期生效）。
const TIER_RANK = { [PREMIUM_TYPES.FREE]: 0, [PREMIUM_TYPES.MONTHLY]: 1, [PREMIUM_TYPES.ANNUAL]: 2 };

const tierFromProductId = (productId) => {
  if (!productId) return null;
  if (productId.includes('annual')) return PREMIUM_TYPES.ANNUAL;
  if (productId.includes('monthly')) return PREMIUM_TYPES.MONTHLY;
  return null;
};

const applyEntitlement = (user, { tier, expireTime, trialEndTime }) => {
  if (expireTime !== undefined) user.expireTime = expireTime;
  if (trialEndTime !== undefined) user.trialEndTime = trialEndTime;
  if (tier && tier !== user.premiumType) user.premiumType = tier;
};

const handleRevenuecatWebhook = async (req, res) => {
  try {
    const signature = req.headers['x-revenuecat-signature'];
    const event = req.body;

    // 签名校验在任何环境都执行(配合 env.js 的 prod fail-fast,杜绝 dev 也被伪造订阅事件)
    // dev 默认 secret 为 'dev_webhook_secret',本地回放用同值签名即可
    if (typeof signature !== 'string' || !req.rawBody) {
      logger.warn('Missing RevenueCat webhook signature');
      return res.status(403).json({ error: t('errors.webhook.invalidSignature', req.lang) });
    }
    // RevenueCat v2 signs the raw body with HMAC-SHA256 (base64).  The header
    // may carry multiple `vX=<sig>,...` entries so all of them must be
    // checked before rejecting the request.
    const expected = crypto
      .createHmac('sha256', config.revenuecat.webhookSecret)
      .update(req.rawBody)
      .digest('base64');
    const expectedBuf = Buffer.from(expected, 'base64');

    const presented = signature
      .split(',')
      .map((entry) => entry.trim())
      .map((entry) => entry.replace(/^v\d+=/i, ''))
      .filter(Boolean);

    const valid = presented.some((entry) => {
      const buf = Buffer.from(entry, 'base64');
      return buf.length === expectedBuf.length && crypto.timingSafeEqual(buf, expectedBuf);
    });

    if (!valid) {
      logger.warn('Invalid RevenueCat webhook signature');
      return res.status(403).json({ error: t('errors.webhook.invalidSignature', req.lang) });
    }

    // RevenueCat v2 wraps the data in `event`; accepting the flat shape keeps
    // local replay tests compatible without weakening production verification.
    const eventData = event.event || event;
    const type = eventData.type || event.type;
    const appUserId = eventData?.app_user_id;
    const productId = eventData?.product_id;

    if (!appUserId) {
      logger.warn('Webhook missing app_user_id');
      return res.status(200).json({ received: true });
    }

    // 沙盒事件不得改动生产账号：RC 对 sandbox 事件使用同一 secret 签名，
    // 签名通过不代表事件可信，必须再校验 environment 字段。
    if (config.isProd && eventData.environment === 'SANDBOX') {
      logger.warn(`Ignoring SANDBOX webhook event for prod user ${appUserId}`);
      return res.status(200).json({ received: true });
    }

    // 幂等去重：RC at-least-once 投递，重试/重放携带相同 event.id。
    // 唯一索引插入失败 = 已处理过，直接确认，防止重放续命会员。
    const eventId = eventData?.id;
    if (eventId) {
      try {
        await WebhookEvent.create({ eventId: String(eventId), type: String(type || 'unknown'), appUserId });
      } catch (dupErr) {
        if (dupErr?.code === 11000 || dupErr?.name === 'MongoServerError') {
          logger.info(`Duplicate webhook event ${eventId}, already processed`);
          return res.status(200).json({ received: true });
        }
        throw dupErr;
      }
    }

    const user = await User.findOne({ userId: appUserId });
    if (!user) {
      logger.warn(`Webhook: user not found: ${appUserId}`);
      return res.status(200).json({ received: true });
    }

    // RC 事件规范字段为 expiration_at_ms（毫秒）。防御性兼容历史/自定义
    // 回放载荷的 expires_at_ms 写法，但以规范字段优先。
    const expirationAtMs = eventData.expiration_at_ms ?? eventData.expires_at_ms ?? null;
    const isTrialPeriod = eventData.period_type === 'TRIAL';
    const isTrialConversion = eventData.is_trial_conversion === true;

    switch (type) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'UNCANCELLATION':
      case 'SUBSCRIPTION_EXTENDED': {
        const tier = tierFromProductId(productId);
        // 单调性守卫：过期时间只能向前推。重放的旧 RENEWAL（更早的到期
        // 时间）不得回退已存储的 expireTime。
        const currentExpire = user.expireTime ?? 0;
        const nextExpire = expirationAtMs ?? currentExpire;
        if (nextExpire < currentExpire) {
          logger.info(`Stale ${type} for ${appUserId}: ignoring expireTime regression`);
          break;
        }
        applyEntitlement(user, { tier, expireTime: nextExpire });
        // 试用期内到期时间即试用结束时间；试用转正式后清除试用标记
        if (isTrialPeriod && expirationAtMs) {
          user.trialEndTime = expirationAtMs;
        }
        if (isTrialConversion) {
          user.trialEndTime = null;
        }
        await user.save();
        logger.info(`User ${appUserId} premium updated: ${user.premiumType}`);
        break;
      }
      case 'PRODUCT_CHANGE': {
        // RC 文档明确：PRODUCT_CHANGE 不代表新订阅立即生效。Google Play 的
        // 规则是升级立即生效、降档下个周期生效 —— 这里仅对升档立即应用，
        // 降档保留当前档位，等待 RENEWAL/EXPIRATION 事件落地。
        const tier = tierFromProductId(productId);
        if (tier && TIER_RANK[tier] > TIER_RANK[user.premiumType]) {
          applyEntitlement(user, { tier, expireTime: expirationAtMs ?? undefined });
          await user.save();
          logger.info(`User ${appUserId} upgraded via PRODUCT_CHANGE: ${tier}`);
        } else {
          logger.info(`User ${appUserId} PRODUCT_CHANGE deferred (downgrade): ${user.premiumType} -> ${tier}`);
        }
        break;
      }
      case 'EXPIRATION': {
        user.premiumType = PREMIUM_TYPES.FREE;
        user.expireTime = null;
        user.trialEndTime = null;
        await user.save();
        logger.info(`User ${appUserId} subscription expired`);
        break;
      }
      case 'CANCELLATION': {
        // RC 无独立 REFUND 事件：退款以 CANCELLATION + cancel_reason
        // CUSTOMER_SUPPORT 到达，需立即撤销权益；UNSUBSCRIBE 取消但订阅
        // 仍有效至到期（到期会有 EXPIRATION 事件兜底）。
        const isRefund = eventData.cancel_reason === 'CUSTOMER_SUPPORT';
        const alreadyExpired = expirationAtMs !== null && expirationAtMs <= Date.now();
        if (isRefund || alreadyExpired) {
          user.premiumType = PREMIUM_TYPES.FREE;
          user.expireTime = null;
          user.trialEndTime = null;
          await user.save();
          logger.info(`User ${appUserId} ${isRefund ? 'refunded' : 'canceled+expired'}, downgraded`);
        } else {
          logger.info(`User ${appUserId} canceled subscription, access kept until expiry`);
        }
        break;
      }
      case 'REFUND': {
        // RC 当前事件列表无此类型，防御性保留（历史平台/自定义集成）。
        user.premiumType = PREMIUM_TYPES.FREE;
        user.expireTime = null;
        user.trialEndTime = null;
        await user.save();
        logger.info(`User ${appUserId} refund processed, downgraded`);
        break;
      }
      case 'BILLING_ISSUE': {
        // 宽限期内（grace_period_expiration_at_ms）RC 不发 EXPIRATION，
        // 保持权益；真正的失效最终由 EXPIRATION 事件落地。
        logger.warn(`User ${appUserId} billing issue, grace until: ${eventData.grace_period_expiration_at_ms ?? 'n/a'}`);
        break;
      }
      case 'SUBSCRIPTION_PAUSED': {
        logger.info(`User ${appUserId} subscription paused`);
        break;
      }
      default:
        logger.info(`Unhandled RevenueCat event type: ${type}`);
    }

    return res.status(200).json({ received: true });
  } catch (error) {
    logger.error(`Webhook error: ${error.message}`);
    return res.status(500).json({ error: t('errors.webhook.internalError', req.lang) });
  }
};

module.exports = { handleRevenuecatWebhook };
