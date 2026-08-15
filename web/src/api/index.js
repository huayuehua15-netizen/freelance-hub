import api from './request'

export const authApi = {
  login: (data) => api.post('/auth/login', data),
  register: (data) => api.post('/auth/register', data),
  getMe: () => api.get('/auth/me'),
  logout: () => api.post('/auth/logout'),
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
