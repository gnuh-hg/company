import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Dev server proxies /api → local Node server (server.mjs) so the front-end
// can talk to the engine data-layer during `npm run dev`. In production the
// built dist/ is served by server.mjs directly (same origin, no proxy needed).
const API_TARGET = process.env.API_TARGET || 'http://localhost:5179';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: API_TARGET,
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
});
