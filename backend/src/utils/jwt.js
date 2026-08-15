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

const verifyAccessToken = (token) => {
  return jwt.verify(token, config.jwt.accessSecret);
};

const verifyRefreshToken = (token) => {
  return jwt.verify(token, config.jwt.refreshSecret);
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
};
