const ExpenseLog = require('../models/ExpenseLog');
const SyncService = require('../services/syncService');
const { ERROR_CODES, PREMIUM_TYPES, SYNC_BATCH_LIMIT } = require('../utils/constants');
const { t } = require('../utils/i18n');
const { DateTime } = require('luxon');
const { getMonthBounds } = require('../utils/timezone');

const batchUpsert = async (req, res, next) => {
  try {
    const { expenses } = req.body;
    if (!Array.isArray(expenses)) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.sync.expensesArrayRequired', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    if (expenses.length > SYNC_BATCH_LIMIT) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.sync.batchTooLarge', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    const result = await SyncService.batchUpsert(req.userId, ExpenseLog, expenses, 'expenseId');

    req.user.lastSyncTime = Date.now();
    await req.user.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('common.success', req.lang),
      data: result,
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

const pull = async (req, res, next) => {
  try {
    const { since, limit, cursor } = req.query;
    const sinceTime = parseInt(since) || 0;
    const limitNum = Math.min(Math.max(parseInt(limit) || 100, 1), 500);

    const result = await SyncService.pullSince(req.userId, ExpenseLog, sinceTime, limitNum, cursor);

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('common.success', req.lang),
      data: result,
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

const list = async (req, res, next) => {
  try {
    const { projectId, category, isTaxDeductible, startDate, endDate, limit, cursor } = req.query;
    const query = { userId: req.userId, isDeleted: false };

    if (projectId) query.projectId = projectId;
    if (category) query.category = category;
    if (isTaxDeductible !== undefined) query.isTaxDeductible = isTaxDeductible === 'true';

    // 组装 expenseDate 范围:Annual 尊重用户传入,Free 强制限制在当月内
    // 修复 M3:此前 Free 直接覆盖用户传入的 startDate/endDate,且无上界
    const expenseDateRange = {};
    if (startDate) expenseDateRange.$gte = parseInt(startDate);
    if (endDate) expenseDateRange.$lt = parseInt(endDate);

    if (req.user.premiumType === PREMIUM_TYPES.FREE) {
      const userTz = req.user.timezone || 'America/New_York';
      // 月边界按用户时区计算（与报表归类一致）：服务器本地时间会导致
      // 非服务器时区用户月初 0-8 小时的数据跨月泄漏/丢失
      const { start: monthStart, end: monthEnd } = getMonthBounds(
        DateTime.now().setZone(userTz).year,
        DateTime.now().setZone(userTz).month,
        userTz
      );
      const userStart = startDate ? parseInt(startDate) : 0;
      const userEnd = endDate ? parseInt(endDate) : Infinity;
      expenseDateRange.$gte = Math.max(monthStart, userStart);
      expenseDateRange.$lt = Math.min(monthEnd, userEnd);
    }

    if (Object.keys(expenseDateRange).length) query.expenseDate = expenseDateRange;

    // 修复 M4:复合游标 (serverUpdateTime, _id),避免同毫秒多条翻页跳过/重复
    const limitNum = Math.min(Math.max(parseInt(limit) || 50, 1), 200);
    if (cursor) {
      const [tsStr, idStr] = cursor.split('_');
      const ts = parseInt(tsStr);
      if (idStr) {
        query.$or = [
          { serverUpdateTime: { $lt: new Date(ts) } },
          { serverUpdateTime: new Date(ts), _id: { $lt: idStr } },
        ];
      } else {
        query.serverUpdateTime = { $lt: new Date(ts) };
      }
    }

    const expenses = await ExpenseLog.find(query)
      .sort({ serverUpdateTime: -1, _id: -1 })
      .limit(limitNum + 1);
    const hasMore = expenses.length > limitNum;
    const data = hasMore ? expenses.slice(0, limitNum) : expenses;
    const last = hasMore ? data[data.length - 1] : null;
    const nextCursor = last ? `${last.serverUpdateTime.getTime()}_${last._id}` : null;

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('common.success', req.lang),
      data: { expenses: data, hasMore, nextCursor },
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

const remove = async (req, res, next) => {
  try {
    const { expenseId } = req.params;
    const expense = await ExpenseLog.findOne({ userId: req.userId, expenseId });

    if (!expense) {
      return res.status(404).json({
        code: ERROR_CODES.NOT_FOUND,
        msg: t('errors.expense.notFound', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    expense.isDeleted = true;
    await expense.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('expense.deleted', req.lang),
      data: null,
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { batchUpsert, pull, list, remove };
