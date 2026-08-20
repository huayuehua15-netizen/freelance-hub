const ClientProject = require('../models/ClientProject');
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
    if (cursor) query.serverUpdateTime = { $lt: new Date(parseInt(cursor)) };

    const projects = await ClientProject.find(query).sort({ serverUpdateTime: -1 }).limit(limitNum + 1);
    const hasMore = projects.length > limitNum;
    const data = hasMore ? projects.slice(0, limitNum) : projects;
    const nextCursor = hasMore ? data[data.length - 1].serverUpdateTime.getTime() : null;

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
    await project.save();

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
