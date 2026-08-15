<template>
  <div class="dashboard">
    <div class="toolbar">
      <el-select v-model="year" style="width: 120px" @change="loadData">
        <el-option v-for="y in years" :key="y" :label="y" :value="y" />
      </el-select>
    </div>

    <div class="metric-cards" v-loading="loading">
      <el-card v-for="m in metrics" :key="m.label" class="metric-card">
        <div class="metric-label">{{ m.label }}</div>
        <div class="metric-value" :style="{ color: m.color }">{{ m.value }}</div>
      </el-card>
    </div>

    <div class="charts-row">
      <el-card class="chart-card">
        <h3>Monthly Income Trend</h3>
        <div ref="incomeChartRef" class="chart"></div>
      </el-card>
      <el-card class="chart-card">
        <h3>Monthly Expenses</h3>
        <div ref="expenseBarRef" class="chart"></div>
      </el-card>
    </div>
    <div class="charts-row">
      <el-card class="chart-card">
        <h3>Expense by Category</h3>
        <div ref="expenseChartRef" class="chart"></div>
      </el-card>
      <el-card class="chart-card">
        <h3>Income by Project</h3>
        <div ref="projectBarRef" class="chart"></div>
      </el-card>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import * as echarts from 'echarts'
import { ElMessage } from 'element-plus'
import { reportApi } from '../api'

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const year = ref(new Date().getFullYear())
const years = [year.value - 2, year.value - 1, year.value, year.value + 1].sort((a, b) => a - b)

const loading = ref(false)
const metrics = ref([])

const incomeChartRef = ref(null)
const expenseBarRef = ref(null)
const expenseChartRef = ref(null)
const projectBarRef = ref(null)

const chartCache = {}
const getChart = (ref) => {
  if (!ref.value) return null
  if (!chartCache[ref]) chartCache[ref] = echarts.init(ref.value)
  return chartCache[ref]
}

const money = (n) => `$${(Number(n) || 0).toFixed(2)}`

const loadData = async () => {
  loading.value = true
  try {
    const res = await reportApi.getAnnual({ year: year.value })
    const d = res.data
    metrics.value = [
      { label: 'Annual Income', value: money(d.totalBillableAmount), color: '#10B981' },
      { label: 'Total Hours', value: `${(Number(d.totalBillableHours) || 0).toFixed(1)}h`, color: '#2563EB' },
      { label: 'Total Expenses', value: money(d.totalExpenses), color: '#F59E0B' },
      { label: 'Tax Deductible', value: money(d.taxDeductibleExpenses), color: '#10B981' },
      { label: 'Net Income', value: money(d.netIncome), color: '#2563EB' },
    ]
    renderCharts(d)
  } catch (e) {
    ElMessage.error(e.response?.data?.msg || 'Failed to load report')
  } finally {
    loading.value = false
  }
}

const renderCharts = (d) => {
  const monthly = d.monthlyTrend || []
  const labels = monthly.map((m) => MONTHS[(m.month - 1) % 12])

  const incomeChart = getChart(incomeChartRef)
  if (incomeChart) {
    incomeChart.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: 40, right: 16, top: 24, bottom: 28 },
      xAxis: { type: 'category', data: labels },
      yAxis: { type: 'value' },
      series: [{
        type: 'line',
        data: monthly.map((m) => m.income),
        smooth: true,
        areaStyle: { color: 'rgba(37, 99, 235, 0.1)' },
        itemStyle: { color: '#2563EB' },
      }],
    })
  }

  const expenseBar = getChart(expenseBarRef)
  if (expenseBar) {
    expenseBar.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: 40, right: 16, top: 24, bottom: 28 },
      xAxis: { type: 'category', data: labels },
      yAxis: { type: 'value' },
      series: [{
        type: 'bar',
        data: monthly.map((m) => m.expenses),
        itemStyle: { color: '#F59E0B', borderRadius: [4, 4, 0, 0] },
        barWidth: '55%',
      }],
    })
  }

  const byCategory = d.byCategory || []
  const expenseChart = getChart(expenseChartRef)
  if (expenseChart) {
    expenseChart.setOption({
      tooltip: { trigger: 'item', formatter: '{b}: ${c}' },
      series: [{
        type: 'pie',
        radius: ['40%', '65%'],
        data: byCategory.map((c) => ({ value: c.amount, name: c.category })),
        label: { formatter: '{b}' },
      }],
      color: ['#2563EB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#06B6D4', '#F97316', '#EC4899'],
    })
  }

  const byProject = d.byProject || []
  const projectBar = getChart(projectBarRef)
  if (projectBar) {
    projectBar.setOption({
      tooltip: { trigger: 'axis', formatter: '{b}: ${c}' },
      grid: { left: 40, right: 16, top: 24, bottom: 28 },
      xAxis: { type: 'category', data: byProject.map((p) => p.projectName) },
      yAxis: { type: 'value' },
      series: [{
        type: 'bar',
        data: byProject.map((p) => p.amount),
        itemStyle: { color: '#2563EB', borderRadius: [4, 4, 0, 0] },
        barWidth: '55%',
      }],
    })
  }
}

onMounted(() => {
  loadData()
})
</script>

<style scoped>
.toolbar {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 16px;
}
.metric-cards {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 16px;
  margin-bottom: 24px;
}
.metric-card {
  text-align: center;
}
.metric-label {
  color: #64748b;
  font-size: 13px;
  margin-bottom: 8px;
}
.metric-value {
  font-size: 24px;
  font-weight: bold;
}
.charts-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-bottom: 24px;
}
.chart-card h3 {
  margin: 0 0 16px;
  color: #1e293b;
  font-size: 15px;
}
.chart {
  height: 300px;
}
</style>
