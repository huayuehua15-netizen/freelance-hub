<template>
  <div class="export-page">
    <!-- 导出表单 -->
    <el-card>
      <h2>{{ t('export.title') }}</h2>
      <el-form label-width="140px" style="max-width: 540px; margin-top: 24px">
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
          <el-button type="primary" :loading="exporting === 'pdf'" @click="handleExport('pdf')">
            <el-icon style="margin-right: 4px"><Download /></el-icon>
            {{ t('export.exportPdf') }}
          </el-button>
          <el-tooltip
            :content="t('export.csvAnnualOnly')"
            :disabled="form.type === 'annual'"
            placement="top"
          >
            <el-button
              type="success"
              plain
              :loading="exporting === 'csv'"
              :disabled="form.type === 'monthly'"
              @click="handleExport('csv')"
            >
              {{ t('export.exportCsv') }}
            </el-button>
          </el-tooltip>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 导出历史 -->
    <el-card style="margin-top: 24px">
      <div class="history-header">
        <h3>{{ t('export.historyTitle') }}</h3>
        <el-button
          v-if="history.length"
          type="danger"
          text
          size="small"
          @click="clearHistory"
        >
          {{ t('export.clearHistory') }}
        </el-button>
      </div>

      <el-empty v-if="!history.length" :description="t('export.noHistory')" />
      <el-table v-else :data="history" stripe>
        <el-table-column :label="t('export.colFormat')" width="80">
          <template #default="{ row }">
            <el-tag :type="row.format === 'pdf' ? 'primary' : 'success'" size="small">
              {{ row.format.toUpperCase() }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column :label="t('export.colRange')" min-width="180">
          <template #default="{ row }">
            {{ row.type === 'annual' ? `${t('export.annual')} ${row.year}` : `${t('export.months.' + row.month)} ${row.year}` }}
          </template>
        </el-table-column>
        <el-table-column prop="fileName" :label="t('export.colFile')" min-width="200" show-overflow-tooltip />
        <el-table-column :label="t('export.colExportedAt')" width="180">
          <template #default="{ row }">{{ formatTime(row.exportedAt) }}</template>
        </el-table-column>
        <el-table-column :label="t('export.colActions')" width="100" align="center">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="reExport(row)">
              {{ t('export.reExport') }}
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Download } from '@element-plus/icons-vue'
import { useI18n } from 'vue-i18n'
import { reportApi } from '../api'

const { t, locale } = useI18n()

const HISTORY_KEY = 'export_history'
const MAX_HISTORY = 20

const currentYear = new Date().getFullYear()
const years = [currentYear - 2, currentYear - 1, currentYear, currentYear + 1].sort((a, b) => a - b)
const months = computed(() => {
  const keys = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
  return keys.map((v) => ({ value: v, label: t(`export.months.${v}`) }))
})

const exporting = ref(null) // 'pdf' | 'csv' | null
const form = ref({
  type: 'annual',
  year: currentYear,
  month: new Date().getMonth() + 1,
})

// 导出历史（localStorage 持久化）
const history = ref(loadHistory())

function loadHistory() {
  try {
    const raw = localStorage.getItem(HISTORY_KEY)
    return raw ? JSON.parse(raw) : []
  } catch {
    return []
  }
}

function saveHistory(records) {
  history.value = records
  localStorage.setItem(HISTORY_KEY, JSON.stringify(records))
}

function addHistory(record) {
  const records = [record, ...history.value].slice(0, MAX_HISTORY)
  saveHistory(records)
}

function clearHistory() {
  ElMessageBox.confirm(t('export.confirmClear'), t('common.confirm'), {
    type: 'warning',
    confirmButtonText: t('common.delete'),
    cancelButtonText: t('common.cancel'),
  })
    .then(() => {
      saveHistory([])
      ElMessage.success(t('export.historyCleared'))
    })
    .catch(() => {})
}

function formatTime(ts) {
  const d = new Date(ts)
  const dateStr = d.toLocaleDateString(locale.value === 'zh' ? 'zh-CN' : 'en-US')
  const timeStr = d.toLocaleTimeString(locale.value === 'zh' ? 'zh-CN' : 'en-US', {
    hour: '2-digit',
    minute: '2-digit',
  })
  return `${dateStr} ${timeStr}`
}

// 统一导出处理：format = 'pdf' | 'csv'
const handleExport = async (format) => {
  exporting.value = format
  try {
    const params = { type: form.value.type, year: form.value.year }
    if (form.value.type === 'monthly') params.month = form.value.month

    let blob
    let fileName
    if (format === 'pdf') {
      blob = await reportApi.exportPdf(params)
      fileName = `freelance-hub-${form.value.type}-${form.value.year}${form.value.type === 'monthly' ? `-${String(form.value.month).padStart(2, '0')}` : ''}.pdf`
    } else {
      // CSV 只支持年度导出（后端限制）
      blob = await reportApi.exportCsv({ year: form.value.year })
      fileName = `freelance-hub-${form.value.year}-export.csv`
    }

    downloadBlob(blob, fileName)

    // 记录到历史
    addHistory({
      id: Date.now(),
      format,
      type: form.value.type,
      year: form.value.year,
      month: form.value.month,
      fileName,
      exportedAt: Date.now(),
      // 保存导出参数用于重新导出
      params: { ...params },
    })

    ElMessage.success(format === 'pdf' ? t('export.pdfExported') : t('export.csvExported'))
  } catch (e) {
    // 错误已由 request.js 统一提示
  } finally {
    exporting.value = null
  }
}

// 重新导出历史记录
const reExport = async (record) => {
  exporting.value = record.format
  try {
    let blob
    if (record.format === 'pdf') {
      blob = await reportApi.exportPdf(record.params)
    } else {
      blob = await reportApi.exportCsv(record.params)
    }
    downloadBlob(blob, record.fileName)
    ElMessage.success(t('export.reExported'))
  } catch (e) {
    // 错误已由 request.js 统一提示
  } finally {
    exporting.value = null
  }
}

function downloadBlob(blob, fileName) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = fileName
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  // 延迟释放：同 tick 释放会在 Safari/部分浏览器中断大文件下载
  setTimeout(() => URL.revokeObjectURL(url), 4000)
}
</script>

<style scoped>
h2 {
  margin: 0 0 8px;
  color: #1e293b;
}
h3 {
  margin: 0;
  color: #1e293b;
  font-size: 16px;
}
.history-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
</style>
