<template>
  <el-container class="main-layout">
    <el-aside width="220px" class="sidebar">
      <div class="logo">Freelance Hub</div>
      <el-menu :default-active="activeMenu" router class="menu">
        <el-menu-item index="/dashboard">
          <span>Annual Dashboard</span>
        </el-menu-item>
        <el-menu-item index="/annual-report">
          <span>Tax Report</span>
        </el-menu-item>
        <el-menu-item index="/export">
          <span>Batch Export</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="header">
        <div class="header-title">{{ pageTitle }}</div>
        <el-dropdown @command="handleCommand">
          <span class="user-info">{{ user?.userName || user?.email || 'User' }}</span>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="logout">Sign Out</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
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
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const user = computed(() => authStore.user)
const activeMenu = computed(() => route.path)
const pageTitle = computed(() => {
  const titles = {
    '/dashboard': 'Annual Dashboard',
    '/annual-report': 'Tax Report',
    '/export': 'Batch Export',
  }
  return titles[route.path] || 'Freelance Hub'
})

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
.user-info {
  cursor: pointer;
  color: #64748b;
}
.content {
  background: #f8fafc;
  padding: 24px;
}
</style>
