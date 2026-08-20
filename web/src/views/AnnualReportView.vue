<template>
  <div class="annual-report">
    <!-- 顶部操作栏：年份选择 + 导出按钮 -->
    <el-card class="summary-card" v-loading="loading">
      <div class="report-header">
        <h2>{{ t('report.annualTitle', { year: selectedYear }) }}</h2>
        <div class="header-actions">
          <el-select v-model="selectedYear" style="width: 120px" @change="loadReport">
            <el-option v-for="y in years" :key="y" :label="y" :value="y" />
          </el-select>
          <el-button type="primary" :loading="exporting" @click="handleExportPdf">
            <el-icon style="margin-right: 4px"><Download /></el-icon>
            {{ t('report.exportPdf') }}
          </el-button>
        </div>
      </div>

      <!-- 汇总指标卡片 -->
      <div class="summary-grid">
        <div class="summary-item">
          <div class="label">{{ t('report.totalIncome') }}</div>
          <div class="value success">{{ moneyFmt(report.totalBillableAmount) }}</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.totalHours') }}</div>
          <div class="value">{{ fmtHours(report.totalBillableHours) }}h</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.totalExpenses') }}</div>
          <div class="value warning">{{ moneyFmt(report.totalExpenses) }}</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.taxDeductible') }}</div>
          <div class="value success">{{ moneyFmt(report.taxDeductibleExpenses) }}</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.netIncome') }}</div>
          <div class="value primary">{{ moneyFmt(report.netIncome) }}</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.estSeTax') }}</div>
          <div class="value danger">{{ moneyFmt(report.estimatedSelfEmploymentTax) }}</div>
        </div>
      </div>

      <!-- 季度预缴税估算（1040-ES）：后端计算，无数据时隐藏 -->
      <div v-if="report.quarterlyTaxEstimate" class="quarterly-estimate">
        <div class="qe-main">
          <span class="qe-label">{{ t('report.perQuarter') }}:</span>
          <span class="qe-value">{{ moneyFmt(report.quarterlyTaxEstimate.perQuarterSuggestion) }}</span>
        </div>
        <div class="qe-breakdown">
          {{ t('report.seTax') }}: {{ moneyFmt(report.quarterlyTaxEstimate.selfEmploymentTax) }}
          · {{ t('report.fedTax') }}: {{ moneyFmt(report.quarterlyTaxEstimate.federalIncomeTax) }}
          · {{ t('report.annualTotal') }}: {{ moneyFmt(report.quarterlyTaxEstimate.totalAnnualEstimate) }}
        </div>
        <div class="qe-hint">{{ t('report.quarterlyHint') }}</div>
      </div>
    </el-card>

    <!-- 图表区：月度趋势 + 类目汇总 -->
    <div class="charts-row" v-loading="loading">
      <el-card class="chart-card">
        <h3>{{ t('report.monthlyTrend') }}</h3>
        <div v-show="hasTrendData" ref="trendChartRef" class="chart"></div>
        <el-empty v-if="!hasTrendData" :description="t('dashboard.noData')" :image-size="72" />
      </el-card>
      <el-card class="chart-card">
        <h3>{{ t('report.expenseByCategory') }}</h3>
        <div v-show="hasCategoryData" ref="categoryChartRef" class="chart"></div>
        <el-empty v-if="!hasCategoryData" :description="t('dashboard.noData')" :image-size="72" />
      </el-card>
    </div>

    <!-- 季度明细表 -->
    <el-card class="quarter-card" v-loading="loading">
      <h3>{{ t('report.quarterlyBreakdown') }}</h3>
      <el-table :data="report.quarters || []" stripe>
        <el-table-column prop="quarter" :label="t('report.quarter')" width="100" />
        <el-table-column :label="t('report.hours')">
          <template #default="{ row }">{{ fmtHours(row.totalBillableHours) }}h</template>
        </el-table-column>
        <el-table-column :label="t('report.income')">
          <template #default="{ row }">{{ moneyFmt(row.totalBillableAmount) }}</template>
        </el-table-column>
        <el-table-column :label="t('report.expenses')">
          <template #default="{ row }">{{ moneyFmt(row.totalExpenses) }}</template>
        </el-table-column>
        <el-table-column :label="t('report.deductible')">
          <template #default="{ row }">{{ moneyFmt(row.taxDeductibleExpenses) }}</template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 免责声明 -->
    <el-card class="disclaimer">
      <p><strong>{{ t('report.disclaimerStrong') }}</strong> {{ t('report.disclaimerBody') }}</p>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch, nextTick } from 'vue'
import * as echarts from 'echarts'
import { ElMessage } from 'element-plus'
import { Download } from '@element-plus/icons-vue'
import { useI18n } from 'vue-i18n'
import { reportApi } from '../api'
import { useAuthStore } from '../stores/auth'
import { money } from '../utils/format'

const { t, locale } = useI18n()
const authStore = useAuthStore()
const userCurrency = () => authStore.user?.currency || 'USD'

const MONTHS_EN = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const MONTHS_ZH = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']

const selectedYear = ref(new Date().getFullYear())
const years = [selectedYear.value - 2, selectedYear.value - 1, selectedYear.value, selectedYear.value + 1].sort((a, b) => a - b)
const loading = ref(false)
const exporting = ref(false)
const report = ref({})

const trendChartRef = ref(null)
const categoryChartRef = ref(null)
let trendChart = null
let categoryChart = null

const fmt = (n) => (Number(n) || 0).toFixed(2)
const fmtHours = (n) => (Number(n) || 0).toFixed(1)
// 模板与图表 tooltip 统一走货币感知格式化（默认 USD，按登录用户 currency 渲染）
const moneyFmt = (n) => money(n, userCurrency())

// 季度预缴税估算（后端返回，无该字段时隐藏整个块）
const hasQuarterlyEstimate = computed(() => !!report.value?.quarterlyTaxEstimate)

// 图表空状态：任一数据源为空时显示占位而非 300px 空白框
const hasTrendData = computed(() => {
  const trend = report.value?.monthlyTrend || []
  return trend.some((m) => Number(m.income) > 0 || Number(m.expenses) > 0)
})
const hasCategoryData = computed(() => (report.value?.byCategory || []).length > 0)

// 年份切换竞态防护：快速切换时旧响应可能后到覆盖新数据，用序号丢弃过期响应
let loadSeq = 0
const loadReport = async () => {
  const seq = ++loadSeq
  loading.value = true
  try {
    const res = await reportApi.getAnnual({ year: selectedYear.value })
    if (seq !== loadSeq) return // 已有更新的请求，丢弃本次结果
    report.value = res.data
    await nextTick()
    renderCharts()
  } catch (e) {
    // 错误已由 request.js 统一提示
  } finally {
    loading.value = false
  }
}

const renderCharts = () => {
  const d = report.value
  if (!d) return

  const monthly = d.monthlyTrend || []
  const months = locale.value === 'zh' ? MONTHS_ZH : MONTHS_EN
  const labels = monthly.map((m) => months[(m.month - 1) % 12])

  // 月度趋势：收入 vs 开支双 series 对比
  if (trendChartRef.value) {
    if (!trendChart) trendChart = echarts.init(trendChartRef.value)
    trendChart.setOption({
      tooltip: {
        trigger: 'axis',
        formatter: (params) => {
          let html = `${params[0].axisValue}<br/>`
          params.forEach((p) => {
            html += `${p.marker} ${p.seriesName}: ${moneyFmt(Number(p.value || 0))}<br/>`
          })
          return html
        },
      },
      legend: {
        data: [t('report.income'), t('report.expenses')],
        top: 0,
        right: 0,
      },
      grid: { left: 48, right: 16, top: 32, bottom: 28 },
      xAxis: { type: 'category', data: labels },
      yAxis: { type: 'value' },
      series: [
        {
          name: t('report.income'),
          type: 'line',
          data: monthly.map((m) => m.income),
          smooth: true,
          itemStyle: { color: '#10B981' },
          areaStyle: { color: 'rgba(16, 185, 129, 0.08)' },
        },
        {
          name: t('report.expenses'),
          type: 'line',
          data: monthly.map((m) => m.expenses),
          smooth: true,
          itemStyle: { color: '#F59E0B' },
          areaStyle: { color: 'rgba(245, 158, 11, 0.08)' },
        },
      ],
    })
  }

  // 类目汇总：开支分类饼图（环图）
  const byCategory = d.byCategory || []
  if (categoryChartRef.value) {
    if (!categoryChart) categoryChart = echarts.init(categoryChartRef.value)
    categoryChart.setOption({
      tooltip: {
        trigger: 'item',
        formatter: (p) => `${p.name}: ${moneyFmt(Number(p.value || 0))} (${p.percent}%)`,
      },
      legend: {
        orient: 'vertical',
        right: 0,
        top: 'middle',
        textStyle: { fontSize: 12 },
      },
      series: [{
        type: 'pie',
        radius: ['42%', '68%'],
        center: ['38%', '50%'],
        data: byCategory.map((c) => ({ value: c.amount, name: c.category })),
        label: { show: false },
        emphasis: {
          label: { show: true, fontWeight: 'bold' },
        },
        color: ['#2563EB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#06B6D4', '#F97316', '#EC4899', '#84CC16', '#14B8A6'],
      }],
    })
  }
}

// 导出年度报税 PDF
const handleExportPdf = async () => {
  exporting.value = true
  try {
    const res = await reportApi.exportPdf({ year: selectedYear.value, type: 'annual' })
    const blob = new Blob([res], { type: 'application/pdf' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `freelance-hub-annual-${selectedYear.value}.pdf`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    // 延迟释放：同 tick 释放会在 Safari/部分浏览器中断大文件下载
    setTimeout(() => URL.revokeObjectURL(url), 4000)
    ElMessage.success(t('report.exported'))
  } catch (e) {
    // 错误已由 request.js 统一提示
  } finally {
    exporting.value = false
  }
}

// 语言切换时重新渲染图表（图例文字 + 月份标签）
watch(locale, () => {
  renderCharts()
})

// 窗口 resize 时重绘图表
const handleResize = () => {
  trendChart?.resize()
  categoryChart?.resize()
}

onMounted(() => {
  loadReport()
  window.addEventListener('resize', handleResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  trendChart?.dispose()
  categoryChart?.dispose()
})
</script>

<style scoped>
.report-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  flex-wrap: wrap;
  gap: 12px;
}
.report-header h2 {
  margin: 0;
  color: #1e293b;
  font-size: 22px;
}
.header-actions {
  display: flex;
  gap: 12px;
  align-items: center;
}
.summary-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
}
.summary-item .label {
  color: #64748b;
  font-size: 14px;
  margin-bottom: 8px;
}
.summary-item .value {
  font-size: 28px;
  font-weight: bold;
}
.charts-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-top: 24px;
}
.chart-card h3 {
  margin: 0 0 16px;
  color: #1e293b;
  font-size: 15px;
}
.chart {
  height: 320px;
}
.quarter-card {
  margin-top: 24px;
}
.quarter-card h3 {
  margin: 0 0 16px;
  color: #1e293b;
  font-size: 15px;
}
.disclaimer {
  margin-top: 24px;
  background: #fef2f2;
  border: 1px solid #fecaca;
}
.disclaimer p {
  margin: 0;
  color: #991b1b;
  font-size: 14px;
  line-height: 1.6;
}

.success { color: #10B981; }
.warning { color: #F59E0B; }
.primary { color: #2563EB; }
.danger { color: #EF4444; }

@media (max-width: 768px) {
  .summary-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 16px;
  }
  .charts-row {
    grid-template-columns: 1fr;
  }
  .summary-item .value {
    font-size: 22px;
  }
}

.quarterly-estimate {
  margin-top: 16px;
  padding: 14px 16px;
  border: 1px solid rgba(37, 99, 235, 0.25);
  background: rgba(37, 99, 235, 0.05);
  border-radius: 8px;
}
.qe-main {
  display: flex;
  align-items: baseline;
  gap: 8px;
}
.qe-label {
  font-size: 13px;
  color: #475569;
}
.qe-value {
  font-size: 20px;
  font-weight: 700;
  color: #2563eb;
}
.qe-breakdown {
  margin-top: 6px;
  font-size: 13px;
  color: #64748b;
}
.qe-hint {
  margin-top: 6px;
  font-size: 11px;
  color: #94a3b8;
  line-height: 1.5;
}
</style>
