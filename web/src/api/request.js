import axios from 'axios'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '../stores/auth'
import { useLocaleStore } from '../stores/locale'
import { i18n } from '../i18n'
import router from '../router'

const t = (key) => i18n.global.t(key)

// 生产构建守卫：Vite 会在构建时把 import.meta.env.PROD 固化为 true。
// 若构建时未提供 VITE_API_BASE_URL，则所有请求都打到 localhost ——
// 必须在第一时间暴露而不是部署后才发现。
if (import.meta.env.PROD && !import.meta.env.VITE_API_BASE_URL) {
  // eslint-disable-next-line no-console
  console.error(
    '[config] Production build is missing VITE_API_BASE_URL. ' +
      'Create web/.env.production with the real API domain and rebuild.'
  )
}

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

// 这些端点的错误由调用处自行处理，不走统一提示：
// - /auth/login:密码错误需在登录表单内展示
// - /auth/register:注册错误同理
// - /auth/refresh:refresh 本身失败，由 refresh 流程处理
function isAuthEndpoint(url) {
  if (!url) return false
  return url.includes('/auth/login') || url.includes('/auth/register') || url.includes('/auth/refresh')
}

async function refreshTokens(authStore) {
  if (refreshingPromise) return refreshingPromise
  refreshingPromise = (async () => {
    const res = await axios.post(
      `${api.defaults.baseURL}/auth/refresh`,
      { refreshToken: authStore.refreshToken },
      { timeout: 10000 } // 无超时的挂起 refresh 会把共享 Promise 永久卡死
    )
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

// blob 响应的错误：后端返回的 JSON 被包成 Blob，调用处拿不到 msg。
// 这里读取并解析为对象，使 e.response.data.msg 在调用处可用。
async function normalizeBlobError(error) {
  if (error.response && typeof Blob !== 'undefined' && error.response.data instanceof Blob) {
    try {
      const text = await error.response.data.text()
      error.response.data = JSON.parse(text)
    } catch (_) {
      // 解析失败保留原 Blob
    }
  }
  return error
}

// 统一错误提示：后端 msg 优先，无 msg 时按状态码给通用文案。
// auth 端点（login/register）交调用处处理，避免重复提示。
function notifyError(error) {
  const config = error.config || {}
  if (config.silent) return
  if (isAuthEndpoint(config.url)) return

  const status = error.response?.status
  // 401 由 refresh 流程处理（refresh 失败会单独提示 sessionExpired 并跳登录）
  if (status === 401) return

  const backendMsg = error.response?.data?.msg
  let msg = backendMsg
  if (!msg) {
    if (!error.response) {
      // 无 response：网络断开 / 超时 / CORS
      msg = t('errors.networkError')
    } else if (status === 403) {
      msg = t('errors.permissionDenied')
    } else if (status === 404) {
      msg = t('errors.notFound')
    } else if (status === 429) {
      msg = t('errors.rateLimited')
    } else if (status >= 500) {
      msg = t('errors.serverError')
    } else {
      msg = t('errors.networkError')
    }
  }
  ElMessage.error(msg)
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
        // refresh 失败：提示会话过期，清登录态跳登录页
        ElMessage.error(t('errors.sessionExpired'))
        authStore.logout()
        router.push('/login')
        return Promise.reject(e)
      }
    }

    // 401 但没有 refreshToken（存储损坏/部分残留）：无法刷新，走会话过期
    // 流程，否则所有请求静默失败且 UI 无任何反馈
    if (error.response?.status === 401 && !isAuthEndpoint(originalRequest.url) && !authStore.refreshToken) {
      ElMessage.error(t('errors.sessionExpired'))
      authStore.logout()
      router.push('/login')
      return Promise.reject(error)
    }

    // blob 错误归一化（让调用处能拿到后端 msg）
    await normalizeBlobError(error)
    notifyError(error)
    return Promise.reject(error)
  }
)

export default api
