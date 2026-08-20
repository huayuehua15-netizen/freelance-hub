<template>
  <el-config-provider :locale="elementLocale">
    <router-view />
  </el-config-provider>
</template>

<script setup>
/**
 * 根组件：用 ElConfigProvider 包裹，让 Element Plus 内置组件文案
 * （ElPagination/ElMessageBox/ElTable 等的"确定/取消/共 X 条"）
 * 跟随 locale store 切换 en / zh-CN。
 *
 * 注意：ElConfigProvider 的 locale 是 Element Plus 自己的语言包，
 * 与 vue-i18n 的 messages 是两套独立系统，必须同时配置才能实现
 * 全站（自定义文案 + 组件内置文案）完整的 i18n。
 */
import { computed } from 'vue'
import { ElConfigProvider } from 'element-plus'
import en from 'element-plus/es/locale/lang/en'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
import { useLocaleStore } from './stores/locale'

const localeStore = useLocaleStore()

const elementLocale = computed(() => (localeStore.locale === 'zh' ? zhCn : en))
</script>
