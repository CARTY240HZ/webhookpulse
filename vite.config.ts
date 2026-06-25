import { ViteDevServer, Plugin } from 'vite'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig(async () => {
  const plugins: (Plugin | null)[] = [react()]

  // Bundle analyzer — cargado dinámicamente para evitar dependencia obligatoria
  if (process.env.ANALYZE === 'true') {
    const { visualizer } = await import('rollup-plugin-visualizer')
    plugins.push(visualizer({
      open: true,
      gzipSize: true,
      brotliSize: true,
      filename: 'dist/stats.html',
    }))
  }

  return {
    plugins: plugins.filter(Boolean) as Plugin[],
    build: {
      target: 'esnext',
      cssCodeSplit: true,
      sourcemap: true,
      rollupOptions: {
        output: {
          manualChunks: {
            react: ['react', 'react-dom', 'react-router-dom'],
            supabase: ['@supabase/supabase-js'],
            lucide: ['lucide-react'],
          },
        },
      },
      chunkSizeWarningLimit: 200,
    },
    optimizeDeps: {
      include: ['react', 'react-dom', 'react-router-dom', '@supabase/supabase-js', 'lucide-react'],
    },
    server: {
      port: 5173,
      host: true,
    },
    preview: {
      port: 4173,
    },
  }
})
