import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

// ---------------------------------------------------------------------------
// Token 存储：sessionStorage（B2 修复）
// ---------------------------------------------------------------------------
// 此前 token 存 localStorage——跨会话持久且任何 XSS 都能读取。改为
// sessionStorage：
// - 同标签页内刷新/导航不丢失（日常使用无感）
// - 关闭标签页/窗口即清空，XSS 的 token 窃取窗口从"永久"缩到"单个会话"
// - 旧版 localStorage 副本在启动时自动迁移到 sessionStorage 并清除
// 仍然不是 httpOnly Cookie 的完全替代（无法抵御运行期 XSS），但对纯
// 前端改造而言是收益/风险比最高的方案。
// ---------------------------------------------------------------------------
const TOKEN_KEY_ACCESS = 'accessToken'
const TOKEN_KEY_REFRESH = 'refreshToken'
const USER_KEY = 'user'

// 持久化到存储的用户字段白名单。
// 登录接口的 res.data 里带 accessToken/refreshToken——整包存存储
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

// 旧版 localStorage 里的 token/profile 迁移到 sessionStorage 并清除，
// 避免升级后旧副本继续残留（XSS 仍可读）。
function migrateLegacyLocalStorage() {
  try {
    for (const key of [TOKEN_KEY_ACCESS, TOKEN_KEY_REFRESH, USER_KEY]) {
      const legacy = localStorage.getItem(key)
      if (legacy == null) continue
      if (sessionStorage.getItem(key) == null) sessionStorage.setItem(key, legacy)
      localStorage.removeItem(key)
    }
  } catch (_) {
    // 存储不可用（隐私模式等）：store 初始化逻辑各自兜底
  }
}
migrateLegacyLocalStorage()

export const useAuthStore = defineStore('auth', () => {
  const accessToken = ref(sessionStorage.getItem(TOKEN_KEY_ACCESS) || '')
  const refreshToken = ref(sessionStorage.getItem(TOKEN_KEY_REFRESH) || '')
  const storedUser = sessionStorage.getItem(USER_KEY)
  let initialUser = null
  try {
    initialUser = storedUser ? JSON.parse(storedUser) : null
  } catch (_) {
    sessionStorage.removeItem(USER_KEY)
  }
  const user = ref(initialUser)

  const isLoggedIn = computed(() => !!accessToken.value)

  const setTokens = (access, refresh) => {
    accessToken.value = access
    refreshToken.value = access ? refresh : ''
    if (access) sessionStorage.setItem(TOKEN_KEY_ACCESS, access)
    else sessionStorage.removeItem(TOKEN_KEY_ACCESS)
    if (refresh) sessionStorage.setItem(TOKEN_KEY_REFRESH, refresh)
    else sessionStorage.removeItem(TOKEN_KEY_REFRESH)
  }

  const setUser = (userData) => {
    const safe = sanitizeUser(userData)
    user.value = safe
    if (safe) sessionStorage.setItem(USER_KEY, JSON.stringify(safe))
    else sessionStorage.removeItem(USER_KEY)
  }

  // 兼容历史遗留：清掉旧版本整包写入的 user（内含 token 副本）
  const purgeLegacyUserTokens = () => {
    try {
      const raw = sessionStorage.getItem(USER_KEY)
      if (!raw) return
      const parsed = JSON.parse(raw)
      if (parsed && (parsed.accessToken || parsed.refreshToken)) {
        sessionStorage.setItem(USER_KEY, JSON.stringify(sanitizeUser(parsed)))
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
    // 两种存储都清：覆盖本会话数据 + 可能残留的旧版 localStorage 数据
    for (const store of [sessionStorage, localStorage]) {
      store.removeItem(TOKEN_KEY_ACCESS)
      store.removeItem(TOKEN_KEY_REFRESH)
      store.removeItem(USER_KEY)
    }
    // 用户作用域的本地数据一并清理：导出历史含上一账号的财务元数据，
    // 共享电脑场景下残留属于隐私泄漏
    sessionStorage.removeItem('export_history')
    localStorage.removeItem('export_history')
  }

  return { accessToken, refreshToken, user, isLoggedIn, setTokens, setUser, logout }
})
