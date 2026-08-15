const { ERROR_CODES } = require('../utils/constants');
const { t } = require('../utils/i18n');
const logger = require('../utils/logger');

const errorHandler = (err, req, res, next) => {
  logger.error(`Unhandled error: ${err.message}`, { stack: err.stack });
  // errorHandler 是四参数签名，Express 视为错误处理中间件；
  // req.lang 由 langMiddleware 注入，无需在此处重新解析。
  const lang = req.lang || res.locals.lang || 'en';

  if (err.name === 'ValidationError') {
    return res.status(400).json({
      code: ERROR_CODES.BAD_REQUEST,
      msg: err.message,
      data: null,
      timestamp: Date.now(),
    });
  }

  if (err.code === 11000) {
    return res.status(409).json({
      code: ERROR_CODES.CONFLICT,
      msg: t('common.duplicateEntry', lang),
      data: null,
      timestamp: Date.now(),
    });
  }

  return res.status(500).json({
    code: ERROR_CODES.INTERNAL_ERROR,
    msg: t('common.internalError', lang),
    data: null,
    timestamp: Date.now(),
  });
};

module.exports = errorHandler;
