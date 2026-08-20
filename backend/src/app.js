const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const mongoose = require('mongoose');
const config = require('./config/env');
const connectDB = require('./config/database');
const errorHandler = require('./middleware/errorHandler');
const { apiLimiter } = require('./middleware/rateLimit');
const langMiddleware = require('./middleware/lang');
const logger = require('./utils/logger');
const emailService = require('./services/emailService');

const authRoutes = require('./routes/auth');
const projectRoutes = require('./routes/project');
const timelogRoutes = require('./routes/timelog');
const expenseRoutes = require('./routes/expense');
const reportRoutes = require('./routes/report');
const premiumRoutes = require('./routes/premium');
const webhookRoutes = require('./routes/webhook');
const taxCategoryRoutes = require('./routes/taxCategory');
const { scheduleAccountCleanup } = require('./services/cleanupService');
const { seedDefaultTaxCategories } = require('./services/taxCategorySeed');

const app = express();

// 生产环境部署在反向代理（nginx/Cloudflare/Render 等）后，必须信任 X-Forwarded-*
// 头，否则 req.ip 取到的是代理 IP 而非真实客户端 IP，rateLimit 的 IP 限流会失效。
// 'loopback' 仅信任本机回环代理，最安全；如部署在多跳代理后改为对应 hop 数。
app.set('trust proxy', config.isProd ? 1 : 'loopback');

app.use(cors({
  // 生产环境仅允许 Web 后台域名；开发/演示环境放开（移动端无 CORS 限制，
  // Web 可能通过局域网 IP 访问用于展示）。
  origin: config.isProd ? config.clientUrl : true,
  credentials: true,
}));

// helmet 安全头：HSTS、X-Content-Type-Options、X-Frame-Options、CSP 等。
// 这是纯 API 服务（返回 JSON/PDF/CSV，不渲染 HTML），CSP 收紧到只允许自身
// 与必要来源，杜绝点击劫持/MIME 嗅探/降级 HTTPS 攻击。
app.use(helmet({
  contentSecurityPolicy: {
    useDefaults: true,
    directives: {
      defaultSrc: ["'none'"],
      // API 不执行脚本/样式/图片，全部 none；frameAncestors 由 helmet 默认 DENY
    },
  },
  // 生产强制 HTTPS：1 年 HSTS，含子域，预加载
  strictTransportSecurity: config.isProd
    ? { maxAge: 31536000, includeSubDomains: true, preload: true }
    : false,
}));
// Preserve the exact webhook payload for HMAC verification.  Re-serialising a
// parsed JSON object changes whitespace/key ordering and makes signatures
// unverifiable.
app.use(express.json({
  limit: '10mb',
  verify: (req, res, buffer) => {
    if (req.originalUrl.startsWith('/api/v1/webhook/')) {
      req.rawBody = Buffer.from(buffer);
    }
  },
}));
app.use(express.urlencoded({ extended: true }));

// 解析 Accept-Language 头，挂到 req.lang（'en' | 'zh'）；
// controller 通过 t(key, req.lang) 返回本地化错误消息。
app.use(langMiddleware);

// 轻量请求日志：方法/路径/状态码/耗时，走 winston 统一格式。
// 健康检查与 webhook 高频路径不打日志，避免噪音。
app.use((req, res, next) => {
  if (req.path === '/api/v1/health' || req.path.startsWith('/api/v1/webhook')) return next();
  const startedAt = Date.now();
  res.on('finish', () => {
    const ms = Date.now() - startedAt;
    const level = res.statusCode >= 500 ? 'error' : 'info';
    logger.log(level, `${req.method} ${req.originalUrl} ${res.statusCode} ${ms}ms ip=${req.ip}`);
  });
  next();
});

app.get('/api/v1/health', (req, res) => {
  // 探活数据库：编排器/监控据此重启异常实例（Mongo 断连时返回 503 而非假健康）
  const dbState = mongoose.connection.readyState; // 1 = connected
  const healthy = dbState === 1;
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    db: healthy ? 'connected' : 'disconnected',
    email: emailService.isConfigured() ? 'configured' : 'fallback-log',
    timestamp: Date.now(),
    env: config.nodeEnv,
  });
});

app.use('/api/v1/webhook', webhookRoutes);
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/project', apiLimiter, projectRoutes);
app.use('/api/v1/timelog', apiLimiter, timelogRoutes);
app.use('/api/v1/expense', apiLimiter, expenseRoutes);
app.use('/api/v1/report', apiLimiter, reportRoutes);
app.use('/api/v1/premium', apiLimiter, premiumRoutes);
app.use('/api/v1/tax-category', apiLimiter, taxCategoryRoutes);

app.use(errorHandler);

const startServer = async () => {
  try {
    await connectDB();
    // GDPR 合规：注册账号 30 天硬删定时任务（启动时立即执行一次 + 每天 03:00 UTC）
    scheduleAccountCleanup();
    // 初始化系统默认税务分类（IRS Schedule C 标准类目，幂等）
    await seedDefaultTaxCategories();
    if (!emailService.isConfigured()) {
      const msg = 'SMTP not configured — verification/password-reset emails will be logged to server logs instead of sent.';
      if (config.isProd) logger.warn(`[email] ${msg}`);
      else logger.info(`[email] ${msg}`);
    }
    const server = app.listen(config.port, () => {
      logger.info(`Freelance Hub API server running on port ${config.port} (${config.nodeEnv})`);
    });

    // 优雅停机：停止接收新连接 → 等待在途请求（默认超时由 server.close 兜底）→ 关闭数据库
    let shuttingDown = false;
    const shutdown = async (signal, exitCode = 0) => {
      if (shuttingDown) return;
      shuttingDown = true;
      logger.info(`${signal} received, shutting down gracefully...`);
      try {
        await new Promise((resolve) => server.close(resolve));
        await mongoose.connection.close();
        logger.info('Shutdown complete.');
      } catch (err) {
        logger.error(`Error during shutdown: ${err.message}`);
      }
      process.exit(exitCode);
    };
    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

    // 进程级兜底：Promise 拒绝记录不退出；uncaughtException 后进程状态
    // 不可信，记录后走优雅停机交由编排器重启（容器/P M2/系统服务）。
    process.on('unhandledRejection', (reason) => {
      logger.error(`unhandledRejection: ${reason instanceof Error ? reason.stack : reason}`);
    });
    process.on('uncaughtException', (err) => {
      logger.error(`uncaughtException: ${err.stack || err.message}`);
      shutdown('uncaughtException', 1);
    });
  } catch (error) {
    logger.error(`Failed to start server: ${error.message}`);
    process.exit(1);
  }
};

startServer();

module.exports = app;
