const ClientProject = require('../models/ClientProject');
const TimeLog = require('../models/TimeLog');
const ExpenseLog = require('../models/ExpenseLog');

class SyncService {
  static async batchUpsert(userId, model, records, idField) {
    const results = [];
    const conflicts = [];

    // 工时/开支同步时预加载该用户全部 projectId（含已软删：删项目后工时仍保留），
    // 拒绝引用不属于本用户的项目，防止伪造数据归属破坏报表一致性
    let validProjectIds = null;
    if (idField === 'timeLogId' || idField === 'expenseId') {
      const userProjects = await ClientProject.find({ userId }, { projectId: 1, _id: 0 });
      validProjectIds = new Set(userProjects.map((p) => p.projectId));
    }

    for (const record of records) {
      try {
        if (!record || typeof record !== 'object' || !record[idField]) {
          throw new Error(`${idField} is required`);
        }
        const existing = await model.findOne({ userId, [idField]: record[idField] });
        // 排除同步管控字段，避免污染 Mongoose 文档
        const {
          clientUpdatedAt,
          deviceId,
          userId: ignoredUserId,
          serverCreateTime,
          serverUpdateTime,
          _id,
          __v,
          ...payload
        } = record;

        // projectId 归属校验：开支的 projectId 可为空（跳过），非空则必须属于本用户
        if (validProjectIds && payload.projectId && !validProjectIds.has(payload.projectId)) {
          throw new Error(`projectId ${payload.projectId} does not belong to this user`);
        }

        if (existing) {
          const clientTs = clientUpdatedAt || Date.now();
          const serverTs = existing.serverUpdateTime.getTime();

          // Deletion always wins.  Without this branch a newer edit from
          // another device can resurrect a record that was deliberately
          // deleted, producing the "ghost data" the sync spec forbids.
          if (existing.isDeleted || payload.isDeleted) {
            if (!existing.isDeleted) {
              existing.isDeleted = true;
              await existing.save();
            }
            const isConflict = existing.isDeleted && !payload.isDeleted;
            if (isConflict) {
              conflicts.push({
                [idField]: record[idField],
                serverVersion: existing.toObject(),
                clientVersion: record,
              });
            }
            results.push({
              [idField]: record[idField],
              status: isConflict ? 'conflict' : 'updated',
              serverUpdateTime: existing.serverUpdateTime.getTime(),
              conflict: isConflict,
            });
          } else if (clientTs >= serverTs) {
            Object.assign(existing, payload);
            await existing.save();
            results.push({
              [idField]: record[idField],
              status: 'updated',
              serverUpdateTime: existing.serverUpdateTime.getTime(),
              conflict: false,
            });
          } else {
            conflicts.push({
              [idField]: record[idField],
              serverVersion: existing.toObject(),
              clientVersion: record,
            });
            results.push({
              [idField]: record[idField],
              status: 'conflict',
              serverUpdateTime: existing.serverUpdateTime.getTime(),
              conflict: true,
            });
          }
        } else {
          const newRecord = await model.create({ userId, ...payload });
          results.push({
            [idField]: record[idField],
            status: 'created',
            serverUpdateTime: newRecord.serverUpdateTime.getTime(),
            conflict: false,
          });
        }
      } catch (error) {
        results.push({
          [idField]: record[idField],
          status: 'error',
          error: error.message,
          conflict: false,
        });
      }
    }

    return { results, conflicts };
  }

  static async pullSince(userId, model, since, limit = 100, cursor = null) {
    // 防御：limit 钳制到 [1, 500]——负值/0/非数字直接归一，防 Mongoose .limit(负数) 报错（L3）
    const safeLimit = Math.max(1, Math.min(Number.parseInt(limit, 10) || 100, 500));
    const sinceDate = new Date(since);
    const query = { userId };

    if (cursor) {
      const separator = String(cursor).lastIndexOf(':');
      const cursorTime = Number.parseInt(separator > 0 ? String(cursor).slice(0, separator) : cursor, 10);
      const cursorId = separator > 0 ? String(cursor).slice(separator + 1) : null;
      const cursorDate = new Date(cursorTime);
      if (!Number.isFinite(cursorTime) || Number.isNaN(cursorDate.getTime())) {
        throw new Error('Invalid sync cursor');
      }
      // The timestamp alone is not unique: MongoDB can assign the same
      // millisecond to several writes.  `_id` makes the descending cursor
      // stable, so a page boundary cannot skip sibling records.
      query.$and = [
        { serverUpdateTime: { $gte: sinceDate } },
        cursorId
          ? {
              $or: [
                { serverUpdateTime: { $lt: cursorDate } },
                { serverUpdateTime: cursorDate, _id: { $lt: cursorId } },
              ],
            }
          : { serverUpdateTime: { $lt: cursorDate } },
      ];
    } else {
      query.serverUpdateTime = { $gte: sinceDate };
    }

    const records = await model
      .find(query)
      .sort({ serverUpdateTime: -1, _id: -1 })
      .limit(safeLimit + 1);

    const hasMore = records.length > safeLimit;
    const data = hasMore ? records.slice(0, safeLimit) : records;
    const last = data[data.length - 1];
    const nextCursor = hasMore ? `${last.serverUpdateTime.getTime()}:${last._id}` : null;

    return {
      data: data.map((r) => r.toObject()),
      hasMore,
      nextCursor,
    };
  }
}

module.exports = SyncService;
