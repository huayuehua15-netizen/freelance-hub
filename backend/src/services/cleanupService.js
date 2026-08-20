const cron = require('node-cron');
const mongoose = require('mongoose');
const logger = require('../utils/logger');
const User = require('../models/User');
const ClientProject = require('../models/ClientProject');
const TimeLog = require('../models/TimeLog');
const ExpenseLog = require('../models/ExpenseLog');
const TaxCategory = require('../models/TaxCategory');

// GDPR Article 17（被遗忘权）：软删账号 30 天宽限期后必须物理删除全部关联数据。
const GRACE_PERIOD_DAYS = 30;
const GRACE_PERIOD_MS = GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000;

/**
 * 删除单个用户的全部关联数据（幂等，可重复执行）。
 * 副本集上走事务保证原子性；standalone MongoDB（事务不可用）降级为
 * 顺序删除 —— 失败的运行会在下一次 cron 自动重跑补齐，配合幂等性
 * 保证最终删除完整（否则 standalone 部署下硬删除会静默永不执行，
 * 且软删用户永久占用邮箱唯一索引阻断再注册）。
 */
async function purgeUserData(u) {
  const runDeletes = async (session) => {
    const sessionOpt = session ? { session } : {};
    // 级联删除：项目 / 工时 / 开支 / 自定义税务类目 / 用户，按 userId 隔离
    // （TaxCategory 含用户自定义名称，属个人数据，GDPR Art.17 要求一并删除）
    const results = await Promise.all([
      ClientProject.deleteMany({ userId: u.userId }, sessionOpt),
      TimeLog.deleteMany({ userId: u.userId }, sessionOpt),
      ExpenseLog.deleteMany({ userId: u.userId }, sessionOpt),
      TaxCategory.deleteMany({ userId: u.userId }, sessionOpt),
      User.deleteOne({ userId: u.userId }, sessionOpt),
    ]);
    return results.reduce((sum, r) => sum + (r.deletedCount || 0), 0);
  };

  if (mongoose.connection.readyState === 1 && !isStandaloneServer()) {
    const session = await mongoose.startSession();
    try {
      let records = 0;
      await session.withTransaction(async () => {
        records = await runDeletes(session);
      });
      return records;
    } finally {
      await session.endSession();
    }
  }
  // standalone（无副本集）降级路径：无事务，靠幂等 + cron 重跑兜底
  logger.warn('[Cleanup] Transactions unavailable, falling back to sequential deletes.');
  return runDeletes(null);
}

// 判断当前连接是否 standalone（事务需要副本集）。探测失败按保守处理
//（降级顺序删除），避免因探测异常而中断清理。
// 副本集拓扑缓存：null = 未探测；true = standalone（事务不可用）
let isStandalone = null;

function isStandaloneServer() {
  return isStandalone === true;
}

/**
 * 物理删除已超过 30 天宽限期的软删账号及其所有关联业务数据。
 * - 副本集使用事务保证原子性；standalone 降级为顺序删除（幂等可重跑）。
 * - 单个用户失败不影响其他用户。
 * - 失败不抛错，仅记录日志（避免 cron 任务崩溃影响服务）。
 *
 * @returns {Promise<{ purgedUsers: number, failedUsers: number, totalRecords: number }>}
 */
async function purgeDeletedAccounts() {
  const cutoff = new Date(Date.now() - GRACE_PERIOD_MS);
  const startedAt = Date.now();
  let purgedUsers = 0;
  let failedUsers = 0;
  let totalRecords = 0;

  // 启动后首次运行时探测一次拓扑：hello 命令的 setName 存在 = 副本集
  try {
    const hello = await mongoose.connection.db.admin().command({ hello: 1 });
    isStandalone = !hello.setName;
  } catch (probeErr) {
    logger.warn(`[Cleanup] Topology probe failed, assuming standalone: ${probeErr.message}`);
    isStandalone = true;
  }

  try {
    // 只查必要字段，避免拉取 passwordHash 等敏感数据
    const expiredUsers = await User.find({
      isDeleted: true,
      deletedAt: { $lt: cutoff },
    }).select('userId deletedAt').lean();

    if (expiredUsers.length === 0) {
      logger.info('[Cleanup] No expired accounts to purge.');
      return { purgedUsers: 0, failedUsers: 0, totalRecords: 0 };
    }

    logger.info(
      `[Cleanup] Found ${expiredUsers.length} expired account(s) to purge (cutoff=${cutoff.toISOString()}).`
    );

    for (const u of expiredUsers) {
      try {
        const records = await purgeUserData(u);
        totalRecords += records;
        purgedUsers += 1;
        logger.info(
          `[Cleanup] Purged user ${u.userId} (deletedAt=${u.deletedAt?.toISOString()}): records=${records}`
        );
      } catch (err) {
        failedUsers += 1;
        logger.error(`[Cleanup] Failed to purge user ${u.userId}: ${err.message}`);
      }
    }

    const elapsed = Date.now() - startedAt;
    logger.info(
      `[Cleanup] Done. Purged ${purgedUsers}/${expiredUsers.length} account(s), ` +
      `failed=${failedUsers}, totalRecordsRemoved=${totalRecords}, elapsed=${elapsed}ms.`
    );

    return { purgedUsers, failedUsers, totalRecords };
  } catch (error) {
    // 致命错误（如 DB 连接断开），记录但不抛出，避免 cron 任务崩溃主进程
    logger.error(`[Cleanup] Fatal error during purge: ${error.message}\n${error.stack}`);
    return { purgedUsers, failedUsers, totalRecords, fatalError: error.message };
  }
}

/**
 * 注册定时清理任务：
 * 1. 启动时立即执行一次（清理上次宕机期间累积的过期账号）
 * 2. 每天 03:00 UTC 执行（低峰期，避免影响业务）
 *
 * 使用 node-cron 而非 setInterval：避免漂移、可读性好、与系统 cron 表达式一致。
 */
function scheduleAccountCleanup() {
  // 启动时立即执行（异步，不阻塞服务器启动）
  purgeDeletedAccounts().catch((err) => {
    logger.error(`[Cleanup] Startup purge failed: ${err.message}`);
  });

  // 每天 03:00 UTC 执行
  cron.schedule(
    '0 3 * * *',
    () => {
      logger.info('[Cleanup] Scheduled daily purge starting...');
      purgeDeletedAccounts().catch((err) => {
        logger.error(`[Cleanup] Scheduled purge failed: ${err.message}`);
      });
    },
    {
      scheduled: true,
      timezone: 'UTC',
    }
  );

  logger.info(
    `[Cleanup] Scheduled daily account purge at 03:00 UTC ` +
    `(grace period = ${GRACE_PERIOD_DAYS} days).`
  );
}

module.exports = {
  purgeDeletedAccounts,
  scheduleAccountCleanup,
  GRACE_PERIOD_DAYS,
};
