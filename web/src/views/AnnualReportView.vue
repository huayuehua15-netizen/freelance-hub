<template>
  <div class="annual-report">
    <el-card class="summary-card" v-loading="loading">
      <div class="report-header">
        <h2>{{ t('report.annualTitle', { year: selectedYear }) }}</h2>
        <el-select v-model="selectedYear" style="width: 120px" @change="loadReport">
          <el-option v-for="y in years" :key="y" :label="y" :value="y" />
        </el-select>
      </div>
      <div class="summary-grid">
        <div class="summary-item">
          <div class="label">{{ t('report.totalIncome') }}</div>
          <div class="value success">${{ fmt(report.totalBillableAmount) }}</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.totalHours') }}</div>
          <div class="value">{{ fmtHours(report.totalBillableHours) }}h</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.totalExpenses') }}</div>
          <div class="value warning">${{ fmt(report.totalExpenses) }}</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.taxDeductible') }}</div>
          <div class="value success">${{ fmt(report.taxDeductibleExpenses) }}</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.netIncome') }}</div>
          <div class="value primary">${{ fmt(report.netIncome) }}</div>
        </div>
        <div class="summary-item">
          <div class="label">{{ t('report.estSeTax') }}</div>
          <div class="value danger">${{ fmt(report.estimatedSelfEmploymentTax) }}</div>
        </div>
      </div>
    </el-card>

    <el-card class="quarter-card" v-loading="loading" style="margin-top: 24px">
      <h3>{{ t('report.quarterlyBreakdown') }}</h3>
      <el-table :data="report.quarters || []" stripe>
        <el-table-column prop="quarter" :label="t('report.quarter')" />
        <el-table-column :label="t('report.hours')">
          <template #default="{ row }">{{ fmtHours(row.totalBillableHours) }}h</template>
        </el-table-column>
        <el-table-column :label="t('report.income')">
          <template #default="{ row }">${{ fmt(row.totalBillableAmount) }}</template>
        </el-table-column>
        <el-table-column :label="t('report.expenses')">
          <template #default="{ row }">${{ fmt(row.totalExpenses) }}</template>
        </el-table-column>
        <el-table-column :label="t('report.deductible')">
          <template #default="{ row }">${{ fmt(row.taxDeductibleExpenses) }}</template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-card class="disclaimer" style="margin-top: 24px">
      <p><strong>{{ t('report.disclaimerStrong') }}</strong> {{ t('report.disclaimerBody') }}</p>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { useI18n } from 'vue-i18n'
import { reportApi } from '../api'

const { t } = useI18n()

const selectedYear = ref(new Date().getFullYear())
const years = [selectedYear.value - 1, selectedYear.value, selectedYear.value + 1].sort((a, b) => a - b)
const loading = ref(false)
const report = ref({})

const fmt = (n) => (Number(n) || 0).toFixed(2)
const fmtHours = (n) => (Number(n) || 0).toFixed(1)

const loadReport = async () => {
  loading.value = true
  try {
    const res = await reportApi.getAnnual({ year: selectedYear.value })
    report.value = res.data
  } catch (e) {
    ElMessage.error(e.response?.data?.msg || t('report.loadFailed'))
  } finally {
    loading.value = false
  }
}

onMounted(loadReport)
</script>

<style scoped>
.report-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}
.report-header h2 {
  margin: 0;
  color: #1e293b;
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
.quarter-card h3 {
  margin: 0 0 16px;
  color: #1e293b;
}
.success { color: #10B981; }
.warning { color: #F59E0B; }
.primary { color: #2563EB; }
.danger { color: #EF4444; }
.disclaimer {
  background: #fef2f2;
  border: 1px solid #fecaca;
}
.disclaimer p {
  margin: 0;
  color: #991b1b;
  font-size: 14px;
}
</style>
