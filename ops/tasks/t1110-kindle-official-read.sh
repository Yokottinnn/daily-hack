#!/bin/bash
# **電子書籍リーダーの比較記事の材料: Amazon の Kindle（2026 年モデル）の商品ページの仕様（技術仕様）・ASIN・商品写真を読む（t1110）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして」。blog3 の ereader-comparison-2026（Kindle・楽天 Kobo・BOOX）。
# amazon.co.jp はクラウドから読めないので、Mac の Chrome（CDP）で **Cookie の無い新しいコンテキスト**で開く（ログインしていない状態。氏名などは出ない）。
# 入口はアマゾンのプレスリリースに書かれた短い URL（amazon.co.jp/Kindle-2026 など）。本文は reports/t1110/<key>.txt（箇条書き・選択肢・技術仕様だけ）、写真は reports/t1110/img/。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1110-kindle-official.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# Kindle 2026 年モデルの商品ページ（t1110・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

# ── playwright-core を探す（**棚卸しに書いてある場所から**） ──
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  {
    echo "⚠️ **\`playwright-core\` がどちらにも無い。**"
    echo ""
    echo "**ここで止める。** 推測で埋めない（最上位ルール 20）。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: **\`$PWDIR\`** に在る" >> "$OUT"

# ── Chrome が CDP で上がっているか（**ポートの LISTEN では足りない**・ルール 13） ──
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  {
    echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** 新しく起動はしない（t174 と同じ）"
    echo ""
    echo "**ここで止める。** Chrome が戻ってから同じものを出し直す。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"
echo "" >> "$OUT"

# ── 描画して読む ──────────────────────────────────────────
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
D="$RDIR/t1110"; rm -rf "$D"; mkdir -p "$D/img"
SCRIPT="$RDIR/.t1110.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 }, locale: 'ja-JP' });   // Cookie なし（ログインしていない）
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 226000 - (Date.now() - t0);
const PAGES = [
  ['kindle16', 'https://www.amazon.co.jp/Kindle-2026'],
  ['paperwhite', 'https://www.amazon.co.jp/Kindle-Paperwhite-2026'],
  ['colorsoft', 'https://www.amazon.co.jp/Kindle-Colorsoft-2026'],
  ['scribe', 'https://www.amazon.co.jp/kindlescribe2026'],
  ['kindle32', 'https://www.amazon.co.jp/Kindle-32GB'],
  ['pwse', 'https://www.amazon.co.jp/Kindle-Paperwhite-SE-2026'],
];
for (const [key, url] of PAGES) {
  if (left() < 25000) { console.log(`- ⏱ ${key} は時間切れ`); continue; }
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    for (let i = 1; i <= 5; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 5), i); await p.waitForTimeout(400); }
    const ti = await p.title();
    const fin = p.url();
    const asin = (fin.match(/\/dp\/([A-Z0-9]{10})/) || [])[1] || await p.evaluate(() => (document.querySelector('input#ASIN, input[name="ASIN"]') || {}).value || '');
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    // 箇条書き・選択肢（広告の有無・容量・色）・「技術仕様」以降だけを残す（ページ全体は出さない）
    const k = Math.max(txt.indexOf('技術仕様'), txt.indexOf('技術詳細'));
    const feat = await p.evaluate(() => { const e = document.querySelector('#feature-bullets'); return e ? e.innerText : ''; });
    const twister = await p.evaluate(() => [...document.querySelectorAll('#twister, #twister_feature_div, [id^="inline-twister"]')].map((e) => e.innerText).join('\n'));
    const spec = k >= 0 ? txt.slice(k, k + 9000) : '(技術仕様の見出しが見つからない)';
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${fin}\nASIN: ${asin}\n\n## 箇条書き\n${feat.slice(0, 5000)}\n\n## 選択肢\n${twister.slice(0, 3000)}\n\n## 仕様\n${spec}`);
    const imgs = await p.evaluate(() => {
      const out = [];
      const li = document.querySelector('#landingImage, #imgBlkFront');
      if (li) {
        if (li.getAttribute('data-old-hires')) out.push(li.getAttribute('data-old-hires'));
        const dyn = li.getAttribute('data-a-dynamic-image');
        if (dyn) { try { const o = JSON.parse(dyn); const best = Object.entries(o).sort((a, z) => z[1][0] - a[1][0])[0]; if (best) out.push(best[0]); } catch {} }
      }
      for (const s of document.querySelectorAll('script')) { const m = (s.textContent || '').match(/"hiRes":"(https:[^"]+)"/g); if (m) for (const x of m) out.push(x.slice(9, -1)); }
      return [...new Set(out)].slice(0, 6);
    });
    console.log(`\n### ${key}\n- 「${ti.slice(0, 100)}」 ${fin.slice(0, 120)}\n- ASIN: **${asin}** / 本文 ${txt.length} 文字 / 技術仕様 ${k >= 0 ? 'あり' : '無し'} / 写真候補 ${imgs.length}`);
    let n = 0;
    for (const s of imgs) {
      if (n >= 4 || left() < 15000) break;
      try {
        const r = await ctx.request.get(s, { timeout: 15000 });
        if (!r.ok()) { console.log(`  - img ✗ ${r.status()} ${s.slice(0, 100)}`); continue; }
        const buf = await r.body(); n++; const f = `${key}-${n}.jpg`; fs.writeFileSync(`${D}/img/${f}`, buf);
        console.log(`  - img ${f} ${buf.length}B ${s.slice(0, 120)}`);
      } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
console.log(`\n---\n対象 ${PAGES.length} / 経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
JS
RES="$RDIR/.t1110-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; ls -la "$D" "$D/img" | awk '{print $5, $9}' >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
