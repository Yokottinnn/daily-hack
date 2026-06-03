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
// banner-matcher は TS。Node の素の ESM では .ts の named export を解決できないため
// jiti で名前空間として読み込む（node scripts/banner-fill.mjs ... で直接実行可能に）。
import { createJiti } from 'jiti';
const jiti = createJiti(import.meta.url);
const { matchBanners, renderBannerHtml } = await jiti.import('../src/lib/banner-matcher.ts');

const POSTS_DIR = 'src/content/posts';

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v ?? true];
  }),
);
const threshold = Number(args.threshold) || 15;
const maxBanners = Number(args.maxBanners) || 6;  // 3スロット × 2バナー想定で6
const dryRun = !!args.dryRun;
const refresh = !!args.refresh;  // 既存挿入を消して再配置

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

  // 既存の banner-fill 自動挿入ブロックを剥がす（refresh モード時のみ全消去 → 再配置）
  let workingBody = body;
  if (refresh) {
    workingBody = workingBody.replace(
      /\n?<!-- a8-banners auto-inserted by banner-fill[^\n]*\n<div class="affiliate-block">[\s\S]*?<\/div>\n/g,
      '\n'
    );
  } else if (workingBody.includes('class="affiliate-block"')) {
    console.log(`⏭  ${fn}: 既にバナーあり、スキップ（--refresh で再配置）`);
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
    if (refresh && workingBody !== body) {
      // refreshで剥がしただけで終わるケースも反映
      const newRaw = raw.slice(0, raw.length - body.length) + workingBody;
      if (!dryRun) await fs.writeFile(fpath, newRaw);
    }
    continue;
  }

  // ## H2 の位置を全て収集
  const h2Re = /^## /gm;
  const h2Indices = [];
  let m;
  while ((m = h2Re.exec(workingBody)) !== null) h2Indices.push(m.index);

  // 末尾 ## まとめ / ## 関連記事 の位置
  let tailIdx = -1;
  for (const marker of ['## 関連記事', '## まとめ']) {
    const idx = workingBody.indexOf(marker);
    if (idx !== -1 && (tailIdx === -1 || idx < tailIdx)) tailIdx = idx;
  }

  // 3スロットの挿入位置を決定（インデックスは workingBody のオフセット）
  // - slot1: 1番目のH2のあと（=2番目のH2の直前） 大事な序盤に1ブロック
  // - slot2: 真ん中のH2の直前（コンテンツ中央）
  // - slot3: まとめ/関連記事の直前 既存位置
  const slots = [];
  if (h2Indices.length >= 2) slots.push({ pos: h2Indices[1], label: 'slot1-after-1st-h2' });
  if (h2Indices.length >= 3) slots.push({ pos: h2Indices[Math.floor(h2Indices.length / 2)], label: 'slot2-middle' });
  if (tailIdx !== -1) slots.push({ pos: tailIdx, label: 'slot3-before-tail' });
  else if (h2Indices.length >= 2) slots.push({ pos: workingBody.length, label: 'slot3-end' });

  // マッチを slot 数で分割（先頭ほど高スコアになるよう intelligent distribute）
  const slotCount = Math.max(1, slots.length);
  const perSlot = Math.max(1, Math.ceil(matches.length / slotCount));
  const buckets = [];
  for (let i = 0; i < slotCount; i++) buckets.push(matches.slice(i * perSlot, (i + 1) * perSlot));

  // 末尾から挿入（先のインデックスがずれない）
  let newBody = workingBody;
  for (let i = slots.length - 1; i >= 0; i--) {
    const bs = buckets[i];
    if (!bs || bs.length === 0) continue;
    const block = `\n<!-- a8-banners auto-inserted by banner-fill (${slots[i].label}) -->\n<div class="affiliate-block">\n${bs.map((m) => renderBannerHtml(m.banner)).join('\n')}\n</div>\n\n`;
    newBody = newBody.slice(0, slots[i].pos) + block + newBody.slice(slots[i].pos);
  }

  const newRaw = raw.slice(0, raw.length - body.length) + newBody;

  if (dryRun) {
    console.log(`📝 ${fn}: ${slots.length}スロット × 計${matches.length}banner 挿入予定 (dry-run)`);
    slots.forEach((s, i) => console.log(`     [${s.label}] ${(buckets[i] || []).map((m) => m.banner.id).join(', ')}`));
  } else {
    await fs.writeFile(fpath, newRaw);
    console.log(`✅ ${fn}: ${slots.length}スロット × 計${matches.length}banner`);
    slots.forEach((s, i) => console.log(`     [${s.label}] ${(buckets[i] || []).map((m) => m.banner.id).join(', ')}`));
    filled.push({ slug: ctx.slug, slots: slots.length, banners: matches.map((m) => m.banner.id) });
  }
}

console.log(`\n=== 完了: ${filled.length} 記事にバナー挿入 ===`);
