import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import fs from 'node:fs'
import path from 'node:path'

// https://vite.dev/config/
export default defineConfig(({ command }) => ({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    // Only the local dev server needs HTTPS (for the Azure AD redirect flow).
    // A production `vite build` never starts a server and must not depend on
    // the local dev cert, which is intentionally excluded from the Docker
    // build context (see .dockerignore).
    ...(command === 'serve'
      ? {
          https: {
            cert: fs.readFileSync(path.resolve(__dirname, '.cert/localhost.pem')),
            key: fs.readFileSync(path.resolve(__dirname, '.cert/localhost.key')),
          },
        }
      : {}),
  },
}))
