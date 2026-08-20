const { ERROR_CODES } = require('../utils/constants');
const { t } = require('../utils/i18n');
const logger = require('../utils/logger');

// 统一错误响应构造器，保证所有错误返回结构一致
const sendError = (res, status, code, msg, lang) => {
  if (!res.headersSent) {
    res.status(status).json({
      code,
      msg,
      data: null,
      timestamp: Date.now(),
    });
  }
};

const errorHandler = (err, req, res, next) => {
  // errorHandler 是四参数签名，Express 视为错误处理中间件；
  // req.lang 由 langMiddleware 注入，无需在此处重新解析。
  const lang = req.lang || res.locals.lang || 'en';

  // Mongoose 校验错误（schema required/type/enum 等）→ 400
  if (err.name === 'ValidationError') {
    logger.warn(`Validation error: ${err.message}`);
    return sendError(res, 400, ERROR_CODES.BAD_REQUEST, err.message, lang);
  }

  // Mongoose CastError（无效 ObjectId / 类型不匹配）→ 400
  // 例如 /project/:id 传入非 ObjectId；TimeLog.duration 传入非数字
  if (err.name === 'CastError') {
    const msg = t('errors.validation.invalidInput', lang);
    logger.warn(`CastError on path "${err.path}": ${err.message}`);
    return sendError(res, 400, ERROR_CODES.BAD_REQUEST, msg, lang);
  }

  // 唯一键冲突 → 409
  if (err.code === 11000) {
    return sendError(res, 409, ERROR_CODES.CONFLICT, t('common.duplicateEntry', lang), lang);
  }

  // 请求体超过 express.json({ limit: '10mb' }) → 413
  if (err.type === 'entity.too.large' || err.code === 'ERR_BODY_LIMIT') {
    logger.warn(`Payload too large: ${err.message}`);
    return sendError(res, 413, ERROR_CODES.BAD_REQUEST, t('errors.validation.payloadTooLarge', lang), lang);
  }

  // JSON 语法错误（请求体不是合法 JSON）→ 400
  // express.json() 抛出的 SyntaxError 带 status 字段
  if (err.type === 'entity.parse.failed' || (err instanceof SyntaxError && err.status === 400)) {
    logger.warn(`Malformed JSON body: ${err.message}`);
    return sendError(res, 400, ERROR_CODES.BAD_REQUEST, t('errors.validation.malformedJson', lang), lang);
  }

  // 其他未捕获错误 → 500，不向前端泄露内部堆栈
  logger.error(`Unhandled error: ${err.message}`, { stack: err.stack });
  return sendError(res, 500, ERROR_CODES.INTERNAL_ERROR, t('common.internalError', lang), lang);
};

module.exports = errorHandler;
