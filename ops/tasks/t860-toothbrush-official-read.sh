#!/bin/bash
# **電動歯ブラシの比較記事の材料: パナソニック Store Plus の価格（本体・替えブラシ）と、オムロン公式の製品ページを読む（t860）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして」。blog3 の electric-toothbrush-comparison-2026 の替えブラシ代（年間のランニングコスト）と仕様。
# ec-plus.panasonic.jp はクラウドから応答なし、healthcare.omron.co.jp は 403 なので、Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開く（ログインの情報を持ち込まない・t688 の反省）。
# 本文は reports/t860/<key>.txt（各 30,000 字まで）。画像は取らない（クラウドから取れる）。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t860-toothbrush-official.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 電動歯ブラシ パナソニック Store Plus・オムロン公式（t860・**\$0**）"
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
    echo "⚠️ **\`playwright-core\` がどちらにも無い。** ここで止める。推測で埋めない（最上位ルール 20）。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: **\`$PWDIR\`** に在る" >> "$OUT"

# ── Chrome が CDP で上がっているか（**ポートの LISTEN では足りない**・ルール 13） ──
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** 新しく起動はしない（t174 と同じ）。ここで止める。" >> "$OUT"
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

D="$RDIR/t860"; rm -rf "$D"; mkdir -p "$D"
SCRIPT="$RDIR/.t860.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 226000 - (Date.now() - t0);
async function read(key, url, wait = 4000) {
  if (left() < 12000) { console.log(`- ⏱ ${key} は時間切れ`); return []; }
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(wait);
    for (let i = 1; i <= 4; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 4), i); await p.waitForTimeout(400); }
    // 「仕様」を開くボタンがあれば押す
    await p.evaluate(() => { for (const el of document.querySelectorAll('button,summary,a,[role=button]')) { const t = (el.innerText || '').trim(); if (/^(仕様|スペック|製品仕様|仕様・スペック|主な仕様)$/.test(t)) { try { el.click(); } catch {} } } });
    await p.waitForTimeout(1200);
    const ti = await p.title();
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${txt.replace(/\n{3,}/g, '\n\n').slice(0, 30000)}`);
    const yen = [...new Set((txt.match(/[0-9,]{3,8}\s*円[^\n]{0,12}/g) || []))].slice(0, 8);
    console.log(`- ${key}: 「${ti.slice(0, 70)}」 ${p.url().slice(0, 110)} / 本文 ${txt.length} 字 / 円の表記 ${yen.join(' ｜ ')}`);
    return await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) })));
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); return []; }
}
console.log('## パナソニック（購入ページ → Store Plus）');
await read('pana-da49-shop', 'https://panasonic.jp/teeth/products/EW-DA49/shopping.html', 6000);
await read('pana-dt88-shop', 'https://panasonic.jp/teeth/products/EW-DT88/shopping.html', 6000);
const EC = 'https://ec-plus.panasonic.jp/store/ap/storeaez/a2A/ProductDetail?HB=';
for (const hb of ['EW-DA49-K', 'EW-DT88-K', 'EW0810-W', 'EW0800-W', 'EW0830', 'EW08304', 'EW0861-W']) await read(`ec-${hb}`, EC + hb);
console.log('\n## オムロン（公式の製品ページ）');
const ol = await read('omron-list', 'https://www.healthcare.omron.co.jp/product/toothbrush/');
const cand = [...new Map(ol.filter((l) => /healthcare\.omron\.co\.jp\/product\/toothbrush\/.+/i.test(l.h)).map((l) => [l.h, l])).values()];
console.log(`- 製品ページ候補 ${cand.length} 件`); for (const l of cand.slice(0, 30)) console.log(`  - ${l.t} — ${l.h}`);
let n = 0;
for (const re of [/b3221/i, /b318/i, /b3220/i]) {
  const l = cand.find((x) => re.test(x.h + ' ' + x.t));
  if (l) await read(`omron-p${++n}`, l.h); else console.log(`- 候補なし ${re}`);
}
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
JS
RES="$RDIR/.t860-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; ls -la "$D" | awk '{print $5, $9}' >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
