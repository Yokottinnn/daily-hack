#!/usr/bin/env node
/**
 * 指定記事に対して banner-matcher の結果からトップ N バナーを記事末尾に自動挿入。
 *
 * Usage:
 *   node scripts/banner-fill.mjs --slug=summer-cospa-travel-2026 --maxBanners=3 --threshold=15
 *   node scripts/banner-fill.mjs --all --threshold=18                 # 全ギャップ記事に高信頼で自動挿入
 *
 * 挿入位置: 「## まとめ」セクションの直前 or 文末（マーカー <!-- a8-banners --> を置く）
 * 既存の <div class="a8-banner"> がある記事はスキップ（上書き禁止）
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { matchBanners, renderBannerHtml } from '../src/lib/banner-matcher.ts';

const POSTS_DIR = 'src/content/posts';

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v ?? true];
  }),
);
const threshold = Number(args.threshold) || 15;
const maxBanners = Number(args.maxBanners) || 3;
const dryRun = !!args.dryRun;

function parseFrontmatter(content) {
  const m = content.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return { data: {}, body: content, raw: content };
  const yaml = m[1];
  const data = {};
  for (const line of yaml.split('\n')) {
    const ar = line.match(/^([a-zA-Z_][\w-]*):\s*(.*)$/);
    if (!ar) continue;
    let val = ar[2].trim();
    if (val.startsWith('[') && val.endsWith(']')) {
      val = val.slice(1, -1).split(',').map((s) => s.trim().replace(/^["']|["']$/g, '')).filter(Boolean);
    } else if (val.startsWith('"') && val.endsWith('"')) {
      val = val.slice(1, -1);
    } else if (val === 'true') val = true;
    else if (val === 'false') val = false;
    data[ar[1]] = val;
  }
  return { data, body: content.slice(m[0].length), raw: content };
}

const files = (await fs.readdir(POSTS_DIR)).filter((f) => f.endsWith('.md'));
const filled = [];

for (const fn of files) {
  if (args.slug && !fn.includes(args.slug)) continue;
  if (!args.all && !args.slug) continue;

  const fpath = path.join(POSTS_DIR, fn);
  const raw = await fs.readFile(fpath, 'utf8');
  const { data, body } = parseFrontmatter(raw);

  if (data.draft) continue;

  if (body.includes('class="a8-banner"')) {
    console.log(`⏭  ${fn}: 既にバナーあり、スキップ`);
    continue;
  }

  const ctx = {
    slug: fn.replace('.md', ''),
    category: Array.isArray(data.category) ? data.category : (data.category ? [data.category] : []),
    tags: Array.isArray(data.tags) ? data.tags : [],
    title: data.title,
    description: data.description,
  };

  const matches = matchBanners(ctx, { threshold, topN: maxBanners });
  if (matches.length === 0) {
    console.log(`⏭  ${fn}: マッチなし（閾値 ${threshold}）、スキップ`);
    continue;
  }

  const bannerBlock = `\n<!-- a8-banners auto-inserted by banner-fill (banner-matcher) -->\n<div class="affiliate-block">\n${matches.map((m) => renderBannerHtml(m.banner)).join('\n')}\n</div>\n`;

  // 挿入位置を決定: 「## 関連記事」「## まとめ」のどちらか先に出る方の直前
  let insertPos = -1;
  for (const marker of ['## 関連記事', '## まとめ']) {
    const idx = body.indexOf(marker);
    if (idx !== -1 && (insertPos === -1 || idx < insertPos)) {
      insertPos = idx;
    }
  }
  let newBody;
  if (insertPos !== -1) {
    newBody = body.slice(0, insertPos) + bannerBlock + '\n' + body.slice(insertPos);
  } else {
    newBody = body + bannerBlock;
  }

  const newRaw = raw.slice(0, raw.length - body.length) + newBody;

  if (dryRun) {
    console.log(`📝 ${fn}: 挿入予定 ${matches.length} banner (dry-run)`);
    matches.forEach((m) => console.log(`     ${m.banner.id} score=${m.score}`));
  } else {
    await fs.writeFile(fpath, newRaw);
    console.log(`✅ ${fn}: 挿入 ${matches.length} banner`);
    matches.forEach((m) => console.log(`     ${m.banner.id} score=${m.score}`));
    filled.push({ slug: ctx.slug, banners: matches.map((m) => m.banner.id) });
  }
}

console.log(`\n=== 完了: ${filled.length} 記事にバナー挿入 ===`);
