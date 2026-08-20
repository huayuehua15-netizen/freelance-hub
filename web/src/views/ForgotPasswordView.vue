<template>
  <div class="auth-container">
    <div class="auth-card">
      <h1>{{ t('forgot.title') }}</h1>
      <p class="subtitle">{{ t('forgot.subtitle') }}</p>

      <template v-if="!sent">
        <el-form @submit.prevent="handleSend">
          <el-form-item :label="t('login.emailLabel')">
            <el-input v-model="email" type="email" :placeholder="t('login.emailPlaceholder')" />
          </el-form-item>
          <el-button type="primary" :loading="loading" class="action-btn" @click="handleSend">
            {{ t('forgot.send') }}
          </el-button>
        </el-form>
      </template>

      <el-result v-else icon="success" :title="t('forgot.sentTitle')" :sub-title="t('forgot.sentBody')" />

      <p class="back-link">
        <router-link to="/login">{{ t('forgot.backToLogin') }}</router-link>
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { useI18n } from 'vue-i18n'
import { authApi } from '../api'

const { t } = useI18n()
const email = ref('')
const loading = ref(false)
const sent = ref(false)

const handleSend = async () => {
  if (!email.value) {
    ElMessage.warning(t('login.enterEmailAndPassword'))
    return
  }
  loading.value = true
  try {
    await authApi.forgotPassword({ email: email.value })
    sent.value = true
  } catch (e) {
    ElMessage.error(e.response?.data?.msg || t('forgot.failed'))
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
.back-link {
  text-align: center;
  margin-top: 16px;
  font-size: 13px;
}
.back-link a {
  color: #2563eb;
  text-decoration: none;
}
.back-link a:hover {
  text-decoration: underline;
}
</style>
