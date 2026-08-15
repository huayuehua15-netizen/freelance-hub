/**
 * 解析 Accept-Language 头，挂到 req.lang（'en' | 'zh'）。
 *
 * 策略：取头部第一个语言标签，以 'zh' 开头（zh, zh-CN, zh-TW, zh-Hans...）归为 'zh'，
 * 其余一律按 'en' 处理。controller 通过 req.lang 调用 t(key, req.lang)。
 *
 * 设计说明：不使用 i18next 等 ICU 库；本项目只需要 en/zh 二选一，
 * 完整 BCP 47 解析对当前规模属于过度设计。
 */
module.exports = function langMiddleware(req, res, next) {
  const al = req.headers['accept-language'] || 'en';
  // 取逗号分隔的第一个语言标签
  const first = String(al).split(',')[0] || 'en';
  req.lang = first.trim().toLowerCase().startsWith('zh') ? 'zh' : 'en';
  // 让响应也可访问（errorHandler 等非 req 上下文可用 res.locals.lang）
  res.locals.lang = req.lang;
  next();
};
