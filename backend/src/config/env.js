require('dotenv').config();

const isProd = process.env.NODE_ENV === 'production';

// 生产环境必须显式配置密钥,杜绝静默使用公开 fallback 导致 token 可伪造 / webhook 可重算
if (isProd) {
  const requiredSecrets = ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET', 'REVENUECAT_WEBHOOK_SECRET'];
  const missing = requiredSecrets.filter((key) => !process.env[key] || String(process.env[key]).trim() === '');
  if (missing.length > 0) {
    throw new Error(
      `[config] Missing required secret(s) in production: ${missing.join(', ')}. ` +
        'Set them in .env before starting the server.'
    );
  }
}

module.exports = {
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  mongodbUri: process.env.MONGODB_URI || 'mongodb://localhost:27017/freelance_hub',
  jwt: {
    // dev 保留 fallback 便于本地启动;prod 由上方守卫保证一定有显式值
    accessSecret: process.env.JWT_ACCESS_SECRET || 'dev_access_secret',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'dev_refresh_secret',
    accessExpires: process.env.JWT_ACCESS_EXPIRES || '1h',
    refreshExpires: process.env.JWT_REFRESH_EXPIRES || '30d',
  },
  bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS) || 12,
  revenuecat: {
    webhookSecret: process.env.REVENUECAT_WEBHOOK_SECRET || 'dev_webhook_secret',
    apiKey: process.env.REVENUECAT_API_KEY || 'dev_api_key',
  },
  clientUrl: process.env.CLIENT_URL || 'http://localhost:5173',
  isProd,
};
