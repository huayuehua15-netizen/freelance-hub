<template>
  <div class="dashboard">
    <div class="toolbar">
      <el-select v-model="year" style="width: 120px" @change="loadData">
        <el-option v-for="y in years" :key="y" :label="y" :value="y" />
      </el-select>
    </div>

    <el-tabs v-model="activeTab" class="dashboard-tabs" @tab-change="handleTabChange">
      <!-- 图表 Tab -->
      <el-tab-pane :label="t('dashboard.tabs.charts')" name="charts">
        <div class="metric-cards" v-loading="loading">
          <el-card v-for="m in metrics" :key="m.label" class="metric-card">
            <div class="metric-label">{{ m.label }}</div>
            <div class="metric-value" :style="{ color: m.color }">{{ m.value }}</div>
          </el-card>
        </div>

        <div class="charts-row">
          <el-card class="chart-card">
            <h3>{{ t('dashboard.monthlyIncomeTrend') }}</h3>
            <div v-show="hasTrendData" ref="incomeChartRef" class="chart"></div>
            <el-empty v-if="!hasTrendData" :description="t('dashboard.noData')" :image-size="72" />
          </el-card>
          <el-card class="chart-card">
            <h3>{{ t('dashboard.monthlyExpenses') }}</h3>
            <div v-show="hasTrendData" ref="expenseBarRef" class="chart"></div>
            <el-empty v-if="!hasTrendData" :description="t('dashboard.noData')" :image-size="72" />
          </el-card>
        </div>
        <div class="charts-row">
          <el-card class="chart-card">
            <h3>{{ t('dashboard.expenseByCategory') }}</h3>
            <div v-show="hasCategoryData" ref="expenseChartRef" class="chart"></div>
            <el-empty v-if="!hasCategoryData" :description="t('dashboard.noData')" :image-size="72" />
          </el-card>
          <el-card class="chart-card">
            <h3>{{ t('dashboard.incomeByProject') }}</h3>
            <div v-show="hasProjectData" ref="projectBarRef" class="chart"></div>
            <el-empty v-if="!hasProjectData" :description="t('dashboard.noData')" :image-size="72" />
          </el-card>
        </div>
      </el-tab-pane>

      <!-- 工时明细 Tab -->
      <el-tab-pane :label="t('dashboard.tabs.timeDetail')" name="timeDetail">
        <el-card v-loading="loading">
          <el-empty v-if="!timeLogs.length" :description="t('dashboard.noData')" />
          <el-table v-else :data="pagedTimeLogs" stripe>
            <el-table-column prop="projectName" :label="t('dashboard.timeDetail.project')" min-width="160" show-overflow-tooltip />
            <el-table-column :label="t('dashboard.timeDetail.startTime')" min-width="160">
              <template #default="{ row }">{{ formatDateTime(row.startTime) }}</template>
            </el-table-column>
            <el-table-column :label="t('dashboard.timeDetail.endTime')" min-width="160">
              <template #default="{ row }">{{ row.endTime ? formatDateTime(row.endTime) : '—' }}</template>
            </el-table-column>
            <el-table-column :label="t('dashboard.timeDetail.duration')" width="100" align="right">
              <template #default="{ row }">{{ formatDuration(row.duration) }}</template>
            </el-table-column>
            <el-table-column :label="t('dashboard.timeDetail.amount')" width="120" align="right">
              <template #default="{ row }">{{ money(row.billableAmount) }}</template>
            </el-table-column>
            <el-table-column :label="t('dashboard.timeDetail.tag')" width="120">
              <template #default="{ row }">
                <el-tag v-if="row.tag" size="small">{{ row.tag }}</el-tag>
                <span v-else>—</span>
              </template>
            </el-table-column>
            <el-table-column prop="note" :label="t('dashboard.timeDetail.note')" min-width="180" show-overflow-tooltip />
          </el-table>
          <div v-if="timeLogs.length > pageSize" class="pagination-wrap">
            <el-pagination
              v-model:current-page="timePage"
              :page-size="pageSize"
              :total="timeLogs.length"
              layout="prev, pager, next, total"
              background
            />
          </div>
        </el-card>
      </el-tab-pane>

      <!-- 开支明细 Tab -->
      <el-tab-pane :label="t('dashboard.tabs.expenseDetail')" name="expenseDetail">
        <el-card v-loading="loading">
          <el-empty v-if="!expenses.length" :description="t('dashboard.noData')" />
          <el-table v-else :data="pagedExpenses" stripe>
            <el-table-column :label="t('dashboard.expenseDetail.date')" width="140">
              <template #default="{ row }">{{ formatDate(row.expenseDate) }}</template>
            </el-table-column>
            <el-table-column prop="projectName" :label="t('dashboard.expenseDetail.project')" min-width="140" show-overflow-tooltip>
              <template #default="{ row }">{{ row.projectName || '—' }}</template>
            </el-table-column>
            <el-table-column prop="category" :label="t('dashboard.expenseDetail.category')" min-width="140" show-overflow-tooltip />
            <el-table-column prop="merchant" :label="t('dashboard.expenseDetail.merchant')" min-width="140" show-overflow-tooltip>
              <template #default="{ row }">{{ row.merchant || '—' }}</template>
            </el-table-column>
            <el-table-column :label="t('dashboard.expenseDetail.amount')" width="120" align="right">
              <template #default="{ row }">{{ money(row.amount) }}</template>
            </el-table-column>
            <el-table-column :label="t('dashboard.expenseDetail.taxDeductible')" width="110" align="center">
              <template #default="{ row }">
                <el-tag :type="row.isTaxDeductible ? 'success' : 'info'" size="small">
                  {{ row.isTaxDeductible ? t('dashboard.expenseDetail.yes') : t('dashboard.expenseDetail.no') }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="note" :label="t('dashboard.expenseDetail.note')" min-width="180" show-overflow-tooltip />
          </el-table>
          <div v-if="expenses.length > pageSize" class="pagination-wrap">
            <el-pagination
              v-model:current-page="expensePage"
              :page-size="pageSize"
              :total="expenses.length"
              layout="prev, pager, next, total"
              background
            />
          </div>
        </el-card>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch, nextTick } from 'vue'
import * as echarts from 'echarts'
import { useI18n } from 'vue-i18n'
import { reportApi } from '../api'
import { useAuthStore } from '../stores/auth'
import { money as fmtMoney } from '../utils/format'

const { t, locale } = useI18n()
const authStore = useAuthStore()
const userCurrency = () => authStore.user?.currency || 'USD'

const MONTHS_EN = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const MONTHS_ZH = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']

const year = ref(new Date().getFullYear())
const years = [year.value - 2, year.value - 1, year.value, year.value + 1].sort((a, b) => a - b)

const loading = ref(false)
const metrics = ref([])
const lastData = ref(null)
const activeTab = ref('charts')

// 明细数据（从年度报表接口附带返回，时区归类与图表完全一致）
const timeLogs = ref([])
const expenses = ref([])

// 分页（前端分页，后端一次返回全年明细）
const pageSize = 20
const timePage = ref(1)
const expensePage = ref(1)

const pagedTimeLogs = computed(() => {
  const start = (timePage.value - 1) * pageSize
  return timeLogs.value.slice(start, start + pageSize)
})
const pagedExpenses = computed(() => {
  const start = (expensePage.value - 1) * pageSize
  return expenses.value.slice(start, start + pageSize)
})

const incomeChartRef = ref(null)
const expenseBarRef = ref(null)
const expenseChartRef = ref(null)
const projectBarRef = ref(null)

// 用 Map 以 ref 对象为 key（普通对象的 key 会被 toString 成 "[object Object]"，
// 导致多个图表共用同一 cache 项，后初始化的覆盖前者，图表显示错乱）
const chartCache = new Map()
const getChart = (ref) => {
  if (!ref.value) return null
  if (!chartCache.has(ref)) chartCache.set(ref, echarts.init(ref.value))
  return chartCache.get(ref)
}

const money = (n) => fmtMoney(n, userCurrency())
const formatDuration = (h) => `${(Number(h) || 0).toFixed(2)}h`

// 图表空状态：任一数据源为空时显示占位而非 300px 空白框
const hasTrendData = computed(() => {
  const trend = lastData.value?.monthlyTrend || []
  return trend.some((m) => Number(m.income) > 0 || Number(m.expenses) > 0)
})
const hasCategoryData = computed(() => (lastData.value?.byCategory || []).length > 0)
const hasProjectData = computed(() => (lastData.value?.byProject || []).length > 0)

const localeStr = computed(() => (locale.value === 'zh' ? 'zh-CN' : 'en-US'))

const formatDateTime = (ts) => {
  if (!ts) return ''
  const d = new Date(ts)
  return d.toLocaleString(localeStr.value, {
    year: 'numeric', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}
const formatDate = (ts) => {
  if (!ts) return ''
  return new Date(ts).toLocaleDateString(localeStr.value, {
    year: 'numeric', month: 'short', day: 'numeric',
  })
}

// 年份切换竞态防护：快速切换时旧响应可能后到覆盖新数据，用序号丢弃过期响应
let loadSeq = 0
const loadData = async () => {
  const seq = ++loadSeq
  loading.value = true
  try {
    const res = await reportApi.getAnnual({ year: year.value })
    if (seq !== loadSeq) return // 已有更新的请求，丢弃本次结果
    const d = res.data
    lastData.value = d
    metrics.value = [
      { label: t('dashboard.annualIncome'), value: money(d.totalBillableAmount), color: '#10B981' },
      { label: t('dashboard.totalHours'), value: `${(Number(d.totalBillableHours) || 0).toFixed(1)}h`, color: '#2563EB' },
      { label: t('dashboard.totalExpenses'), value: money(d.totalExpenses), color: '#F59E0B' },
      { label: t('dashboard.taxDeductible'), value: money(d.taxDeductibleExpenses), color: '#10B981' },
      { label: t('dashboard.netIncome'), value: money(d.netIncome), color: '#2563EB' },
    ]
    timeLogs.value = d.timeLogDetails || []
    expenses.value = d.expenseDetails || []
    timePage.value = 1
    expensePage.value = 1
    // 切回 charts 时再渲染（明细 tab 下图表容器尺寸为 0，渲染无意义）
    await nextTick()
    if (activeTab.value === 'charts') renderCharts(d)
  } catch (e) {
    // 错误已由 request.js 统一提示
  } finally {
    loading.value = false
  }
}

// 切 tab：回到 charts 时，图表容器重新可见，需 resize 避免尺寸为 0
const handleTabChange = async (name) => {
  if (name === 'charts') {
    await nextTick()
    chartCache.forEach((c) => c?.resize())
    if (lastData.value) renderCharts(lastData.value)
  }
}

// 语言切换时刷新 metrics 标签和图表月份
watch(locale, () => {
  if (!lastData.value) return
  metrics.value = [
    { label: t('dashboard.annualIncome'), value: money(lastData.value.totalBillableAmount), color: '#10B981' },
    { label: t('dashboard.totalHours'), value: `${(Number(lastData.value.totalBillableHours) || 0).toFixed(1)}h`, color: '#2563EB' },
    { label: t('dashboard.totalExpenses'), value: money(lastData.value.totalExpenses), color: '#F59E0B' },
    { label: t('dashboard.taxDeductible'), value: money(lastData.value.taxDeductibleExpenses), color: '#10B981' },
    { label: t('dashboard.netIncome'), value: money(lastData.value.netIncome), color: '#2563EB' },
  ]
  if (activeTab.value === 'charts') renderCharts(lastData.value)
})

const renderCharts = (d) => {
  const monthly = d.monthlyTrend || []
  const months = locale.value === 'zh' ? MONTHS_ZH : MONTHS_EN
  const labels = monthly.map((m) => months[(m.month - 1) % 12])

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

const handleResize = () => {
  chartCache.forEach((c) => c?.resize())
}

onMounted(() => {
  loadData()
  window.addEventListener('resize', handleResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  // 释放 ECharts 实例，避免内存泄漏
  chartCache.forEach((c) => c?.dispose())
  chartCache.clear()
})
</script>

<style scoped>
.toolbar {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 16px;
}
.dashboard-tabs {
  margin-top: 8px;
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
.pagination-wrap {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}

@media (max-width: 768px) {
  .metric-cards {
    grid-template-columns: repeat(2, 1fr);
  }
  .charts-row {
    grid-template-columns: 1fr;
  }
}
</style>
