// @ts-check
import { defineConfig } from 'astro/config';
import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import mdx from '@astrojs/mdx';
import rehypeExternalLinks from 'rehype-external-links';
import rehypeShop from './src/lib/shop/rehype-shop.mjs';
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

/**
 * サイトマップから外すタグ（2026-11-12・AdSense「有用性の低いコンテンツ」の対策）。
 * 設定は src/data/site-quality.json。記事が tagIndexMinPosts 本より少ないタグのページは
 * ページの側でも noindex にしている（src/pages/tags/[tag].astro）。湾岸の地区・湾岸ニュースは 1 本以上で残す。
 */
const QUALITY = JSON.parse(readFileSync(join(process.cwd(), 'src/data/site-quality.json'), 'utf-8'));
function thinTagPaths() {
  const min = Number(QUALITY.tagIndexMinPosts) || 0;
  if (min <= 0) return new Set();
  const wanganSrc = readFileSync(join(process.cwd(), 'src/lib/wangan.ts'), 'utf-8');
  const keep = new Set([...wanganSrc.matchAll(/\{\s*tag:\s*'([^']+)'/g)].map((m) => m[1]));
  const news = wanganSrc.match(/WANGAN_NEWS_TAG\s*=\s*'([^']+)'/);
  if (news) keep.add(news[1]);
  const dir = join(process.cwd(), 'src/content/posts');
  /** @type {Record<string, number>} */
  const count = {};
  for (const name of readdirSync(dir)) {
    if (!name.endsWith('.md') && !name.endsWith('.mdx')) continue;
    const head = readFileSync(join(dir, name), 'utf-8').slice(0, 3000);
    if (/^draft:\s*true/m.test(head)) continue;
    const m = head.match(/^tags:\s*\[(.*)\]/m);
    for (const t of m ? [...m[1].matchAll(/"([^"]+)"/g)].map((x) => x[1]) : []) count[t] = (count[t] || 0) + 1;
  }
  const out = new Set();
  for (const t of keep) if (!count[t]) out.add(`/tags/${t}/`);   // 記事がまだ無い湾岸の地区（ページは noindex）
  for (const [t, n] of Object.entries(count)) if (n < (keep.has(t) ? 1 : min)) out.add(`/tags/${t}/`);
  return out;
}
const THIN_TAGS = thinTagPaths();
/** @type {string[]} */
const SITEMAP_EXCLUDE = Array.isArray(QUALITY.sitemapExclude) ? QUALITY.sitemapExclude : [];

export default defineConfig({
  site: 'https://daily-hack.fieldbeside.com',
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [
    sitemap({
      // 湾岸マップの外側を画像に焼くための作業用ページは載せない（2026-11-07）
      // 記事の少ないタグ・下書き一覧・サイト内検索も載せない（2026-11-12・src/data/site-quality.json）
      filter: (page) => {
        if (page.includes('/wangan-map-bake/')) return false;
        let path = new URL(page).pathname;
        try { path = decodeURIComponent(path); } catch {}
        if (SITEMAP_EXCLUDE.some((x) => path === x)) return false;
        return !THIN_TAGS.has(path);
      },
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
      // 3 店ボタン（楽天・Yahoo!・Amazon）。docs/shop-comparison.md
      rehypeShop,
      [
        rehypeExternalLinks,
        {
          target: '_blank',
          // 全外部リンクに noopener。アフィリエイト系（px.a8.net 等）には sponsored + nofollow も付与
          rel: (/** @type {{ properties?: { href?: string } }} */ element) => {
            const href = String(element?.properties?.href ?? '');
            const isAffiliate = /px\.a8\.net|adm\.shinobi\.jp|hb\.afl\.rakuten\.co\.jp|amazon\.co\.jp\/.*\?tag=|ck\.jp\.ap\.valuecommerce\.com|af\.moshimo\.com/.test(href);
            return isAffiliate
              ? ['sponsored', 'noopener', 'nofollow']
              : ['noopener'];
          },
        },
      ],
    ],
  },
});
