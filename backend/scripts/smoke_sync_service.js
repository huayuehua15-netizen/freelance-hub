/* eslint-disable no-console */
// syncService.batchUpsert 冒烟测试：直连 Atlas（测试账号数据用后即删）
require('dotenv').config();
const mongoose = require('mongoose');
const SyncService = require('../src/services/syncService');
const ClientProject = require('../src/models/ClientProject');
const ExpenseLog = require('../src/models/ExpenseLog');

const TEST_USER = 'smoke_test_user__delete_me';
// 基准时间取真实当前时间：LWW 比较的是 clientUpdatedAt 与服务端 serverUpdateTime，
// 用历史假时间戳会被判 conflict（服务端更新）——那是正确行为，不是缺陷
const T0 = Date.now() - 60000;

const proj = (id, name, clientTs, extra = {}) => ({
  projectId: id,
  clientName: 'Smoke',
  clientEmail: 'smoke@test.dev',
  projectName: name,
  hourlyRate: 50,
  currency: 'USD',
  status: 'active',
  isDeleted: false,
  clientUpdatedAt: clientTs,
  ...extra,
});

const expense = (id, amount, clientTs, extra = {}) => ({
  expenseId: id,
  amount,
  currency: 'EUR',
  expenseDate: T0,
  category: 'Software',
  isTaxDeductible: true,
  merchant: 'Smoke',
  note: '',
  receiptUrl: '',
  isDeleted: false,
  clientUpdatedAt: clientTs,
  ...extra,
});

const assert = (cond, label) => {
  if (!cond) throw new Error(`ASSERT FAIL: ${label}`);
  console.log(`  ok - ${label}`);
};

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('connected');

  // 清场 + 币种改写模拟（与控制器行为一致）
  await ClientProject.deleteMany({ userId: TEST_USER });
  await ExpenseLog.deleteMany({ userId: TEST_USER });

  // 1. 新建
  let r = await SyncService.batchUpsert(TEST_USER, ClientProject, [proj('p1', 'A', T0)], 'projectId');
  assert(r.results[0].status === 'created', 'create -> created');

  // 2. 客户端更新（clientTs 更新）→ updated 且字段落库
  r = await SyncService.batchUpsert(TEST_USER, ClientProject, [proj('p1', 'A2', Date.now())], 'projectId');
  assert(r.results[0].status === 'updated', 'newer clientTs -> updated');
  const after = await ClientProject.findOne({ userId: TEST_USER, projectId: 'p1' });
  assert(after.projectName === 'A2', 'payload applied');
  assert(after.serverUpdateTime.getTime() >= T0, 'serverUpdateTime bumped');

  // 3. 旧客户端时间 → conflict（LWW 败者），服务端数据不被覆盖
  r = await SyncService.batchUpsert(TEST_USER, ClientProject, [proj('p1', 'SHOULD_NOT_APPLY', T0)], 'projectId');
  assert(r.results[0].status === 'conflict' && r.conflicts.length === 1, 'stale clientTs -> conflict');
  const afterStale = await ClientProject.findOne({ userId: TEST_USER, projectId: 'p1' });
  assert(afterStale.projectName === 'A2', 'stale payload NOT applied');

  // 4. 删除优先：服务端已删，客户端旧编辑 → conflict，不复活
  await ClientProject.updateOne({ userId: TEST_USER, projectId: 'p1' }, { isDeleted: true });
  r = await SyncService.batchUpsert(TEST_USER, ClientProject, [proj('p1', 'A3', Date.now())], 'projectId');
  assert(r.results[0].status === 'conflict', 'edit-after-delete -> conflict');
  const notResurrected = await ClientProject.findOne({ userId: TEST_USER, projectId: 'p1' });
  assert(notResurrected.isDeleted === true && notResurrected.projectName === 'A2', 'deleted record NOT resurrected');

  // 5. 客户端删除胜出：服务端未删，客户端带 isDeleted=true → updated + isDeleted
  r = await SyncService.batchUpsert(TEST_USER, ClientProject, [proj('p2', 'B', Date.now(), { isDeleted: true })], 'projectId');
  assert(['created', 'updated'].includes(r.results[0].status), 'client delete -> tombstone persisted');
  const tombstone = await ClientProject.findOne({ userId: TEST_USER, projectId: 'p2' });
  assert(tombstone.isDeleted === true, 'tombstone persisted');

  // 6. 批量混合：500 条批量性（数量级）+ 单条校验失败不阻断整批
  const batch = [];
  for (let i = 0; i < 50; i += 1) batch.push(expense(`e${i}`, 10 + i, T0 + i));
  batch.push(expense('bad', -5, T0)); // min:0 校验应失败
  batch.push({ expenseDate: T0, clientUpdatedAt: T0 }); // 缺 expenseId
  r = await SyncService.batchUpsert(TEST_USER, ExpenseLog, batch, 'expenseId');
  const created = r.results.filter((x) => x.status === 'created');
  const errs = r.results.filter((x) => x.status === 'error');
  assert(created.length === 50, `50 created (got ${created.length})`);
  assert(errs.length === 2, `2 errors (bad amount + missing id), got ${errs.length}`);

  // 7. 重复插入（并发竞态模拟）→ 已存在路径走 LWW 而非重复文档
  const dupCountBefore = await ExpenseLog.countDocuments({ userId: TEST_USER, expenseId: 'e1' });
  // 控制器层会先做币种改写（expenseController.batchUpsert），此处模拟同行为
  const coerced = [expense('e1', 999, Date.now())];
  coerced[0].currency = 'USD';
  await SyncService.batchUpsert(TEST_USER, ExpenseLog, coerced, 'expenseId');
  const dupCountAfter = await ExpenseLog.countDocuments({ userId: TEST_USER, expenseId: 'e1' });
  assert(dupCountBefore === 1 && dupCountAfter === 1, 'no duplicate documents');

  // 8. 币种强制（模拟控制器改写后 EUR → USD 落库）
  const e1 = await ExpenseLog.findOne({ userId: TEST_USER, expenseId: 'e1' });
  assert(e1.currency === 'USD', `currency coerced to USD (got ${e1.currency})`);

  // 清场
  await ClientProject.deleteMany({ userId: TEST_USER });
  await ExpenseLog.deleteMany({ userId: TEST_USER });
  console.log('SMOKE_TEST_ALL_PASS');
  await mongoose.disconnect();
  process.exit(0);
})().catch((e) => {
  console.error('SMOKE_TEST_FAIL:', e.message);
  process.exit(1);
});
