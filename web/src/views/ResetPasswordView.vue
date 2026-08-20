<template>
  <div class="auth-container">
    <div class="auth-card">
      <h1>{{ t('reset.title') }}</h1>

      <template v-if="!done">
        <p class="subtitle">{{ t('reset.subtitle') }}</p>
        <el-form @submit.prevent="handleReset">
          <el-form-item :label="t('reset.newPasswordLabel')">
            <el-input
              v-model="password"
              type="password"
              show-password
              :placeholder="t('reset.passwordRule')"
            />
          </el-form-item>
          <el-form-item :label="t('reset.confirmPasswordLabel')">
            <el-input
              v-model="confirmPassword"
              type="password"
              show-password
              :placeholder="t('reset.confirmPasswordLabel')"
            />
          </el-form-item>
          <el-button type="primary" :loading="loading" class="action-btn" @click="handleReset">
            {{ t('reset.submit') }}
          </el-button>
        </el-form>
      </template>

      <el-result v-else icon="success" :title="t('reset.doneTitle')" :sub-title="t('reset.doneBody')" />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useI18n } from 'vue-i18n'
import { authApi } from '../api'

const { t } = useI18n()
const route = useRoute()
const password = ref('')
const confirmPassword = ref('')
const loading = ref(false)
const done = ref(false)
const token = ref('')

onMounted(() => {
  token.value = String(route.query.token || '')
  if (!token.value) {
    ElMessage.error(t('reset.tokenMissing'))
  }
})

const handleReset = async () => {
  if (!token.value) {
    ElMessage.error(t('reset.tokenMissing'))
    return
  }
  if (!password.value || password.value.length < 8) {
    ElMessage.warning(t('reset.passwordRule'))
    return
  }
  if (password.value !== confirmPassword.value) {
    ElMessage.warning(t('reset.passwordMismatch'))
    return
  }
  loading.value = true
  try {
    await authApi.resetPassword({ token: token.value, newPassword: password.value })
    done.value = true
  } catch (e) {
    ElMessage.error(e.response?.data?.msg || t('reset.failed'))
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.auth-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f8fafc;
}
.auth-card {
  width: 400px;
  padding: 40px;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}
.auth-card h1 {
  text-align: center;
  color: #1e293b;
  margin-bottom: 8px;
  font-size: 22px;
}
.subtitle {
  text-align: center;
  color: #64748b;
  margin-bottom: 32px;
  font-size: 14px;
}
.action-btn {
  width: 100%;
}
</style>
