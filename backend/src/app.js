const express = require('express');
const cors = require('cors');
const config = require('./config/env');
const connectDB = require('./config/database');
const errorHandler = require('./middleware/errorHandler');
const { apiLimiter } = require('./middleware/rateLimit');
const langMiddleware = require('./middleware/lang');
const logger = require('./utils/logger');

const authRoutes = require('./routes/auth');
const projectRoutes = require('./routes/project');
const timelogRoutes = require('./routes/timelog');
const expenseRoutes = require('./routes/expense');
const reportRoutes = require('./routes/report');
const premiumRoutes = require('./routes/premium');
const webhookRoutes = require('./routes/webhook');

const app = express();

app.use(cors({
  // 生产环境仅允许 Web 后台域名；开发/演示环境放开（移动端无 CORS 限制，
  // Web 可能通过局域网 IP 访问用于展示）。
  origin: config.isProd ? config.clientUrl : true,
  credentials: true,
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

app.get('/api/v1/health', (req, res) => {
  res.json({ status: 'ok', timestamp: Date.now(), env: config.nodeEnv });
});

app.use('/api/v1/webhook', webhookRoutes);
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/project', apiLimiter, projectRoutes);
app.use('/api/v1/timelog', apiLimiter, timelogRoutes);
app.use('/api/v1/expense', apiLimiter, expenseRoutes);
app.use('/api/v1/report', apiLimiter, reportRoutes);
app.use('/api/v1/premium', apiLimiter, premiumRoutes);

app.use(errorHandler);

const startServer = async () => {
  try {
    await connectDB();
    app.listen(config.port, () => {
      logger.info(`Freelance Hub API server running on port ${config.port} (${config.nodeEnv})`);
    });
  } catch (error) {
    logger.error(`Failed to start server: ${error.message}`);
    process.exit(1);
  }
};

startServer();

module.exports = app;
