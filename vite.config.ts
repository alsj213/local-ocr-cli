import { defineConfig } from 'vite'
import { builtinModules } from 'node:module'

export default defineConfig({
  build: {
    lib: {
      entry: 'src/main.ts',
      formats: ['es'],
      fileName: () => 'main.js',
    },
    target: 'node20',
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      external: [...builtinModules, ...builtinModules.map((m) => `node:${m}`)],
      output: {
        // ESM CLI needs a shebang so npm's bin shim runs it with node.
        banner: '#!/usr/bin/env node',
      },
    },
  },
})
