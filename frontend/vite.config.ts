import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      'components': path.resolve(__dirname, './src/components'),
    },
  },
  server: {
    host: '::',
    port: 8080,
    cors: {
      origin: 'http://localhost:5173',
    },
  },
  build: {
    manifest: true,
    rollupOptions: {
      input: './src/main.tsx',
    },
  },
})

