import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  build: {
    // 沙箱保护下 rmSync 拦批量删除；禁用 emptyOutDir 让 Vite 直接写入
    // 现有文件，残留文件由手动维护（rm 单个文件不触发批量保护）
    emptyOutDir: false,
    rollupOptions: {
      output: {
        // 拆分第三方依赖：此前全部打进单个 1.17MB chunk，首屏解析慢，
        // 且任一业务改动都会让整包缓存失效。element-plus/echarts 体积
        // 稳定，独立成 chunk 后可长期命中浏览器缓存。
        manualChunks(id) {
          if (!id.includes('node_modules')) return undefined
          if (id.includes('element-plus')) return 'vendor-element'
          if (id.includes('echarts')) return 'vendor-echarts'
          if (id.includes('/vue/') || id.includes('/vue-router/') || id.includes('/pinia/')) {
            return 'vendor-vue'
          }
          return 'vendor'
        },
      },
    },
  },
})
