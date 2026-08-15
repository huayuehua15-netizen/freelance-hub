const ClientProject = require('../models/ClientProject');
const TimeLog = require('../models/TimeLog');
const ExpenseLog = require('../models/ExpenseLog');

class SyncService {
  static async batchUpsert(userId, model, records, idField) {
    const results = [];
    const conflicts = [];

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
      .limit(limit + 1);

    const hasMore = records.length > limit;
    const data = hasMore ? records.slice(0, limit) : records;
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
