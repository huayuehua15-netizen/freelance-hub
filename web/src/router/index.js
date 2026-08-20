import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { authApi } from '../api'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/LoginView.vue'),
    meta: { requiresAuth: false },
  },
  {
    // 密码找回/重置/邮箱验证落地页：公开访问（邮件链接直达）
    path: '/forgot-password',
    name: 'ForgotPassword',
    component: () => import('../views/ForgotPasswordView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/reset-password',
    name: 'ResetPassword',
    component: () => import('../views/ResetPasswordView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/verify-email',
    name: 'VerifyEmail',
    component: () => import('../views/VerifyEmailView.vue'),
    meta: { requiresAuth: false },
  },
  {
    // 隐私政策页面：公开访问，无需登录。Google Play 上架要求隐私政策 URL 公网可访问。
    path: '/privacy',
    name: 'Privacy',
    component: () => import('../views/PrivacyView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/',
    component: () => import('../layouts/MainLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        redirect: '/dashboard',
      },
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('../views/DashboardView.vue'),
      },
      {
        path: 'annual-report',
        name: 'AnnualReport',
        component: () => import('../views/AnnualReportView.vue'),
      },
      {
        path: 'export',
        name: 'Export',
        component: () => import('../views/ExportView.vue'),
      },
    ],
  },
  // 404 兜底：未匹配路径重定向到首页，由 auth 流程决定去 login 还是 dashboard
  {
    path: '/:pathMatch(.*)*',
    redirect: '/',
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// getMe 校验缓存：页面刷新后首次校验，之后 5 分钟内路由切换用缓存，避免每次跳转都打后端。
// 超时后重新校验，兼顾性能与账号降级/过期的及时性。
let profileVerifiedAt = 0
const PROFILE_VERIFY_TTL = 5 * 60 * 1000

router.beforeEach(async (to) => {
  const authStore = useAuthStore()
  const requiresAuth = to.matched.some((record) => record.meta.requiresAuth)

  // 公开页面（隐私政策等）直接放行，不触发 getMe，避免 token 过期时被踢到登录页
  if (!requiresAuth && to.name !== 'Login') {
    return true
  }

  if (!authStore.accessToken) {
    return requiresAuth ? { name: 'Login' } : true
  }

  // 首次或缓存过期时拉取最新 profile，防止 localStorage 里的过期/降级账号继续导航。
  // 缓存窗口内直接用 store 中的 user，减少后端压力。
  const needVerify = !profileVerifiedAt || Date.now() - profileVerifiedAt > PROFILE_VERIFY_TTL
  if (needVerify) {
    try {
      const profile = await authApi.getMe()
      authStore.setUser(profile.data)
      profileVerifiedAt = Date.now()
    } catch (e) {
      profileVerifiedAt = 0
      // 仅会话失效（401/403）才登出踢回登录页；网络故障/超时（无 status）
      // 保持本地缓存的会话降级放行，弱网下刷新页面不再被误登出
      const status = e?.response?.status
      if (status === 401 || status === 403) {
        authStore.logout()
        return to.name === 'Login' ? true : { name: 'Login' }
      }
      // 网络错误：离线放行（后端不可达不代表会话失效）
    }
  }

  if (requiresAuth && authStore.user?.premiumType !== 'annual') {
    authStore.logout()
    return { name: 'Login', query: { reason: 'annual_required' } }
  }

  return to.name === 'Login' ? { name: 'Dashboard' } : true
})

export default router
