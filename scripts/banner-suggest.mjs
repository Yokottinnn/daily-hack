#!/usr/bin/env node
/**
 * 全記事を走査して、各記事に対するバナーマッチング結果を出力する CLI。
 * 親和性ありの banner が見つからない記事は「スキップ」として明示。
 *
 * Usage:
 *   node scripts/banner-suggest.mjs                 # 全記事レポート
 *   node scripts/banner-suggest.mjs --slug=foo      # 特定記事のみ
 *   node scripts/banner-suggest.mjs --json          # JSON出力
 *   node scripts/banner-suggest.mjs --threshold=5   # スコア閾値
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { BANNER_CATALOG } from '../src/data/banner-catalog.ts';
import { matchBanners, renderBannerHtml } from '../src/lib/banner-matcher.ts';

const POSTS_DIR = 'src/content/posts';

// CLI args
const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v ?? true];
  }),
);
const threshold = Number(args.threshold) || 10;
const topN = Number(args.topN) || 5;
const wantJson = !!args.json;

// frontmatter parser (minimal, YAML subset)
function parseFrontmatter(content) {
  const m = content.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return { data: {}, body: content };
  const yaml = m[1];
  const data = {};
  let curKey = null;
  for (const line of yaml.split('\n')) {
    const ar = line.match(/^([a-zA-Z_][\w-]*):\s*(.*)$/);
    if (ar) {
      curKey = ar[1];
      let val = ar[2].trim();
      if (val.startsWith('[') && val.endsWith(']')) {
        val = val.slice(1, -1).split(',').map((s) => s.trim().replace(/^["']|["']$/g, '')).filter(Boolean);
      } else if (val.startsWith('"') && val.endsWith('"')) {
        val = val.slice(1, -1);
      } else if (val === 'true') val = true;
      else if (val === 'false') val = false;
      data[curKey] = val;
    }
  }
  return { data, body: content.slice(m[0].length) };
}

const files = (await fs.readdir(POSTS_DIR)).filter((f) => f.endsWith('.md'));
const reports = [];

for (const fn of files) {
  if (args.slug && !fn.includes(args.slug)) continue;
  const content = await fs.readFile(path.join(POSTS_DIR, fn), 'utf8');
  const { data, body } = parseFrontmatter(content);
  if (data.draft) continue;

  const ctx = {
    slug: fn.replace('.md', ''),
    category: Array.isArray(data.category) ? data.category : (data.category ? [data.category] : []),
    tags: Array.isArray(data.tags) ? data.tags : [],
    title: data.title,
    description: data.description,
  };

  const matches = matchBanners(ctx, { topN, threshold });
  const existing = (body.match(/class="a8-banner"/g) || []).length;

  reports.push({
    slug: ctx.slug,
    categories: ctx.category,
    existing_banners: existing,
    suggested_banners: matches.map((m) => ({
      id: m.banner.id,
      name: m.banner.name,
      score: m.score,
      reason: m.reason,
    })),
    suggested_count: matches.length,
  });
}

if (wantJson) {
  console.log(JSON.stringify(reports, null, 2));
} else {
  console.log(`\n=== Banner Suggestion Report (threshold=${threshold}, topN=${topN}) ===\n`);
  const hasMatches = reports.filter((r) => r.suggested_count > 0);
  const noMatches = reports.filter((r) => r.suggested_count === 0);
  console.log(`Articles with banner suggestions: ${hasMatches.length}/${reports.length}`);
  console.log(`Articles with no relevant banner: ${noMatches.length} (skipped)\n`);

  for (const r of hasMatches) {
    console.log(`📄 ${r.slug}`);
    console.log(`   category=[${r.categories.join(',')}]  existing=${r.existing_banners}`);
    for (const s of r.suggested_banners) {
      const inserted = r.existing_banners > 0 ? '?' : '-';
      console.log(`   ${inserted} ${s.id} (score ${s.score}, ${s.reason})`);
      console.log(`     "${s.name.substring(0, 60)}..."`);
    }
    console.log();
  }

  if (noMatches.length > 0) {
    console.log(`\n=== Skipped (no banner match) ===`);
    for (const r of noMatches) {
      console.log(`  - ${r.slug} (category=[${r.categories.join(',')}])`);
    }
  }
}
