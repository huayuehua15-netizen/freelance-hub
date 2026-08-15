const crypto = require('crypto');
const User = require('../models/User');
const config = require('../config/env');
const logger = require('../utils/logger');
const { PREMIUM_TYPES } = require('../utils/constants');

const handleRevenuecatWebhook = async (req, res) => {
  try {
    const signature = req.headers['x-revenuecat-signature'];
    const event = req.body;

    if (config.isProd) {
      if (typeof signature !== 'string' || !req.rawBody) {
        logger.warn('Missing RevenueCat webhook signature');
        return res.status(403).json({ error: 'Invalid signature' });
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
        return res.status(403).json({ error: 'Invalid signature' });
      }
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

    const user = await User.findOne({ userId: appUserId });
    if (!user) {
      logger.warn(`Webhook: user not found: ${appUserId}`);
      return res.status(200).json({ received: true });
    }

    switch (type) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'PRODUCT_CHANGE': {
        if (productId?.includes('annual')) {
          user.premiumType = PREMIUM_TYPES.ANNUAL;
        } else if (productId?.includes('monthly')) {
          user.premiumType = PREMIUM_TYPES.MONTHLY;
        }
        user.expireTime = eventData.expires_at_ms || null;
        if (eventData.trial_converted_at_ms) {
          user.trialEndTime = null;
        }
        await user.save();
        logger.info(`User ${appUserId} premium updated: ${user.premiumType}`);
        break;
      }
      case 'EXPIRATION':
      case 'CANCELLATION': {
        if (type === 'EXPIRATION' || eventData.expires_at_ms <= Date.now()) {
          user.premiumType = PREMIUM_TYPES.FREE;
          user.expireTime = null;
          user.trialEndTime = null;
          await user.save();
          logger.info(`User ${appUserId} subscription expired/downgraded`);
        }
        break;
      }
      case 'REFUND': {
        user.premiumType = PREMIUM_TYPES.FREE;
        user.expireTime = null;
        await user.save();
        logger.info(`User ${appUserId} refund processed, downgraded`);
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
    return res.status(500).json({ error: 'Internal error' });
  }
};

module.exports = { handleRevenuecatWebhook };
