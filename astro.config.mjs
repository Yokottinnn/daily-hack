// @ts-check
import { defineConfig } from 'astro/config';
import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import mdx from '@astrojs/mdx';
import rehypeExternalLinks from 'rehype-external-links';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

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

/**
 * 記事の更新日を集める（サイトマップの `lastmod` 用）。
 *
 * **`lastmod` が無いサイトマップは「何も変わっていない」と言っているのと同じ。**
 * 2026-09-14 に URL 検査 API で全記事を調べたところ、最終クロールが 2〜3 か月前の
 * まま止まっている記事が並び、6 本以上が「クロール済み - インデックス未登録」だった。
 * Google に再クロールを促す一次の合図がこれなので、必ず出す。
 *
 * コンテンツコレクションは設定ファイルから読めないので、フロントマターを直接 読む。
 * **`updatedDate` があればそれを、無ければ `publishDate` を使う。**
 */
function postLastmod() {
  const dir = join(process.cwd(), 'src/content/posts');
  /** @type {Record<string, string>} */
  const map = {};
  for (const name of readdirSync(dir)) {
    if (!name.endsWith('.md') && !name.endsWith('.mdx')) continue;
    const slug = name.replace(/\.mdx?$/, '');
    const head = readFileSync(join(dir, name), 'utf-8').slice(0, 2000);
    const updated = head.match(/^updatedDate:\s*"?(\d{4}-\d{2}-\d{2})/m);
    const published = head.match(/^publishDate:\s*"?(\d{4}-\d{2}-\d{2})/m);
    const date = (updated ?? published)?.[1];
    if (date) map[`/posts/${slug}/`] = new Date(`${date}T00:00:00Z`).toISOString();
  }
  return map;
}

const LASTMOD = postLastmod();

export default defineConfig({
  site: 'https://daily-hack.fieldbeside.com',
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [
    sitemap({
      serialize(item) {
        const path = new URL(item.url).pathname;
        const lastmod = LASTMOD[path];
        if (lastmod) item.lastmod = lastmod;
        return item;
      },
    }),
    mdx(),
    pagefindIntegration,
  ],
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
