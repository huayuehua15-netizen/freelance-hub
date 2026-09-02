import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

// 持久化到 localStorage 的用户字段白名单。
// 登录接口的 res.data 里带 accessToken/refreshToken——整包存 localStorage
// 意味着 token 双份暴露给任何 XSS/恶意扩展，这里只保留非敏感 profile 字段。
const USER_SAFE_FIELDS = [
  'userId',
  'userName',
  'email',
  'userEmail',
  'currency',
  'timezone',
  'premiumType',
  'isPremium',
  'expireTime',
  'trialEndTime',
  'lastSyncTime',
  'createdAt',
  'updatedAt',
]

const sanitizeUser = (userData) => {
  if (!userData || typeof userData !== 'object') return null
  const safe = {}
  for (const key of USER_SAFE_FIELDS) {
    if (userData[key] !== undefined) safe[key] = userData[key]
  }
  return safe
}

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
    refreshToken.value = access ? refresh : ''
    localStorage.setItem('accessToken', access)
    if (refresh) localStorage.setItem('refreshToken', refresh)
    else localStorage.removeItem('refreshToken')
  }

  const setUser = (userData) => {
    const safe = sanitizeUser(userData)
    user.value = safe
    if (safe) localStorage.setItem('user', JSON.stringify(safe))
    else localStorage.removeItem('user')
  }

  // 兼容历史遗留：清掉旧版本整包写入的 user（内含 token 副本）
  const purgeLegacyUserTokens = () => {
    try {
      const raw = localStorage.getItem('user')
      if (!raw) return
      const parsed = JSON.parse(raw)
      if (parsed && (parsed.accessToken || parsed.refreshToken)) {
        localStorage.setItem('user', JSON.stringify(sanitizeUser(parsed)))
      }
    } catch (_) {
      /* 解析失败留给初始化逻辑清理 */
    }
  }
  purgeLegacyUserTokens()

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
