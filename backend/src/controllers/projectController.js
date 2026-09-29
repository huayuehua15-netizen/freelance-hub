const ClientProject = require('../models/ClientProject');
const TimeLog = require('../models/TimeLog');
const ExpenseLog = require('../models/ExpenseLog');
const SyncService = require('../services/syncService');
const { ERROR_CODES, FREE_PROJECT_LIMIT, PREMIUM_TYPES, SYNC_BATCH_LIMIT } = require('../utils/constants');
const { t } = require('../utils/i18n');

const batchUpsert = async (req, res, next) => {
  try {
    const { projects, deviceId } = req.body;
    if (!Array.isArray(projects)) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.sync.projectsArrayRequired', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }
    if (projects.length > SYNC_BATCH_LIMIT) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.sync.batchTooLarge', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    // 单币种强制（v1 策略）：项目货币决定计费金额语义，报表聚合不换算，
    // 与账号货币不一致的项目会把报表金额变成跨币种混加。统一改写为账号货币。
    for (const project of projects) {
      if (project && typeof project === 'object') project.currency = req.user.currency;
    }

    const result = await SyncService.batchUpsert(req.userId, ClientProject, projects, 'projectId');

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
    const limitNum = Math.min(Math.max(parseInt(limit) || 100, 1), 200);

    const result = await SyncService.pullSince(req.userId, ClientProject, sinceTime, limitNum, cursor);

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
    const { status, limit, cursor } = req.query;
    const query = { userId: req.userId, isDeleted: false };
    if (status) query.status = status;

    if (req.user.premiumType === PREMIUM_TYPES.FREE) {
      const allProjects = await ClientProject.find(query).sort({ serverUpdateTime: -1 });
      return res.status(200).json({
        code: ERROR_CODES.SUCCESS,
        msg: t('common.success', req.lang),
        data: {
          projects: allProjects.slice(0, FREE_PROJECT_LIMIT),
          hasMore: false,
          nextCursor: null,
          freeLimit: FREE_PROJECT_LIMIT,
        },
        timestamp: Date.now(),
      });
    }

    const limitNum = Math.min(Math.max(parseInt(limit) || 50, 1), 200);
    // 复合游标 (serverUpdateTime, _id)，与 timelog/expense 的 list 同口径：
    // batchUpsert 给同批记录写同一个 serverUpdateTime，纯时间戳游标在翻页时
    // 会用 $lt 整批排除同毫秒的兄弟记录，导致项目永久丢失。
    if (cursor) {
      const [tsStr, idStr] = cursor.split('_');
      const ts = parseInt(tsStr, 10);
      if (idStr) {
        query.$or = [
          { serverUpdateTime: { $lt: new Date(ts) } },
          { serverUpdateTime: new Date(ts), _id: { $lt: idStr } },
        ];
      } else {
        query.serverUpdateTime = { $lt: new Date(ts) };
      }
    }

    const projects = await ClientProject.find(query)
      .sort({ serverUpdateTime: -1, _id: -1 })
      .limit(limitNum + 1);
    const hasMore = projects.length > limitNum;
    const data = hasMore ? projects.slice(0, limitNum) : projects;
    const last = hasMore ? data[data.length - 1] : null;
    const nextCursor = last ? `${last.serverUpdateTime.getTime()}_${last._id}` : null;

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('common.success', req.lang),
      data: { projects: data, hasMore, nextCursor },
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

const remove = async (req, res, next) => {
  try {
    const { projectId } = req.params;
    const project = await ClientProject.findOne({ userId: req.userId, projectId });

    if (!project) {
      return res.status(404).json({
        code: ERROR_CODES.NOT_FOUND,
        msg: t('errors.project.notFound', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    project.isDeleted = true;
    project.serverUpdateTime = Date.now();
    await project.save();

    // 级联软删（P1 修复）：项目下的工时与开支一并软删并推进 serverUpdateTime，
    // 使移动端/其他设备通过增量 pull 感知删除（软删随同步协议传播，
    // 物理删除会静默丢数据且无法传播到离线端）。
    // 单查询聚合更新，无并发窗口；与项目删除同一事务语义（Mongo 无跨集合事务时
    // 以"已删除项目的数据不可再被报表聚合"为最终一致性目标）。
    const now = Date.now();
    await Promise.all([
      TimeLog.updateMany(
        { userId: req.userId, projectId, isDeleted: false },
        { $set: { isDeleted: true, serverUpdateTime: now } }
      ),
      ExpenseLog.updateMany(
        { userId: req.userId, projectId, isDeleted: false },
        { $set: { isDeleted: true, serverUpdateTime: now } }
      ),
    ]);

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('project.deleted', req.lang),
      data: null,
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { batchUpsert, pull, list, remove };
