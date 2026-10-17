#!/usr/bin/env node
/**
 * 記事ごとに**指定した** A8 バナーを差し込む（banner-fill の自動選定ではなく、人が選んだ案件だけ）。
 * 2026-10-15: 利用者「アフィリエイトが一切記事の中に入っていない記事に、積極的に入れて」。
 * 割り当ての正本はマネタイズ作戦室の「記事の構想 → 成果リンクを入れる記事」（db: linkplan）。
 *
 * Usage: node scripts/banner-place.mjs [--dryRun]
 *   - 見出し（`## ` と section-with-mascot の生 HTML h2）の 2 本目の前と、真ん中の前に 1 枚ずつ置く。3 枚目は記事の末尾近く
 *   - 既に affiliate-block がある記事・`<!-- a8-banners: none` の印がある記事は触らない
 *   - 入れた記事は isPR: true にする（ステマ規制）
 */
import fs from 'node:fs/promises';
import { createJiti } from 'jiti';
const jiti = createJiti(import.meta.url);
const { renderBannerHtml } = await jiti.import('../src/lib/banner-matcher.ts');
const { BANNER_ENTRIES } = await jiti.import('../src/data/banner-catalog.ts');
const dryRun = process.argv.includes('--dryRun');

export const PLAN = {
  'lalaport-guide-2026': ['earthcar', 'travelist-hotel'],
  'credit-card-kaiaku-2026': ['hapitas', 'chobirich'],
  'walk-poikatsu-2026': ['hapitas', 'chobirich'],
  'outlet-mall-guide-2026': ['earthcar', 'aeon-rentacar', 'travelist-hotel'],
  'momiji-2026-kanto': ['travelist-hotel', 'aeon-rentacar', 'yumeyado'],
  'takanawa-gateway-city-guide-2026': ['travelist-hotel'],
  'tokyo-bay-hanabi-2026': ['travelist-hotel'],
  'price-hike-2026-summer-defense': ['denki-choice', 'gas-choice', 'enepi-denki'],
  'ikea-toyosu-2026': ['earthcar'],
  'budget-overseas-resorts-2026': ['trifa-esim', 'sakura-mobile-kaigai', 'kkday'],
  'wangan-tower-construction-map-2026': ['softbank-air', 'docomo-hikari', 'au-hikari'],
  'harumi-flag-koukai-2026': ['softbank-air', 'docomo-hikari', 'au-hikari'],
  'point-kaiaku-timeline-2026': ['hapitas', 'chobirich'],
  'qr-payment-comparison-2026': ['hapitas', 'chobirich'],
  // 2026-10-17: 成果リンクが 0 本だった記事のうち、主題に合う提携先があるもの（利用者「0 本の 43 記事に入れる」）
  'summer-electricity-saving-2026': ['denki-choice', 'enepi-denki'],
  'narita-haneda-overseas-direct-2026': ['trifa-esim', 'sakura-mobile-kaigai', 'kkday'],
  'his-clearance-sale-2026-jun': ['trifa-esim', 'sakura-mobile-kaigai', 'kkday'],
  'credit-card-no-annual-fee-comparison-2026': ['hapitas', 'chobirich'],
  'credit-card-campaign-2026-07': ['hapitas', 'chobirich'],
  'paypay-card-gold-kaiaku-2026': ['hapitas', 'chobirich'],
  'may-2026-bank-campaigns-roundup': ['hapitas', 'chobirich'],
  'best-online-banks-2026': ['hapitas', 'chobirich'],
  'poikatsu-tax-guide-2026': ['hapitas', 'chobirich'],
  'poikatsu-hourly-wage-2026': ['hapitas', 'chobirich'],
  'nisa-investment-beginner-guide-2026': ['hapitas', 'chobirich'],
  'fx-account-comparison-2026': ['hapitas', 'chobirich'],
};

// バナーの前に置く一文（案件の種類ごと）。バナーだけを置くと、なぜそこにあるのかが読者に分からない
const LEAD = {
  hapitas: 'カードや口座を作る前に、ポイントサイトに同じ案件が載っていないか見ておくといいわよ。経由するだけで、公式の特典とは別にポイントが付くことがあるの。',
  'denki-choice': '料金プランの見直しは、比較サイトで郵便番号と使用量を入れてまとめて見るのが早いわよ。',
  'trifa-esim': '海外に行くなら、現地の通信と現地ツアーも出発前に押さえておくと着いてから慌てないわよ。',
};

const byId = Object.fromEntries(BANNER_ENTRIES.map((b) => [b.id, b]));
for (const [slug, ids] of Object.entries(PLAN)) {
  const fp = `src/content/posts/${slug}.md`;
  const raw = await fs.readFile(fp, 'utf8');
  const fm = raw.match(/^---\n[\s\S]*?\n---\n/)[0];
  let body = raw.slice(fm.length);
  if (body.includes('class="affiliate-block"') || body.includes('<!-- a8-banners: none')) { console.log(`⏭  ${slug}: 既にバナーあり／none の印`); continue; }
  const missing = ids.filter((i) => !byId[i]); if (missing.length) throw new Error(`${slug}: カタログに無い ${missing}`);
  const heads = [...body.matchAll(/^(## |<div class="section-with-mascot">)/gm)].map((m) => m.index);
  let tail = -1; for (const k of ['## 関連記事', '## まとめ']) { const i = body.indexOf(k); if (i !== -1 && (tail === -1 || i < tail)) tail = i; }
  const pos = [];
  if (heads.length >= 2) pos.push(heads[1]);
  if (heads.length >= 4) pos.push(heads[Math.floor(heads.length / 2)]);
  pos.push(tail !== -1 ? tail : body.length);
  const uniq = [...new Set(pos)].sort((a, b) => a - b);
  // 案件を位置に順に配る（位置が足りなければ最後の位置にまとめる）
  const buckets = uniq.map(() => []); ids.forEach((id, i) => buckets[Math.min(i, uniq.length - 1)].push(id));
  for (let i = uniq.length - 1; i >= 0; i--) {
    if (!buckets[i].length) continue;
    const lead = i === 0 && LEAD[ids[0]] ? `<p>${LEAD[ids[0]]}</p>\n\n` : '';
    const block = `\n<!-- a8-banners placed by banner-place (${buckets[i].join(',')}) -->\n${lead}<div class="affiliate-block">\n${buckets[i].map((id) => renderBannerHtml(byId[id])).join('\n')}\n</div>\n\n`;
    body = body.slice(0, uniq[i]) + block + body.slice(uniq[i]);
  }
  let fm2 = /^isPR:/m.test(fm) ? fm.replace(/^isPR:.*$/m, 'isPR: true') : fm.replace(/\n---\n$/, '\nisPR: true\n---\n');
  console.log(`${dryRun ? '📝' : '✅'} ${slug}: 見出し ${heads.length} 本 → ${uniq.length} か所 ${buckets.map((b) => b.join('+')).join(' / ')}`);
  if (!dryRun) await fs.writeFile(fp, fm2 + body);
}
