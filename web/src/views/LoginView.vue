<template>
  <div class="login-container">
    <div class="login-card">
      <h1>Freelance Hub</h1>
      <p class="subtitle">Web Dashboard — Annual Contractor Plan</p>
      <el-form :model="form" @submit.prevent="handleLogin">
        <el-form-item label="Email">
          <el-input v-model="form.email" type="email" placeholder="you@example.com" />
        </el-form-item>
        <el-form-item label="Password">
          <el-input v-model="form.password" type="password" placeholder="••••••••" show-password />
        </el-form-item>
        <el-button type="primary" :loading="loading" class="login-btn" @click="handleLogin">
          Sign In
        </el-button>
      </el-form>
      <p class="hint">Web access requires an Annual Contractor subscription.</p>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { authApi } from '../api'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()
const loading = ref(false)
const form = ref({ email: '', password: '' })

const handleLogin = async () => {
  if (!form.value.email || !form.value.password) {
    ElMessage.warning('Please enter email and password')
    return
  }
  loading.value = true
  try {
    const res = await authApi.login(form.value)
    authStore.setTokens(res.data.accessToken, res.data.refreshToken)
    authStore.setUser(res.data)
    if (res.data.premiumType !== 'annual') {
      authStore.logout()
      ElMessage.warning('Web dashboard is available for the Annual Contractor plan only.')
      return
    }
    ElMessage.success('Login successful')
    router.push('/dashboard')
  } catch (e) {
    ElMessage.error(e.response?.data?.msg || 'Login failed')
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
}
.login-card {
  width: 400px;
  padding: 40px;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
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
