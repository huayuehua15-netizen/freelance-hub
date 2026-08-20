const jwt = require('jsonwebtoken');
const config = require('../config/env');

const generateAccessToken = (userId) => {
  return jwt.sign({ userId, type: 'access' }, config.jwt.accessSecret, {
    expiresIn: config.jwt.accessExpires,
  });
};

const generateRefreshToken = (userId) => {
  return jwt.sign({ userId, type: 'refresh' }, config.jwt.refreshSecret, {
    expiresIn: config.jwt.refreshExpires,
  });
};

// 显式锁定算法白名单为 HS256，防止算法混淆攻击
// （攻击者用公钥当 HMAC 密钥伪造 token）；同时校验 type claim，
// 确保 access/refresh 两种 token 不可互相冒用。
const verifyAccessToken = (token) => {
  const decoded = jwt.verify(token, config.jwt.accessSecret, { algorithms: ['HS256'] });
  if (decoded.type !== 'access') {
    throw new jwt.JsonWebTokenError('invalid token type');
  }
  return decoded;
};

const verifyRefreshToken = (token) => {
  const decoded = jwt.verify(token, config.jwt.refreshSecret, { algorithms: ['HS256'] });
  if (decoded.type !== 'refresh') {
    throw new jwt.JsonWebTokenError('invalid token type');
  }
  return decoded;
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
};
