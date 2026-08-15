import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { i18n } from '../i18n'

const STORAGE_KEY = 'app_locale'

/**
 * 语言偏好 Store。
 *
 * - 持久化到 localStorage，刷新/重开保持上次选择
 * - 切换语言时同步更新 vue-i18n.global.locale（响应式触发所有 t() 重算）
 * - 暴露 acceptLanguage 给 api/request.js 作为 Accept-Language 头值
 *
 * 设计说明：不引入 vue-i18n 的全局 locale 切换 API，由本 store 单点管理，
 * 避免双向同步（store <-> i18n.global）导致的循环更新。
 */
export const useLocaleStore = defineStore('locale', () => {
  // 初始化：localStorage > 浏览器语言 > 'en'
  const stored = localStorage.getItem(STORAGE_KEY)
  const browserLang = (navigator.language || 'en').toLowerCase()
  const initial = stored || (browserLang.startsWith('zh') ? 'zh' : 'en')

  const locale = ref(initial)
  i18n.global.locale.value = initial

  const acceptLanguage = computed(() => (locale.value === 'zh' ? 'zh-CN' : 'en'))

  function setLocale(lang) {
    if (lang !== 'en' && lang !== 'zh') return
    locale.value = lang
    i18n.global.locale.value = lang
    localStorage.setItem(STORAGE_KEY, lang)
  }

  return { locale, acceptLanguage, setLocale }
})
