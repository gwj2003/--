import { fileURLToPath, URL } from 'node:url'
import { resolve } from 'node:path'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    vueDevTools(),
  ],
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        privacy: resolve(__dirname, 'privacy-policy.html'),
        terms: resolve(__dirname, 'terms-conditions.html'),
        basin: resolve(__dirname, 'basin-monitoring.html'),
        knowledge: resolve(__dirname, 'knowledge-graph.html'),
        mobile: resolve(__dirname, 'mobile-monitoring.html'),
      },
    },
  },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    },
  },
  server: {
    allowedHosts: [
      'localhost',
      '127.0.0.1',
      '.ngrok-free.dev',     // 允许所有 ngrok 免费域名
      '.ngrok.io',           // 允许所有 ngrok 付费域名
    ],
    proxy: {
      // 告诉 Vite：只要是发给 '/api' 的请求，都帮我偷偷转发给本地的 8000 端口
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
      }
    }
  }
})
