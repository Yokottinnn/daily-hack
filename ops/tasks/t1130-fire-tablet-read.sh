#!/bin/bash
# **タブレットの比較記事の材料: Amazon の Fire タブレットの商品ページ（技術仕様・セキュリティアップデートの保証）と写真を読む（t1130）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして」。blog3 の tablet-comparison-2026（iPad・Galaxy Tab・Xiaomi・Fire）。
# amazon.co.jp はクラウドから読めない（ボット確認のページになる）ので、Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開く（ログインの情報を持ち込まない・氏名が写らない）。
# 商品ページの URL は推測で組み立てず、Amazon の検索結果（Amazon デバイスの絞り込み）から題名で探す。本文は reports/t1130/<key>.txt、写真の候補は reports/t1130/img/。240 秒で打ち切る。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1130-fire-tablet.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# Fire タブレットの商品ページ（t1130・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **\`playwright-core\` がどちらにも無い。** ここで止める（最上位ルール 20）。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: **\`$PWDIR\`** に在る" >> "$OUT"

VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** 新しく起動はしない。ここで止める。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"
echo "" >> "$OUT"

run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
D="$RDIR/t1130"; rm -rf "$D"; mkdir -p "$D/img"
SCRIPT="$RDIR/.t1130.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 }, locale: 'ja-JP' });   // Cookie なし（ログインの情報を持ち込まない）
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 232000 - (Date.now() - t0);
// 1) 検索結果（Amazon デバイスの絞り込み）から Fire タブレットの商品ページを集める
const found = new Map();
for (const q of ['Fire タブレット', 'Fire HD 10 タブレット', 'Fire Max 11']) {
  if (left() < 120000) break;
  try {
    await p.goto(`https://www.amazon.co.jp/s?k=${encodeURIComponent(q)}&i=amazon-devices`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3500);
    const rows = await p.evaluate(() => [...document.querySelectorAll('[data-component-type="s-search-result"][data-asin]')].map((e) => ({ asin: e.getAttribute('data-asin'), title: ((e.querySelector('h2') || {}).innerText || '').trim().slice(0, 160), sponsored: /スポンサー|Sponsored/.test(e.innerText) })).filter((r) => r.asin));
    console.log(`\n## 検索「${q}」 ${rows.length} 件（題名: ${(await p.title()).slice(0, 40)}）`);
    for (const r of rows.slice(0, 16)) { console.log(`- ${r.asin} ${r.sponsored ? '[広告] ' : ''}${r.title}`); if (!r.sponsored && /Fire/.test(r.title) && /タブレット/.test(r.title)) found.set(r.asin, r.title); }
  } catch (e) { console.log(`- ⚠️ 検索「${q}」: ${String(e).slice(0, 120)}`); }
}
// 2) 機種ごとに 1 件ずつ（キッズ・カバー・セットを除く）商品ページを読む
const want = [['fire-hd-10', /Fire HD 10/], ['fire-max-11', /Fire Max 11/], ['fire-hd-8', /Fire HD 8/], ['fire-7', /Fire 7/]];
for (const [key, re] of want) {
  if (left() < 25000) { console.log(`- ⏱ ${key} は時間切れ`); break; }
  const hit = [...found.entries()].find(([, t]) => re.test(t) && !/キッズ|Kids|カバー|ケース|セット|Plus|まとめ買い|整備済/.test(t));
  if (!hit) { console.log(`\n### ${key}\n- 検索結果に見つからない`); continue; }
  const [asin, title] = hit;
  try {
    await p.goto(`https://www.amazon.co.jp/dp/${asin}`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3000);
    for (let i = 1; i <= 5; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 5), i); await p.waitForTimeout(350); }
    const info = await p.evaluate(() => {
      const pick = (sel) => [...document.querySelectorAll(sel)].map((e) => e.innerText.replace(/[ \t]+/g, ' ').trim()).filter(Boolean).join('\n');
      const img = document.querySelector('#landingImage, #imgTagWrapperId img');
      let hi = img ? (img.getAttribute('data-old-hires') || '') : '';
      if (!hi && img) { try { const dyn = JSON.parse(img.getAttribute('data-a-dynamic-image') || '{}'); hi = Object.keys(dyn).sort((a, z) => dyn[z][0] - dyn[a][0])[0] || ''; } catch {} }
      const alt = [...document.querySelectorAll('#altImages img')].map((i) => (i.src || '').replace(/\._[^.]+_\./, '.')).filter((s) => /media-amazon/.test(s)).slice(0, 6);
      return {
        title: (document.querySelector('#productTitle') || {}).innerText || '',
        bullets: pick('#feature-bullets li'),
        overview: pick('#productOverview_feature_div tr'),
        spec: pick('#productDetails_techSpec_section_1 tr, #productDetails_techSpec_section_2 tr, #tech tr, #prodDetails tr, #detailBullets_feature_div li, table.a-keyvalue tr'),
        hi, alt,
      };
    });
    const sec = info.spec.split('\n').filter((l) => /セキュリティ|アップデート|発売|OS|ストレージ|容量|ディスプレイ|画面|重量|重さ|バッテリー|電池|メモリ|RAM|プロセッサ|寸法|サイズ|世代|Google|アプリ/.test(l));
    fs.writeFileSync(`${D}/${key}.txt`, `ASIN: ${asin}\nURL: ${p.url()}\nTITLE: ${info.title.trim()}\n\n# 箇条書き\n${info.bullets}\n\n# 概要\n${info.overview}\n\n# 技術仕様\n${info.spec}`.slice(0, 60000));
    console.log(`\n### ${key}\n- ${asin} 「${info.title.trim().slice(0, 120)}」\n- 仕様の行 ${info.spec.split('\n').length} / 拾った行:`);
    for (const l of sec.slice(0, 40)) console.log(`  - ${l.replace(/\n/g, ' ').slice(0, 200)}`);
    let n = 0;
    for (const s of [info.hi, ...info.alt].filter(Boolean)) {
      if (n >= 4 || left() < 15000) break;
      try {
        const r = await ctx.request.get(s, { timeout: 15000 }); if (!r.ok()) continue;
        const buf = await r.body(); n++; fs.writeFileSync(`${D}/img/${key}-${n}.jpg`, buf);
        console.log(`  - img ${key}-${n}.jpg ${buf.length}B ${s.slice(0, 120)}`);
      } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
JS
RES="$RDIR/.t1130-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 245 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; ls -la "$D" "$D/img" | awk '{print $5, $9}' >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
