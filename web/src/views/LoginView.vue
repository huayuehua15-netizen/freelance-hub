<template>
  <div class="login-container">
    <div class="login-card">
      <div class="locale-switch">
        <el-dropdown @command="handleLocaleCommand" trigger="click">
          <span class="locale-trigger">
            {{ localeLabel }}
            <el-icon><svg viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="m7 10 5 5 5-5z"/></svg></el-icon>
          </span>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="en" :disabled="locale === 'en'">English</el-dropdown-item>
              <el-dropdown-item command="zh" :disabled="locale === 'zh'">中文</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </div>
      <h1>{{ t('login.title') }}</h1>
      <p class="subtitle">{{ t('login.subtitle') }}</p>
      <el-form :model="form" @submit.prevent="handleLogin">
        <el-form-item :label="t('login.emailLabel')">
          <el-input v-model="form.email" type="email" :placeholder="t('login.emailPlaceholder')" />
        </el-form-item>
        <el-form-item :label="t('login.passwordLabel')">
          <el-input v-model="form.password" type="password" :placeholder="t('login.passwordPlaceholder')" show-password />
        </el-form-item>
        <el-button type="primary" :loading="loading" class="login-btn" @click="handleLogin">
          {{ t('login.submit') }}
        </el-button>
      </el-form>
      <p class="hint">{{ t('login.hint') }}</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useI18n } from 'vue-i18n'
import { authApi } from '../api'
import { useAuthStore } from '../stores/auth'
import { useLocaleStore } from '../stores/locale'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const { t } = useI18n()
const localeStore = useLocaleStore()

const locale = computed(() => localeStore.locale)
const localeLabel = computed(() => (locale.value === 'zh' ? '中文' : 'English'))

const handleLocaleCommand = (cmd) => {
  if (cmd === 'en' || cmd === 'zh') {
    localeStore.setLocale(cmd)
  }
}

const loading = ref(false)
const form = ref({ email: '', password: '' })

const handleLogin = async () => {
  if (!form.value.email || !form.value.password) {
    ElMessage.warning(t('login.enterEmailAndPassword'))
    return
  }
  loading.value = true
  try {
    const res = await authApi.login(form.value)
    // 修复 M7:此前登录返回过期 annual 也"假成功",守卫 getMe 会触发降级踢回登录页
    // 现在在 LoginView 校验 expireTime:已过期则直接拦截,提示用户续费
    if (res.data.premiumType !== 'annual') {
      authStore.logout()
      ElMessage.warning(t('login.annualOnly'))
      return
    }
    if (res.data.expireTime && res.data.expireTime < Date.now()) {
      authStore.logout()
      ElMessage.warning(t('login.annualExpired'))
      return
    }
    authStore.setTokens(res.data.accessToken, res.data.refreshToken)
    authStore.setUser(res.data)
    ElMessage.success(t('login.success'))
    const redirect = route.query.redirect || '/dashboard'
    router.push(redirect)
  } catch (e) {
    ElMessage.error(e.response?.data?.msg || t('login.failed'))
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f8fafc;
  position: relative;
}
.locale-switch {
  position: absolute;
  top: 16px;
  right: 16px;
}
.locale-trigger {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  color: #64748b;
  padding: 6px 10px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
  background: #fff;
  font-size: 13px;
}
.locale-trigger:hover {
  background: #f1f5f9;
}
.login-card {
  width: 400px;
  padding: 40px;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  position: relative;
}
.login-card h1 {
  text-align: center;
  color: #1e293b;
  margin-bottom: 8px;
}
.subtitle {
  text-align: center;
  color: #64748b;
  margin-bottom: 32px;
  font-size: 14px;
}
.login-btn {
  width: 100%;
}
.hint {
  text-align: center;
  color: #94a3b8;
  font-size: 12px;
  margin-top: 16px;
}
</style>
