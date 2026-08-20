<template>
  <el-container class="main-layout">
    <el-aside width="220px" class="sidebar">
      <div class="logo">Freelance Hub</div>
      <el-menu :default-active="activeMenu" router class="menu">
        <el-menu-item index="/dashboard">
          <span>{{ t('nav.dashboard') }}</span>
        </el-menu-item>
        <el-menu-item index="/annual-report">
          <span>{{ t('nav.annualReport') }}</span>
        </el-menu-item>
        <el-menu-item index="/export">
          <span>{{ t('nav.export') }}</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="header">
        <div class="header-title">{{ pageTitle }}</div>
        <div class="header-actions">
          <el-dropdown @command="handleLocaleCommand" trigger="click">
            <span class="locale-trigger">
              <el-icon><svg viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 2c1.1 0 2.45 1.27 3.16 3.6A18.7 18.7 0 0 1 12 8a18.7 18.7 0 0 1-3.16-.4C9.55 5.27 10.9 4 12 4ZM5.04 7.3a18.9 18.9 0 0 1 4.3-1.06A11.4 11.4 0 0 0 7.4 9.5c-.86.27-1.66.6-2.36 1 .04-1.13.32-2.2.82-3.2Zm0 9.4c.7.4 1.5.73 2.36 1 .64.96 1.36 1.8 2.1 2.46a18.9 18.9 0 0 1-4.46-3.46ZM12 20c-1.1 0-2.45-1.27-3.16-3.6 1.04-.27 2.15-.4 3.16-.4s2.12.13 3.16.4C14.45 18.73 13.1 20 12 20Zm1.5-5.6c-.5-.06-1-.1-1.5-.1s-1 .04-1.5.1a13.3 13.3 0 0 1-2.04-3.94c1.13-.27 2.32-.46 3.54-.46s2.41.19 3.54.46A13.3 13.3 0 0 1 13.5 14.4Zm2.94 4.32c.74-.66 1.46-1.5 2.1-2.46.86-.27 1.66-.6 2.36-1 .04 1.13.32 2.2.82 3.2a18.9 18.9 0 0 1-4.46 3.46Z"/></svg></el-icon>
              <span class="locale-label">{{ localeLabel }}</span>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="en" :disabled="locale === 'en'">
                  English
                </el-dropdown-item>
                <el-dropdown-item command="zh" :disabled="locale === 'zh'">
                  中文
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
          <el-dropdown @command="handleCommand">
            <span class="user-info">{{ user?.userName || user?.email || t('common.user') }}</span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="deleteAccount" divided>{{ t('common.deleteAccount') }}</el-dropdown-item>
                <el-dropdown-item command="logout">{{ t('common.logout') }}</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>
      <el-main class="content">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { ElMessageBox, ElMessage } from 'element-plus'
import { useAuthStore } from '../stores/auth'
import { useLocaleStore } from '../stores/locale'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { t } = useI18n()
const localeStore = useLocaleStore()

const locale = computed(() => localeStore.locale)
const localeLabel = computed(() => (locale.value === 'zh' ? '中文' : 'EN'))

const user = computed(() => authStore.user)
const activeMenu = computed(() => route.path)
const pageTitle = computed(() => {
  const titles = {
    '/dashboard': t('nav.dashboard'),
    '/annual-report': t('nav.annualReport'),
    '/export': t('nav.export'),
  }
  return titles[route.path] || 'Freelance Hub'
})

const handleLocaleCommand = (cmd) => {
  if (cmd === 'en' || cmd === 'zh') {
    localeStore.setLocale(cmd)
  }
}

const handleCommand = async (cmd) => {
  if (cmd === 'logout') {
    try {
      const { authApi } = await import('../api')
      await authApi.logout()
    } catch (_) {
      // Local cleanup still protects this browser if the network is offline.
    }
    authStore.logout()
    router.push('/login')
    return
  }

  // GDPR 账号删除：双重确认（输入 DELETE + 输入密码——后端要求密码
  // 二次验证，防止有效会话被盗设备直接删除账号）；
  // 成功后清空本地会话并跳登录页（后端软删，30 天宽限期）。
  if (cmd === 'deleteAccount') {
    try {
      const confirm = await ElMessageBox.prompt(
        t('common.deleteAccountConfirm'),
        t('common.deleteAccountTitle'),
        {
          confirmButtonText: t('common.confirm'),
          cancelButtonText: t('common.cancel'),
          inputPlaceholder: t('common.deleteAccountPlaceholder'),
          inputValidator: (val) => val === 'DELETE' || t('common.deleteAccountPlaceholder'),
          type: 'warning',
        }
      )
      if (confirm.value !== 'DELETE') return

      const passwordPrompt = await ElMessageBox.prompt(
        t('common.deleteAccountPasswordMsg'),
        t('common.deleteAccountTitle'),
        {
          confirmButtonText: t('common.confirm'),
          cancelButtonText: t('common.cancel'),
          inputPattern: /\S+/,
          inputErrorMessage: t('common.deleteAccountPlaceholder'),
          inputType: 'password',
          type: 'warning',
        }
      )

      const { authApi } = await import('../api')
      await authApi.deleteAccount(passwordPrompt.value)
      authStore.logout()
      ElMessage.success(t('common.deleteAccountSuccess'))
      router.push('/login')
    } catch (e) {
      // ElMessageBox 取消会 reject 'cancel'，这里只在真实请求失败时提示
      if (e && e !== 'cancel' && e !== 'close') {
        ElMessage.error(e?.response?.data?.msg || t('common.deleteAccountFailed'))
      }
    }
  }
}
</script>

<style scoped>
.main-layout {
  height: 100vh;
}
.sidebar {
  background: #1e293b;
  color: #fff;
}
.logo {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  font-weight: bold;
  color: #fff;
  border-bottom: 1px solid #334155;
}
.menu {
  border-right: none;
  background: transparent;
}
.menu :deep(.el-menu-item) {
  color: #cbd5e1;
}
.menu :deep(.el-menu-item.is-active) {
  background: #2563eb;
  color: #fff;
}
.header {
  background: #fff;
  border-bottom: 1px solid #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.header-title {
  font-size: 18px;
  font-weight: 600;
  color: #1e293b;
}
.header-actions {
  display: flex;
  align-items: center;
  gap: 16px;
}
.locale-trigger {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  color: #64748b;
  padding: 4px 8px;
  border-radius: 6px;
  border: 1px solid transparent;
}
.locale-trigger:hover {
  background: #f1f5f9;
  border-color: #e2e8f0;
}
.locale-label {
  font-size: 13px;
  font-weight: 500;
}
.user-info {
  cursor: pointer;
  color: #64748b;
}
.content {
  background: #f8fafc;
  padding: 24px;
}
</style>
