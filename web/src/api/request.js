import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import router from '../router'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:3001/api/v1',
  timeout: 15000,
})

api.interceptors.request.use(
  (config) => {
    const authStore = useAuthStore()
    if (authStore.accessToken) {
      config.headers.Authorization = `Bearer ${authStore.accessToken}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

api.interceptors.response.use(
  (response) => response.data,
  async (error) => {
    const originalRequest = error.config
    if (error.response?.status === 401 && !originalRequest._retry && useAuthStore().refreshToken) {
      originalRequest._retry = true
      const authStore = useAuthStore()
      try {
        const res = await axios.post(
          `${api.defaults.baseURL}/auth/refresh`,
          { refreshToken: authStore.refreshToken }
        )
        const { accessToken, refreshToken } = res.data.data
        authStore.setTokens(accessToken, refreshToken)
        originalRequest.headers.Authorization = `Bearer ${accessToken}`
        return api(originalRequest)
      } catch (e) {
        authStore.logout()
        router.push('/login')
        return Promise.reject(e)
      }
    }
    return Promise.reject(error)
  }
)

export default api
