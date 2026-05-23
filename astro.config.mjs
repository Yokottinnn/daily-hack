// @ts-check
import { defineConfig } from 'astro/config';
import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import mdx from '@astrojs/mdx';
import rehypeExternalLinks from 'rehype-external-links';

const execAsync = promisify(exec);

/** @type {import('astro').AstroIntegration} */
const pagefindIntegration = {
  name: 'pagefind',
  hooks: {
    'astro:build:done': async ({ logger }) => {
      try {
        const { stdout } = await execAsync('npx pagefind --site dist');
        logger.info('Pagefind index built');
        if (stdout) logger.info(stdout);
      } catch (err) {
        logger.warn(`Pagefind index failed: ${err}`);
      }
    },
  },
};

export default defineConfig({
  site: 'https://daily-hack.fieldbeside.com',
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [sitemap(), mdx(), pagefindIntegration],
  markdown: {
    rehypePlugins: [
      [
        rehypeExternalLinks,
        {
          target: '_blank',
          // 全外部リンクに noopener。アフィリエイト系（px.a8.net 等）には sponsored + nofollow も付与
          rel: (/** @type {{ properties?: { href?: string } }} */ element) => {
            const href = String(element?.properties?.href ?? '');
            const isAffiliate = /px\.a8\.net|adm\.shinobi\.jp|hb\.afl\.rakuten\.co\.jp|amazon\.co\.jp\/.*\?tag=/.test(href);
            return isAffiliate
              ? ['sponsored', 'noopener', 'nofollow']
              : ['noopener'];
          },
        },
      ],
    ],
  },
});
