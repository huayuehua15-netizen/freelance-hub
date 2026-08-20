const rateLimit = require('express-rate-limit');
const { verifyAccessToken } = require('../utils/jwt');
const { t } = require('../utils/i18n');

// 已登录用户按 userId 限流，未登录按 IP。
// 设计要点：
// 1. apiLimiter 挂在 auth 中间件之前，req.userId 此时未设置，所以从 Authorization
//    header 解析 JWT payload 取 userId（仅验签不查库，token 过期则回退 IP）。
// 2. 这样同一 NAT/公司 IP 下多个真实用户各自拥有独立配额，避免相互影响；同时
//    单个用户即便切换 IP 也无法绕过配额（因为按 userId 聚合）。
// 3. token 无法解析时一律回退 IP，保证未认证请求仍受 IP 级限流保护。
function resolveKey(req) {
  try {
    const h = req.headers.authorization || '';
    if (h.startsWith('Bearer ')) {
      const decoded = verifyAccessToken(h.slice(7));
      if (decoded && decoded.userId) return `u:${decoded.userId}`;
    }
  } catch (_) {
    // token 无效/过期：回退 IP 限流，不影响请求本身（auth 中间件会再校验）
  }
  const ip = req.ip;
  return ip ? `ip:${ip}` : 'ip:unknown';
}

// express-rate-limit 的 message 既支持静态对象，也支持 (req) => 动态计算。
// 这里用函数形式，按 req.lang（由 lang 中间件注入）返回本地化消息。
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  // 登录/注册是未认证端点，按 IP 限流防爆破
  keyGenerator: (req) => req.ip || 'unknown',
  message: (req) => ({
    code: 429,
    msg: t('errors.rateLimit.authTooMany', req.lang || 'en'),
    data: null,
    timestamp: Date.now(),
  }),
});

// Refresh token 轮换端点：比普通 API 更严格，防止被盗 token 被刷。
// 10 次/分钟足够正常单设备轮换，多设备也够用。
const refreshLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.ip || 'unknown',
  message: (req) => ({
    code: 429,
    msg: t('errors.rateLimit.tooMany', req.lang || 'en'),
    data: null,
    timestamp: Date.now(),
  }),
});

// 忘记密码/邮箱验证端点：5 次/小时/IP —— 防邮件轰炸（真实用户几乎不会
// 一小时内忘记 5 次密码；攻击者可借此向任意邮箱发信骚扰）。
const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.ip || 'unknown',
  message: (req) => ({
    code: 429,
    msg: t('errors.rateLimit.tooMany', req.lang || 'en'),
    data: null,
    timestamp: Date.now(),
  }),
});

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: resolveKey,
  message: (req) => ({
    code: 429,
    msg: t('errors.rateLimit.tooMany', req.lang || 'en'),
    data: null,
    timestamp: Date.now(),
  }),
});

module.exports = { authLimiter, refreshLimiter, passwordResetLimiter, apiLimiter };
