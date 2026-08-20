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
  // 生产环境绝不允许演示特权：注册默认 annual = 全员免费用一年，属部署事故级风险
  if (String(process.env.DEMO_ANNUAL_BY_DEFAULT).toLowerCase() === 'true') {
    throw new Error(
      '[config] DEMO_ANNUAL_BY_DEFAULT must NOT be enabled in production. ' +
        'Demo entitlement grants are for local/staging only.'
    );
  }
}

// 演示开关：仅本地/联调环境显式开启后，注册用户才默认拿到 annual(+1 年)。
// 默认关闭——即使 NODE_ENV 漏配为 production，注册也只会是 free，杜绝误上线事故。
const demoAnnualByDefault =
  !isProd && String(process.env.DEMO_ANNUAL_BY_DEFAULT).toLowerCase() === 'true';

if (demoAnnualByDefault) {
  // 联调/演示时能看到明确提示，避免"为什么注册是 free"的困惑
  console.warn('[config] DEMO_ANNUAL_BY_DEFAULT=true: new registrations will be annual for demo purposes.');
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
  smtp: {
    host: process.env.SMTP_HOST || '',
    port: parseInt(process.env.SMTP_PORT) || 587,
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.SMTP_FROM || 'Freelance Hub <no-reply@freelancehub.app>',
  },
  revenuecat: {
    webhookSecret: process.env.REVENUECAT_WEBHOOK_SECRET || 'dev_webhook_secret',
    apiKey: process.env.REVENUECAT_API_KEY || 'dev_api_key',
  },
  clientUrl: process.env.CLIENT_URL || 'http://localhost:5173',
  isProd,
  demoAnnualByDefault,
};
