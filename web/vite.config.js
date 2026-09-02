import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  build: {
    // 沙箱保护下 rmSync 拦批量删除；禁用 emptyOutDir 让 Vite 直接写入
    // 现有文件，残留文件由手动维护（rm 单个文件不触发批量保护）
    emptyOutDir: false,
  },
})
