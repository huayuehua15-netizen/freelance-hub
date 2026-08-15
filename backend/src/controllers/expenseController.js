const ExpenseLog = require('../models/ExpenseLog');
const SyncService = require('../services/syncService');
const { ERROR_CODES, PREMIUM_TYPES } = require('../utils/constants');

const batchUpsert = async (req, res, next) => {
  try {
    const { expenses } = req.body;
    if (!Array.isArray(expenses)) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: 'expenses must be an array',
        data: null,
        timestamp: Date.now(),
      });
    }

    const result = await SyncService.batchUpsert(req.userId, ExpenseLog, expenses, 'expenseId');

    req.user.lastSyncTime = Date.now();
    await req.user.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: 'success',
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
    const limitNum = Math.min(parseInt(limit) || 100, 500);

    const result = await SyncService.pullSince(req.userId, ExpenseLog, sinceTime, limitNum, cursor);

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: 'success',
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

    const expenseDateRange = {};
    if (startDate) expenseDateRange.$gte = parseInt(startDate);
    if (endDate) expenseDateRange.$lt = parseInt(endDate);
    if (Object.keys(expenseDateRange).length) query.expenseDate = expenseDateRange;

    if (req.user.premiumType === PREMIUM_TYPES.FREE) {
      const monthStart = new Date();
      monthStart.setDate(1);
      monthStart.setHours(0, 0, 0, 0);
      query.expenseDate = { $gte: monthStart.getTime() };
    }

    const limitNum = Math.min(parseInt(limit) || 50, 200);
    if (cursor) query.serverUpdateTime = { $lt: new Date(parseInt(cursor)) };

    const expenses = await ExpenseLog.find(query).sort({ serverUpdateTime: -1 }).limit(limitNum + 1);
    const hasMore = expenses.length > limitNum;
    const data = hasMore ? expenses.slice(0, limitNum) : expenses;
    const nextCursor = hasMore ? data[data.length - 1].serverUpdateTime.getTime() : null;

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: 'success',
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
        msg: 'Expense not found',
        data: null,
        timestamp: Date.now(),
      });
    }

    expense.isDeleted = true;
    await expense.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: 'Expense deleted',
      data: null,
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { batchUpsert, pull, list, remove };
