import { createI18n } from 'vue-i18n'
import en from './messages/en.json'
import zh from './messages/zh.json'

/**
 * vue-i18n 实例。
 *
 * - legacy: false -> 使用 Composition API 风格（useI18n / t）
 * - 初期同步加载 en/zh 全量资源（体积小，~3KB，无需 lazy load 复杂度）
 * - fallbackLocale: 'en' -> 缺失翻译时回退英文，再回退到 key 本身
 *
 * 与 stores/locale.js 单点联动：locale store 调用 i18n.global.locale.value 切换，
 * 全局所有 t() 调用响应式刷新。
 */
export const i18n = createI18n({
  legacy: false,
  locale: 'en',
  fallbackLocale: 'en',
  messages: {
    en,
    zh,
  },
})

export default i18n
