import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useLocaleStore } from '../stores/locale'
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
    // 同步当前语言偏好到后端,使后端返回本地化的错误消息
    try {
      const localeStore = useLocaleStore()
      if (localeStore.acceptLanguage) {
        config.headers['Accept-Language'] = localeStore.acceptLanguage
      }
    } catch (_) {
      // store 未初始化时忽略,保持默认请求行为
    }
    return config
  },
  (error) => Promise.reject(error)
)

// 模块级共享的 refresh Promise:并发 401 只发一次 refresh,其余挂同一 Promise
// 避免后端 refresh 轮换(旧 token 立即失效)导致第二个 refresh 401 → 误踢登录
let refreshingPromise = null

// 这些端点 401 直接走原错误链,不触发 refresh:
// - /auth/login:密码错误需正常上报给用户
// - /auth/refresh:refresh 本身失败,再 refresh 会递归死循环
function isAuthEndpoint(url) {
  if (!url) return false
  return url.includes('/auth/login') || url.includes('/auth/refresh')
}

async function refreshTokens(authStore) {
  if (refreshingPromise) return refreshingPromise
  refreshingPromise = (async () => {
    const res = await axios.post(`${api.defaults.baseURL}/auth/refresh`, {
      refreshToken: authStore.refreshToken,
    })
    const { accessToken, refreshToken } = res.data.data
    authStore.setTokens(accessToken, refreshToken)
    return accessToken
  })()
    .finally(() => {
      // 成功或失败都清空,允许后续再次尝试
      refreshingPromise = null
    })
  return refreshingPromise
}

api.interceptors.response.use(
  (response) => response.data,
  async (error) => {
    const originalRequest = error.config
    const authStore = useAuthStore()
    const shouldRefresh =
      error.response?.status === 401 &&
      !originalRequest._retry &&
      !isAuthEndpoint(originalRequest.url) &&
      authStore.refreshToken

    if (shouldRefresh) {
      originalRequest._retry = true
      try {
        const accessToken = await refreshTokens(authStore)
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
