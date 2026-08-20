import api from './request'

export const authApi = {
  login: (data) => api.post('/auth/login', data),
  register: (data) => api.post('/auth/register', data),
  getMe: () => api.get('/auth/me'),
  logout: () => api.post('/auth/logout'),
  // 密码找回：统一返回 200（防账号枚举），真实用户收到含一次性 token 的邮件
  forgotPassword: (data) => api.post('/auth/forgot-password', data),
  resetPassword: (data) => api.post('/auth/reset-password', data),
  // 邮箱验证（非阻断式，token 一次性）
  verifyEmail: (data) => api.post('/auth/verify-email', data),
  // GDPR 账号删除：后端要求密码二次验证，防有效会话被盗设备滥用
  deleteAccount: (currentPassword) => api.delete('/auth/account', { data: { currentPassword } }),
}

export const reportApi = {
  getMonthly: (params) => api.get('/report/monthly', { params }),
  getAnnual: (params) => api.get('/report/annual', { params }),
  exportPdf: (params) => api.get('/report/export', { params, responseType: 'blob' }),
  exportCsv: (params) => api.get('/report/export-csv', { params, responseType: 'blob' }),
}

export const premiumApi = {
  getEntitlement: () => api.get('/premium/entitlement'),
}
