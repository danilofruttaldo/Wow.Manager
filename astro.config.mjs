import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://wow.danilofruttaldo.com',
  integrations: [sitemap()],
  prefetch: {
    prefetchAll: false,
    defaultStrategy: 'hover',
  },
});
