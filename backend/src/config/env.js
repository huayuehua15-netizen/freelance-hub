require('dotenv').config();

module.exports = {
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  mongodbUri: process.env.MONGODB_URI || 'mongodb://localhost:27017/freelance_hub',
  jwt: {
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
  isProd: process.env.NODE_ENV === 'production',
};
