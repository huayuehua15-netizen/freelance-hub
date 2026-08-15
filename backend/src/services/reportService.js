const TimeLog = require('../models/TimeLog');
const ClientProject = require('../models/ClientProject');
const ExpenseLog = require('../models/ExpenseLog');

class ReportService {
  static async getMonthlyReport(userId, year, month, projectId = null) {
    const startDate = new Date(Date.UTC(year, month - 1, 1)).getTime();
    const endDate = new Date(Date.UTC(year, month, 1)).getTime();

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

      const day = new Date(log.startTime).toISOString().split('T')[0];
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
      totalBillableHours: Math.round(totalBillableHours * 100) / 100,
      totalBillableAmount: Math.round(totalBillableAmount * 100) / 100,
      totalExpenses: Math.round(totalExpenses * 100) / 100,
      taxDeductibleExpenses: Math.round(taxDeductibleExpenses * 100) / 100,
      nonDeductibleExpenses: Math.round(nonDeductibleExpenses * 100) / 100,
      netIncome: Math.round((totalBillableAmount - totalExpenses) * 100) / 100,
      hoursByProject: Object.entries(hoursByProject).map(([pid, data]) => ({
        projectId: pid,
        projectName: projectMap[pid]?.projectName || 'Unknown',
        hours: Math.round(data.hours * 100) / 100,
        amount: Math.round(data.amount * 100) / 100,
      })),
      expensesByCategory: Object.entries(expensesByCategory).map(([cat, data]) => ({
        category: cat,
        amount: Math.round(data.amount * 100) / 100,
        isTaxDeductible: data.isTaxDeductible,
      })),
      dailyHoursTrend: Object.entries(dailyHoursTrend).map(([date, hours]) => ({
        date,
        hours: Math.round(hours * 100) / 100,
      })).sort((a, b) => a.date.localeCompare(b.date)),
    };
  }

  static async getAnnualReport(userId, year) {
    // 一次性查询全年数据，避免逐月 12 次查询，并补齐 Web 大屏所需的
    // 逐月趋势 / 按项目 / 按类目 三组聚合（文档 §3.6「按季度拆分、按项目汇总、按类目汇总」）。
    const startDate = new Date(Date.UTC(year, 0, 1)).getTime();
    const endDate = new Date(Date.UTC(year + 1, 0, 1)).getTime();

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
      totalBillableAmount += log.billableAmount;
      const monthIdx = new Date(log.startTime).getUTCMonth();
      const q = Math.floor(monthIdx / 3);
      monthlyTrend[monthIdx].income += log.billableAmount;
      quarters[q].totalBillableHours += log.duration;
      quarters[q].totalBillableAmount += log.billableAmount;

      const pid = log.projectId;
      if (!byProjectMap[pid]) {
        byProjectMap[pid] = { projectId: pid, projectName: projectMap[pid]?.projectName || 'Unknown', hours: 0, amount: 0 };
      }
      byProjectMap[pid].hours += log.duration;
      byProjectMap[pid].amount += log.billableAmount;
    }

    let totalExpenses = 0;
    let taxDeductibleExpenses = 0;

    for (const exp of expenseLogs) {
      totalExpenses += exp.amount;
      if (exp.isTaxDeductible) taxDeductibleExpenses += exp.amount;
      const monthIdx = new Date(exp.expenseDate).getUTCMonth();
      const q = Math.floor(monthIdx / 3);
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
    const estimatedSelfEmploymentTax = netIncome * 0.153;
    const round = (n) => Math.round(n * 100) / 100;

    return {
      year,
      totalBillableHours: round(totalBillableHours),
      totalBillableAmount: round(totalBillableAmount),
      totalExpenses: round(totalExpenses),
      taxDeductibleExpenses: round(taxDeductibleExpenses),
      nonDeductibleExpenses: round(totalExpenses - taxDeductibleExpenses),
      netIncome: round(netIncome),
      estimatedSelfEmploymentTax: round(estimatedSelfEmploymentTax),
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
    };
  }
}

module.exports = ReportService;
