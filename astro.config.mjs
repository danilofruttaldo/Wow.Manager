import { defineConfig } from 'astro/config';

export default defineConfig({
  prefetch: {
    prefetchAll: false,
    defaultStrategy: 'hover',
  },
  vite: {
    // Il CSS lo minifica esbuild invece di lightningcss: quest'ultimo e' un
    // modulo nativo non firmato e Smart App Control lo blocca sulla macchina
    // di sviluppo, facendo morire `astro build`. Per lo stesso motivo
    // package.json rimpiazza esbuild con esbuild-wasm.
    build: { cssMinify: 'esbuild' },
  },
});
