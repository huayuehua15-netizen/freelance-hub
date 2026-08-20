<template>
  <div class="auth-container">
    <div class="auth-card">
      <h1>{{ t('verify.title') }}</h1>

      <el-result
        v-if="state !== 'loading'"
        :icon="state === 'ok' ? 'success' : 'error'"
        :title="state === 'ok' ? t('verify.okTitle') : t('verify.failedTitle')"
        :sub-title="state === 'ok' ? t('verify.okBody') : t('verify.failedBody')"
      />

      <el-result v-else icon="info" :title="t('verify.loadingTitle')" />

      <p class="back-link">
        <router-link to="/login">{{ t('forgot.backToLogin') }}</router-link>
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { authApi } from '../api'

const { t } = useI18n()
const route = useRoute()
const state = ref('loading') // loading | ok | failed

onMounted(async () => {
  const token = String(route.query.token || '')
  if (!token) {
    state.value = 'failed'
    return
  }
  try {
    await authApi.verifyEmail({ token })
    state.value = 'ok'
  } catch (_) {
    state.value = 'failed'
  }
})
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
