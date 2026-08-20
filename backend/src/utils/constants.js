const ERROR_CODES = {
  SUCCESS: 200,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  RATE_LIMIT: 429,
  INTERNAL_ERROR: 500,
  REFRESH_TOKEN_EXPIRED: 1001,
  FREE_PROJECT_LIMIT: 2001,
  NEED_MONTHLY: 2002,
  NEED_ANNUAL: 2003,
  SYNC_CONFLICT: 3001,
};

const PREMIUM_TYPES = {
  FREE: 'free',
  MONTHLY: 'monthly',
  ANNUAL: 'annual',
};

const FREE_PROJECT_LIMIT = 3;

// 单次同步批量写入上限：防止恶意超大 payload 长时间占用 DB 连接池阻塞事件循环
const SYNC_BATCH_LIMIT = 500;

// IRS Schedule SE 自雇税参数：
// - 应税基数 = 净收益 × 92.35%（雇主份额视同扣除）
// - 基数 < $400 不产生自雇税
// - 社保部分（12.4%）受年度工资基数上限约束，医保部分（2.9%）无上限
// SS 工资基数逐年调整，每年 10 月 SSA 公告后需更新此表。
const SE_TAX = {
  NET_EARNINGS_RATE: 0.9235,
  SS_RATE: 0.124,
  MEDICARE_RATE: 0.029,
  MIN_BASE: 400,
  WAGE_BASE_BY_YEAR: { 2024: 168600, 2025: 176100, 2026: 184500 },
  LATEST_WAGE_BASE: 184500,
};

// 联邦个人所得税（单身申报，Form 1040 预估用）。
// 税法逐年变化，每年须复核（2026 值基于 2025 年通过的税法延期方案估算）。
// ⚠️ 2027 起未收录的年份会回退使用 2026 值（BRACKETS_BY_YEAR[year] ?? 2026）——
// 每年 10 月 IRS 公布新税率后必须在此补当年条目，否则估算会逐年失真。
const FEDERAL_TAX = {
  STANDARD_DEDUCTION_BY_YEAR: { 2025: 15000, 2026: 16100 },
  LATEST_STANDARD_DEDUCTION: 16100,
  BRACKETS_BY_YEAR: {
    2025: [
      { upTo: 11875, rate: 0.1 },
      { upTo: 48475, rate: 0.12 },
      { upTo: 103350, rate: 0.22 },
      { upTo: 197300, rate: 0.24 },
      { upTo: 250525, rate: 0.32 },
      { upTo: 626350, rate: 0.35 },
      { upTo: Infinity, rate: 0.37 },
    ],
    2026: [
      { upTo: 12400, rate: 0.1 },
      { upTo: 50400, rate: 0.12 },
      { upTo: 105700, rate: 0.22 },
      { upTo: 201775, rate: 0.24 },
      { upTo: 256225, rate: 0.32 },
      { upTo: 640600, rate: 0.35 },
      { upTo: Infinity, rate: 0.37 },
    ],
  },
};

module.exports = {
  ERROR_CODES,
  PREMIUM_TYPES,
  FREE_PROJECT_LIMIT,
  SYNC_BATCH_LIMIT,
  SE_TAX,
  FEDERAL_TAX,
};
