const ClientProject = require('../models/ClientProject');
const TimeLog = require('../models/TimeLog');
const ExpenseLog = require('../models/ExpenseLog');

class SyncService {
  /**
   * 批量 upsert（增量同步推送入口）。
   *
   * 性能：旧实现逐条 findOne + save，500 条记录 = 最多 ~1000 次串行往返
   * Atlas，Render free + M0 上容易拖到请求超时。现改为：
   *   1. 一次 $in 查询加载全部已存在记录
   *   2. 内存中完成 LWW/delete-wins 仲裁
   *   3. 新建走 insertMany(ordered:false)，更新走 bulkWrite(ordered:false)
   *      （filter 带 serverUpdateTime 乐观锁：并发竞争时败者 matched 不到，
   *        不会发生"后写者无条件覆盖"）
   *
   * 语义（勿回归，与移动端 SyncService 契约一致）：
   * - results: [{[idField], status: created|updated|conflict|error, serverUpdateTime, conflict}]
   * - 删除永远优先；clientTs >= serverTs 时客户端覆盖服务端
   * - 单条失败不抛出，以 status=error 返回，不阻断整批
   */
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

    // 预处理：清洗 payload、校验归属、构造 Mongoose 文档完成 cast/strict 剥离与校验
    const parsed = records.map((record) => {
      const id = record?.[idField];
      if (!record || typeof record !== 'object' || !id) {
        return { id, error: `${idField} is required` };
      }
      if (validProjectIds && record.projectId && !validProjectIds.has(record.projectId)) {
        return { id, error: `projectId ${record.projectId} does not belong to this user` };
      }
      // 排除同步管控字段，避免污染 Mongoose 文档
      const { clientUpdatedAt, deviceId, userId: ignoredUserId, serverCreateTime, serverUpdateTime, _id, __v, ...payload } = record;
      // 经 Mongoose 文档 cast + strict 剥离未知字段 + validateSync（保留 min:0 等校验），
      // toObject() 产出可直接 $set 的干净 POJO。userId 以认证值参与校验（required），
      // 且 $set/insert 时写入同值无副作用。
      const doc = new model({ userId, ...payload });
      const validationError = doc.validateSync();
      if (validationError) {
        return { id, error: validationError.message };
      }
      // toObject() 会带上新生成的 _id/__v，不得进入 $set/insert（_id 不可变且须由 MongoDB 生成）
      const clean = doc.toObject();
      delete clean._id;
      delete clean.__v;
      return { id, clientUpdatedAt, payload: clean, isDeleted: !!payload.isDeleted };
    });

    // 一次加载全部已存在记录
    const ids = parsed.filter((p) => p.id != null).map((p) => p.id);
    const existingMap = new Map();
    if (ids.length > 0) {
      const existingDocs = await model.find({ userId, [idField]: { $in: ids } });
      for (const doc of existingDocs) existingMap.set(doc[idField], doc);
    }

    const now = new Date();
    const createDocs = [];
    const bulkOps = [];
    const bulkMeta = []; // 与 bulkOps 一一对应：{ id, clientTs, baseServerTs }，乐观锁失败时复查用

    for (let i = 0; i < parsed.length; i += 1) {
      const item = parsed[i];
      const id = item.id;
      const resultOf = (status, serverTime, conflict = false) => {
        const r = { [idField]: id, status, conflict };
        if (serverTime != null) r.serverUpdateTime = serverTime;
        return r;
      };

      if (item.error) {
        results.push({ [idField]: id ?? null, status: 'error', error: item.error, conflict: false });
        continue;
      }

      const existing = existingMap.get(id);
      if (!existing) {
        createDocs.push({ userId, ...item.payload, serverCreateTime: now, serverUpdateTime: now });
        results.push(resultOf('created', now.getTime()));
        continue;
      }

      const clientTs = item.clientUpdatedAt || Date.now();
      const serverTs = existing.serverUpdateTime.getTime();

      // Deletion always wins.  Without this branch a newer edit from
      // another device can resurrect a record that was deliberately
      // deleted, producing the "ghost data" the sync spec forbids.
      if (existing.isDeleted || item.isDeleted) {
        const isConflict = existing.isDeleted && !item.isDeleted;
        if (isConflict) {
          conflicts.push({ [idField]: id, serverVersion: existing.toObject(), clientVersion: item.payload });
          results.push(resultOf('conflict', serverTs, true));
        } else if (!existing.isDeleted) {
          // 删除胜出：落一个 isDeleted 标记，serverUpdateTime 前推使删除能同步到其他设备
          bulkOps.push({
            updateOne: {
              filter: { userId, [idField]: id, serverUpdateTime: existing.serverUpdateTime },
              update: { $set: { isDeleted: true, serverUpdateTime: now } },
            },
          });
          bulkMeta.push({ id, clientTs, baseServerTs: existing.serverUpdateTime, kind: 'delete', record: item.payload });
          results.push(resultOf('updated', now.getTime()));
        } else {
          // 双方均已删除：幂等，无写入
          results.push(resultOf('updated', serverTs));
        }
        continue;
      }

      if (clientTs >= serverTs) {
        bulkOps.push({
          updateOne: {
            filter: { userId, [idField]: id, serverUpdateTime: existing.serverUpdateTime },
            update: { $set: { ...item.payload, serverUpdateTime: now } },
          },
        });
        bulkMeta.push({ id, clientTs, baseServerTs: existing.serverUpdateTime, kind: 'update', record: item.payload });
        results.push(resultOf('updated', now.getTime()));
      } else {
        conflicts.push({ [idField]: id, serverVersion: existing.toObject(), clientVersion: item.payload });
        results.push(resultOf('conflict', serverTs, true));
      }
    }

    // 执行写入：insertMany 负责新建，bulkWrite 负责更新/删除
    if (createDocs.length > 0) {
      try {
        await model.insertMany(createDocs, { ordered: false });
      } catch (err) {
        // ordered:false：并发/重复插入的 E11000 只影响对应记录。
        // 极端情况下（同毫秒双端首建）标记 conflict 交由客户端重试拉取。
        const failedIds = new Set(
          (err?.writeErrors || []).map((we) => String(we?.op?.[idField])),
        );
        if (!err?.writeErrors?.length) throw err;
        for (let i = 0; i < results.length; i += 1) {
          const r = results[i];
          if (r.status === 'created' && failedIds.has(String(r[idField]))) {
            r.status = 'conflict';
            r.conflict = true;
          }
        }
      }
    }

    if (bulkOps.length > 0) {
      const res = await model.bulkWrite(bulkOps, { ordered: false });
      // 乐观锁失配（并发写把 serverUpdateTime 顶掉）：逐条复查真实状态，
      // 保证返回给客户端的 per-record status 仍然准确
      if (res.matchedCount < bulkOps.length) {
        const racedMeta = bulkMeta.filter((m) => m.kind === 'update' || m.kind === 'delete');
        // 粗粒度：无法从聚合结果定位具体 op，重新加载本批 id 再按 LWW 修正状态
        const racedIds = racedMeta.map((m) => m.id);
        const after = await model.find({ userId, [idField]: { $in: racedIds } });
        const afterMap = new Map(after.map((d) => [d[idField], d]));
        for (const r of results) {
          const meta = racedMeta.find((m) => m.id === r[idField]);
          const current = afterMap.get(r[idField]);
          if (!meta || !current || r.status !== 'updated') continue;
          const serverTsNow = current.serverUpdateTime.getTime();
          if (serverTsNow !== now.getTime() && meta.clientTs < serverTsNow) {
            // 本批写入后又被并发覆盖，且并发者比客户端新 → 按冲突上报
            r.status = 'conflict';
            r.conflict = true;
            r.serverUpdateTime = serverTsNow;
            conflicts.push({ [idField]: r[idField], serverVersion: current.toObject(), clientVersion: meta.record });
          }
        }
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
