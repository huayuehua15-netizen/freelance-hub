const { ERROR_CODES } = require('../utils/constants');
const logger = require('../utils/logger');

const errorHandler = (err, req, res, next) => {
  logger.error(`Unhandled error: ${err.message}`, { stack: err.stack });

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
      msg: 'Duplicate entry',
      data: null,
      timestamp: Date.now(),
    });
  }

  return res.status(500).json({
    code: ERROR_CODES.INTERNAL_ERROR,
    msg: 'Internal server error',
    data: null,
    timestamp: Date.now(),
  });
};

module.exports = errorHandler;
