// 「編集部おすすめ」の元になる、記事ごとの読者数（直近 28 日）を書き出す（2026-11-07・LLM 不使用・$0）。
// 2026-11-07 利用者「単純にたくさん PV を集めている記事を編集部おすすめの記事として設定すればいい」。
// 元は作戦室のスナップショット（scripts/strategy-board/build-snapshot.mjs の出力）の articles。
// 数はボットを除いた読者（h28）。無い記事だけ Cloudflare の訪問（v28・ボットを含む）を使う。
// 使い方: node scripts/gen-popular-posts.mjs <snap.json>   → src/data/popular-posts.json
// 毎朝の作戦室の更新（docs/strategy-board-routine.md の 2-B）で回して commit する。
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const src = process.argv[2];
if (!src) { console.error('使い方: node scripts/gen-popular-posts.mjs <snap.json>'); process.exit(1); }
const snap = JSON.parse(fs.readFileSync(src, 'utf8'));
// 2026-11-08: 記事の一覧はスナップショットの隣の <名前>.arts.json に分かれた（snapshot/latest が大きくなりすぎたため）。無ければ本体の articles を読む
const artsPath = src.replace(/\.json$/, '.arts.json');
const articles = snap.articles?.length ? snap.articles : (fs.existsSync(artsPath) ? JSON.parse(fs.readFileSync(artsPath, 'utf8')).articles || [] : []);
if (!articles.length) { console.error(`記事の一覧が見つからない（${src} の articles も ${artsPath} も空）。書き換えずに止める`); process.exit(1); }
const pv = {};
for (const a of articles) {
  const n = a.h28 != null ? a.h28 : a.v28;
  if (a.slug && n > 0) pv[a.slug] = n;
}
const sorted = Object.fromEntries(Object.entries(pv).sort((x, y) => y[1] - x[1]));
const out = {
  _note: '各カテゴリーの「編集部おすすめ」は、この数の多い順に上位 3 本（src/lib/popular.ts）。毎朝の作戦室の更新で書き直す',
  generated: snap.generatedAt,
  window: { last: snap.pvMeta?.last ?? null, days: 28 },
  metric: '直近 28 日の読者（ボット除外。無い記事は訪問）',
  pv: sorted,
};
const OUT = path.join(ROOT, 'src/data/popular-posts.json');
fs.writeFileSync(OUT, JSON.stringify(out, null, 1) + '\n');
console.log(`記事 ${Object.keys(sorted).length} 本 → ${path.relative(ROOT, OUT)}（最終日 ${out.window.last}）`);
