const rateLimit = require('express-rate-limit');
const { t } = require('../utils/i18n');

// express-rate-limit 的 message 既支持静态对象，也支持 (req) => 动态计算。
// 这里用函数形式，按 req.lang（由 lang 中间件注入）返回本地化消息。
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  // req.lang 由 app.js 挂载的 langMiddleware 注入；若中间件未挂载则回退 'en'
  message: (req) => ({
    code: 429,
    msg: t('errors.rateLimit.authTooMany', req.lang || 'en'),
    data: null,
    timestamp: Date.now(),
  }),
});

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: (req) => ({
    code: 429,
    msg: t('errors.rateLimit.tooMany', req.lang || 'en'),
    data: null,
    timestamp: Date.now(),
  }),
});

module.exports = { authLimiter, apiLimiter };
