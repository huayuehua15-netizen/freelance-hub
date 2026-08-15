<template>
  <div class="export-page">
    <el-card>
      <h2>{{ t('export.title') }}</h2>
      <el-form label-width="140px" style="max-width: 500px; margin-top: 24px">
        <el-form-item :label="t('export.reportType')">
          <el-radio-group v-model="form.type">
            <el-radio value="annual">{{ t('export.annual') }}</el-radio>
            <el-radio value="monthly">{{ t('export.monthly') }}</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item :label="t('export.year')">
          <el-select v-model="form.year" style="width: 160px">
            <el-option v-for="y in years" :key="y" :label="y" :value="y" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="form.type === 'monthly'" :label="t('export.month')">
          <el-select v-model="form.month" style="width: 160px">
            <el-option v-for="m in months" :key="m.value" :label="m.label" :value="m.value" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="exporting" @click="handleExport">
            {{ t('export.exportPdf') }}
          </el-button>
          <el-button type="success" :loading="exporting" plain @click="handleExportCsv">
            {{ t('export.exportCsv') }}
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'
import { useI18n } from 'vue-i18n'
import { reportApi } from '../api'

const { t, locale } = useI18n()

const currentYear = new Date().getFullYear()
const years = [currentYear - 1, currentYear, currentYear + 1].sort((a, b) => a - b)
const months = computed(() => {
  const keys = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
  return keys.map((v) => ({ value: v, label: t(`export.months.${v}`) }))
})

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
    ElMessage.success(t('export.pdfExported'))
  } catch (e) {
    ElMessage.error(t('export.pdfExportFailed'))
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
    ElMessage.success(t('export.csvExported'))
  } catch (e) {
    ElMessage.error(t('export.csvExportFailed'))
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
