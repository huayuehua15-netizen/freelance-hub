<template>
  <div class="export-page">
    <el-card>
      <h2>Export Report</h2>
      <el-form label-width="140px" style="max-width: 500px; margin-top: 24px">
        <el-form-item label="Report Type">
          <el-radio-group v-model="form.type">
            <el-radio value="annual">Annual Tax Summary</el-radio>
            <el-radio value="monthly">Monthly Report</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="Year">
          <el-select v-model="form.year" style="width: 160px">
            <el-option v-for="y in years" :key="y" :label="y" :value="y" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="form.type === 'monthly'" label="Month">
          <el-select v-model="form.month" style="width: 160px">
            <el-option v-for="m in months" :key="m.value" :label="m.label" :value="m.value" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="exporting" @click="handleExport">
            Export PDF
          </el-button>
          <el-button type="success" :loading="exporting" plain @click="handleExportCsv">
            Export CSV
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { reportApi } from '../api'

const currentYear = new Date().getFullYear()
const years = [currentYear - 1, currentYear, currentYear + 1].sort((a, b) => a - b)
const months = [
  { value: 1, label: 'January' }, { value: 2, label: 'February' }, { value: 3, label: 'March' },
  { value: 4, label: 'April' }, { value: 5, label: 'May' }, { value: 6, label: 'June' },
  { value: 7, label: 'July' }, { value: 8, label: 'August' }, { value: 9, label: 'September' },
  { value: 10, label: 'October' }, { value: 11, label: 'November' }, { value: 12, label: 'December' },
]

const exporting = ref(false)
const form = ref({
  type: 'annual',
  year: currentYear,
  month: new Date().getMonth() + 1,
})

const handleExport = async () => {
  exporting.value = true
  try {
    const params = { type: form.value.type, year: form.value.year }
    if (form.value.type === 'monthly') params.month = form.value.month

    const blob = await reportApi.exportPdf(params)
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `${form.value.type}_report_${form.value.year}.pdf`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
    ElMessage.success('Report exported')
  } catch (e) {
    ElMessage.error('Export failed')
  } finally {
    exporting.value = false
  }
}

const handleExportCsv = async () => {
  exporting.value = true
  try {
    const blob = await reportApi.exportCsv({ year: form.value.year })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `freelance_hub_${form.value.year}_export.csv`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
    ElMessage.success('CSV exported')
  } catch (e) {
    ElMessage.error('CSV export failed')
  } finally {
    exporting.value = false
  }
}
</script>

<style scoped>
h2 {
  margin: 0 0 8px;
  color: #1e293b;
}
</style>
