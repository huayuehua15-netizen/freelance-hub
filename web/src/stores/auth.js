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
  }

  return { accessToken, refreshToken, user, isLoggedIn, setTokens, setUser, logout }
})
