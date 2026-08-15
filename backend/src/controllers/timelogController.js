const TimeLog = require('../models/TimeLog');
const SyncService = require('../services/syncService');
const { ERROR_CODES, PREMIUM_TYPES } = require('../utils/constants');

const batchUpsert = async (req, res, next) => {
  try {
    const { timeLogs } = req.body;
    if (!Array.isArray(timeLogs)) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: 'timeLogs must be an array',
        data: null,
        timestamp: Date.now(),
      });
    }

    const result = await SyncService.batchUpsert(req.userId, TimeLog, timeLogs, 'timeLogId');

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

    const result = await SyncService.pullSince(req.userId, TimeLog, sinceTime, limitNum, cursor);

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
    const { projectId, startDate, endDate, limit, cursor } = req.query;
    const query = { userId: req.userId, isDeleted: false };

    if (projectId) query.projectId = projectId;

    const startTimeRange = {};
    if (startDate) startTimeRange.$gte = parseInt(startDate);
    if (endDate) startTimeRange.$lt = parseInt(endDate);
    if (Object.keys(startTimeRange).length) query.startTime = startTimeRange;

    if (req.user.premiumType === PREMIUM_TYPES.FREE) {
      const monthStart = new Date();
      monthStart.setDate(1);
      monthStart.setHours(0, 0, 0, 0);
      query.startTime = { $gte: monthStart.getTime() };
    }

    const limitNum = Math.min(parseInt(limit) || 50, 200);
    if (cursor) query.serverUpdateTime = { $lt: new Date(parseInt(cursor)) };

    const logs = await TimeLog.find(query).sort({ serverUpdateTime: -1 }).limit(limitNum + 1);
    const hasMore = logs.length > limitNum;
    const data = hasMore ? logs.slice(0, limitNum) : logs;
    const nextCursor = hasMore ? data[data.length - 1].serverUpdateTime.getTime() : null;

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: 'success',
      data: { timeLogs: data, hasMore, nextCursor },
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

const remove = async (req, res, next) => {
  try {
    const { timeLogId } = req.params;
    const log = await TimeLog.findOne({ userId: req.userId, timeLogId });

    if (!log) {
      return res.status(404).json({
        code: ERROR_CODES.NOT_FOUND,
        msg: 'Time log not found',
        data: null,
        timestamp: Date.now(),
      });
    }

    log.isDeleted = true;
    await log.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: 'Time log deleted',
      data: null,
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { batchUpsert, pull, list, remove };
