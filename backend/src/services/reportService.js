const TimeLog = require('../models/TimeLog');
const ClientProject = require('../models/ClientProject');
const ExpenseLog = require('../models/ExpenseLog');
const {
  getMonthBounds,
  getYearBounds,
  formatDateKey,
  getMonthIndex,
  getQuarterIndex,
} = require('../utils/timezone');
const { SE_TAX, FEDERAL_TAX } = require('../utils/constants');

const round = (n) => Math.round(n * 100) / 100;

/**
 * Schedule SE 自雇税估算（仅参考值）：
 * 1. 净收益 ≈ 可计费收入 - 可抵扣开支（不可抵扣开支不减税基，与 Schedule C 一致）
 * 2. 应税基数 = 净收益 × 92.35%；基数 < $400 时无需缴纳
 * 3. 社保部分受年度工资基数上限约束，医保部分无上限
 */
const estimateSelfEmploymentTax = (billableAmount, taxDeductibleExpenses, year) => {
  const netEarnings = Math.max(0, billableAmount - taxDeductibleExpenses);
  const base = netEarnings * SE_TAX.NET_EARNINGS_RATE;
  if (base < SE_TAX.MIN_BASE) return 0;
  const wageBase = SE_TAX.WAGE_BASE_BY_YEAR[year] ?? SE_TAX.LATEST_WAGE_BASE;
  return Math.min(base, wageBase) * SE_TAX.SS_RATE + base * SE_TAX.MEDICARE_RATE;
};

/** 联邦个税（单身申报，累进税率表）。 */
const federalIncomeTax = (taxableIncome, year) => {
  const brackets = FEDERAL_TAX.BRACKETS_BY_YEAR[year] ?? FEDERAL_TAX.BRACKETS_BY_YEAR[2026];
  let tax = 0;
  let lower = 0;
  for (const b of brackets) {
    if (taxableIncome <= lower) break;
    const span = Math.min(taxableIncome, b.upTo) - lower;
    tax += span * b.rate;
    lower = b.upTo;
  }
  return tax;
};

/**
 * 季度预缴税估算（Form 1040-ES，简化版，仅供参考）：
 * - 自雇税 + 联邦个税（AGI 近似 = 净收益 - 自雇税的可抵扣半额，再减标准扣除）
 * - 每季度建议缴纳 = 全年估算 ÷ 4（未做 safe harbor 90%/100% 规则判断）
 */
const estimateQuarterlyTaxes = (billableAmount, taxDeductibleExpenses, year) => {
  const netEarnings = Math.max(0, billableAmount - taxDeductibleExpenses);
  const seTax = estimateSelfEmploymentTax(billableAmount, taxDeductibleExpenses, year);
  const stdDeduction = FEDERAL_TAX.STANDARD_DEDUCTION_BY_YEAR[year] ?? FEDERAL_TAX.LATEST_STANDARD_DEDUCTION;
  const taxableIncome = Math.max(0, netEarnings - seTax / 2 - stdDeduction);
  const incomeTax = federalIncomeTax(taxableIncome, year);
  const total = seTax + incomeTax;
  return {
    netEarningsForTax: round(netEarnings),
    selfEmploymentTax: round(seTax),
    federalIncomeTax: round(incomeTax),
    totalAnnualEstimate: round(total),
    perQuarterSuggestion: round(total / 4),
    taxableIncome: round(taxableIncome),
  };
};

class ReportService {
  /**
   * 月度报表：按用户时区划月界，跨时区用户的工时/开支归类正确。
   * 例：美东用户 1 月 31 日 23:00 工作到 2 月 1 日 00:00（本地时间），
   *     UTC 是 2 月 1 日 04:00-05:00，但应归到 1 月。
   *
   * @param {string} userId
   * @param {number} year
   * @param {number} month 1-12
   * @param {string|null} projectId 可选，仅统计该项目
   * @param {string} timezone IANA 时区，如 'America/New_York'
   */
  static async getMonthlyReport(userId, year, month, projectId = null, timezone = 'America/New_York') {
    // 按用户时区计算月界（DST 自动处理），返回 UTC 毫秒，可直接用于 DB 查询
    const { start: startDate, end: endDate } = getMonthBounds(year, month, timezone);

    const timeQuery = {
      userId,
      isDeleted: false,
      isBillable: true,
      startTime: { $gte: startDate, $lt: endDate },
    };
    if (projectId) timeQuery.projectId = projectId;

    const expenseQuery = {
      userId,
      isDeleted: false,
      expenseDate: { $gte: startDate, $lt: endDate },
    };
    if (projectId) expenseQuery.projectId = projectId;

    const [timeLogs, expenseLogs, projects] = await Promise.all([
      TimeLog.find(timeQuery),
      ExpenseLog.find(expenseQuery),
      ClientProject.find({ userId, isDeleted: false }),
    ]);

    const projectMap = {};
    projects.forEach((p) => {
      projectMap[p.projectId] = p;
    });

    let totalBillableHours = 0;
    let totalBillableAmount = 0;
    const hoursByProject = {};
    const dailyHoursTrend = {};

    for (const log of timeLogs) {
      totalBillableHours += log.duration;
      totalBillableAmount += log.billableAmount;

      if (!hoursByProject[log.projectId]) {
        hoursByProject[log.projectId] = { hours: 0, amount: 0 };
      }
      hoursByProject[log.projectId].hours += log.duration;
      hoursByProject[log.projectId].amount += log.billableAmount;

      // 按用户时区格式化日期，避免 UTC 跨日归类错误
      const day = formatDateKey(log.startTime, timezone);
      dailyHoursTrend[day] = (dailyHoursTrend[day] || 0) + log.duration;
    }

    let totalExpenses = 0;
    let taxDeductibleExpenses = 0;
    let nonDeductibleExpenses = 0;
    const expensesByCategory = {};

    for (const exp of expenseLogs) {
      totalExpenses += exp.amount;
      if (exp.isTaxDeductible) {
        taxDeductibleExpenses += exp.amount;
      } else {
        nonDeductibleExpenses += exp.amount;
      }
      if (!expensesByCategory[exp.category]) {
        expensesByCategory[exp.category] = { amount: 0, isTaxDeductible: exp.isTaxDeductible };
      }
      expensesByCategory[exp.category].amount += exp.amount;
    }

    return {
      period: `${year}-${String(month).padStart(2, '0')}`,
      timezone,
      totalBillableHours: round(totalBillableHours),
      totalBillableAmount: round(totalBillableAmount),
      totalExpenses: round(totalExpenses),
      taxDeductibleExpenses: round(taxDeductibleExpenses),
      nonDeductibleExpenses: round(nonDeductibleExpenses),
      netIncome: round(totalBillableAmount - totalExpenses),
      hoursByProject: Object.entries(hoursByProject).map(([pid, data]) => ({
        projectId: pid,
        projectName: projectMap[pid]?.projectName || 'Unknown',
        hours: round(data.hours),
        amount: round(data.amount),
      })),
      expensesByCategory: Object.entries(expensesByCategory).map(([cat, data]) => ({
        category: cat,
        amount: round(data.amount),
        isTaxDeductible: data.isTaxDeductible,
      })),
      dailyHoursTrend: Object.entries(dailyHoursTrend).map(([date, hours]) => ({
        date,
        hours: round(hours),
      })).sort((a, b) => a.date.localeCompare(b.date)),
    };
  }

  /**
   * 年度报税汇总：按用户时区划年界，跨年工时归类正确。
   *
   * @param {string} userId
   * @param {number} year
   * @param {string} timezone IANA 时区
   */
  static async getAnnualReport(userId, year, timezone = 'America/New_York') {
    // 按用户时区计算年界（DST 自动处理）
    const { start: startDate, end: endDate } = getYearBounds(year, timezone);

    const [timeLogs, expenseLogs, projects] = await Promise.all([
      TimeLog.find({ userId, isDeleted: false, isBillable: true, startTime: { $gte: startDate, $lt: endDate } }),
      ExpenseLog.find({ userId, isDeleted: false, expenseDate: { $gte: startDate, $lt: endDate } }),
      ClientProject.find({ userId, isDeleted: false }),
    ]);

    const projectMap = {};
    projects.forEach((p) => { projectMap[p.projectId] = p; });

    const monthlyTrend = Array.from({ length: 12 }, (_, i) => ({ month: i + 1, income: 0, expenses: 0 }));
    const quarters = Array.from({ length: 4 }, (_, i) => ({
      quarter: `Q${i + 1}`,
      totalBillableHours: 0,
      totalBillableAmount: 0,
      totalExpenses: 0,
      taxDeductibleExpenses: 0,
    }));
    const byProjectMap = {};
    const byCategoryMap = {};

    let totalBillableHours = 0;
    let totalBillableAmount = 0;

    for (const log of timeLogs) {
      totalBillableHours += log.duration;
      // 收入只累计可计费工时（防御历史同步数据中非计费但金额未清零的记录）
      const income = log.isBillable ? log.billableAmount : 0;
      totalBillableAmount += income;
      // 按用户时区归类月份/季度，避免 UTC 跨月错误
      const monthIdx = getMonthIndex(log.startTime, timezone);
      const q = getQuarterIndex(log.startTime, timezone);
      monthlyTrend[monthIdx].income += income;
      quarters[q].totalBillableHours += log.duration;
      quarters[q].totalBillableAmount += income;

      const pid = log.projectId;
      if (!byProjectMap[pid]) {
        byProjectMap[pid] = { projectId: pid, projectName: projectMap[pid]?.projectName || 'Unknown', hours: 0, amount: 0 };
      }
      byProjectMap[pid].hours += log.duration;
      byProjectMap[pid].amount += income;
    }

    let totalExpenses = 0;
    let taxDeductibleExpenses = 0;

    for (const exp of expenseLogs) {
      totalExpenses += exp.amount;
      if (exp.isTaxDeductible) taxDeductibleExpenses += exp.amount;
      const monthIdx = getMonthIndex(exp.expenseDate, timezone);
      const q = getQuarterIndex(exp.expenseDate, timezone);
      monthlyTrend[monthIdx].expenses += exp.amount;
      quarters[q].totalExpenses += exp.amount;
      if (exp.isTaxDeductible) quarters[q].taxDeductibleExpenses += exp.amount;

      const cat = exp.category;
      if (!byCategoryMap[cat]) {
        byCategoryMap[cat] = { category: cat, amount: 0, isTaxDeductible: exp.isTaxDeductible };
      }
      byCategoryMap[cat].amount += exp.amount;
    }

    const netIncome = totalBillableAmount - totalExpenses;
    // Schedule SE：税基只减可抵扣开支（92.35% 系数 + 工资基数上限 + $400 起征）
    const estimatedSelfEmploymentTax = estimateSelfEmploymentTax(
      totalBillableAmount,
      taxDeductibleExpenses,
      year,
    );

    // 明细列表：供 Web 后台 Dashboard 明细 Tab 展示。
    // 复用本次查询的 timeLogs/expenseLogs（已按用户时区年界过滤），
    // 保证明细与图表/汇总的时区归类完全一致，避免前端按 UTC 年界拉取导致跨年错位。
    // 注意：仅返回展示所需字段，剔除 userId/isDeleted 等内部字段，控制响应体积。
    const timeLogDetails = timeLogs
      .map((log) => ({
        timeLogId: log.timeLogId,
        projectId: log.projectId,
        projectName: projectMap[log.projectId]?.projectName || 'Unknown',
        startTime: log.startTime,
        endTime: log.endTime,
        duration: round(log.duration),
        isBillable: log.isBillable,
        billableAmount: round(log.billableAmount),
        tag: log.tag || '',
        note: log.note || '',
      }))
      .sort((a, b) => b.startTime - a.startTime);

    const expenseDetails = expenseLogs
      .map((exp) => ({
        expenseId: exp.expenseId,
        projectId: exp.projectId,
        projectName: exp.projectId ? (projectMap[exp.projectId]?.projectName || '') : '',
        amount: round(exp.amount),
        currency: exp.currency || 'USD',
        expenseDate: exp.expenseDate,
        category: exp.category || '',
        isTaxDeductible: !!exp.isTaxDeductible,
        merchant: exp.merchant || '',
        note: exp.note || '',
      }))
      .sort((a, b) => b.expenseDate - a.expenseDate);

    return {
      year,
      timezone,
      totalBillableHours: round(totalBillableHours),
      totalBillableAmount: round(totalBillableAmount),
      totalExpenses: round(totalExpenses),
      taxDeductibleExpenses: round(taxDeductibleExpenses),
      nonDeductibleExpenses: round(totalExpenses - taxDeductibleExpenses),
      netIncome: round(netIncome),
      estimatedSelfEmploymentTax: round(estimatedSelfEmploymentTax),
      quarterlyTaxEstimate: estimateQuarterlyTaxes(totalBillableAmount, taxDeductibleExpenses, year),
      disclaimer: 'Estimate only, not tax advice. Consult a certified tax professional.',
      monthlyTrend: monthlyTrend.map((m) => ({ month: m.month, income: round(m.income), expenses: round(m.expenses) })),
      quarters: quarters.map((q) => ({
        quarter: q.quarter,
        totalBillableHours: round(q.totalBillableHours),
        totalBillableAmount: round(q.totalBillableAmount),
        totalExpenses: round(q.totalExpenses),
        taxDeductibleExpenses: round(q.taxDeductibleExpenses),
      })),
      byProject: Object.values(byProjectMap)
        .map((p) => ({ projectId: p.projectId, projectName: p.projectName, hours: round(p.hours), amount: round(p.amount) }))
        .sort((a, b) => b.amount - a.amount),
      byCategory: Object.values(byCategoryMap)
        .map((c) => ({ category: c.category, amount: round(c.amount), isTaxDeductible: c.isTaxDeductible }))
        .sort((a, b) => b.amount - a.amount),
      timeLogDetails,
      expenseDetails,
    };
  }
}

module.exports = ReportService;
