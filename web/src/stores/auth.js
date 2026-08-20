import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  const accessToken = ref(localStorage.getItem('accessToken') || '')
  const refreshToken = ref(localStorage.getItem('refreshToken') || '')
  const storedUser = localStorage.getItem('user')
  let initialUser = null
  try {
    initialUser = storedUser ? JSON.parse(storedUser) : null
  } catch (_) {
    localStorage.removeItem('user')
  }
  const user = ref(initialUser)

  const isLoggedIn = computed(() => !!accessToken.value)

  const setTokens = (access, refresh) => {
    accessToken.value = access
    refreshToken.value = refresh
    localStorage.setItem('accessToken', access)
    localStorage.setItem('refreshToken', refresh)
  }

  const setUser = (userData) => {
    user.value = userData
    localStorage.setItem('user', JSON.stringify(userData))
  }

  const logout = () => {
    accessToken.value = ''
    refreshToken.value = ''
    user.value = null
    localStorage.removeItem('accessToken')
    localStorage.removeItem('refreshToken')
    localStorage.removeItem('user')
    // 用户作用域的本地数据一并清理：导出历史含上一账号的财务元数据，
    // 共享电脑场景下残留属于隐私泄漏
    localStorage.removeItem('export_history')
  }

  return { accessToken, refreshToken, user, isLoggedIn, setTokens, setUser, logout }
})
