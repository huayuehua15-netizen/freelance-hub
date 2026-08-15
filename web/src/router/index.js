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
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  const authStore = useAuthStore()
  const requiresAuth = to.matched.some((record) => record.meta.requiresAuth)

  if (!authStore.accessToken) {
    return requiresAuth ? { name: 'Login' } : true
  }

  // A token alone is not enough to grant access to the Web console.  Fetch a
  // fresh profile after page reload so an expired/downgraded account cannot
  // keep navigating based on stale localStorage.
  try {
    const profile = await authApi.getMe()
    authStore.setUser(profile.data)
  } catch (_) {
    authStore.logout()
    return to.name === 'Login' ? true : { name: 'Login' }
  }

  if (requiresAuth && authStore.user?.premiumType !== 'annual') {
    authStore.logout()
    return { name: 'Login', query: { reason: 'annual_required' } }
  }

  return to.name === 'Login' ? { name: 'Dashboard' } : true
})

export default router
