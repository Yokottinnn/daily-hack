#!/bin/bash
# **加湿空気清浄機の比較記事の 3 店ボタン（Yahoo!・Amazon）の行き先を確かめる（t821）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして」。記事 humidifying-air-purifier-comparison-2026 の src/data/shop/humidifying-air-purifier.json と同じ検索語で、
# Yahoo!ショッピングの検索と Amazon の検索（tag=dailyhack-22）を Chrome で開き、着いた URL・題名・型番が何回出るかだけを出す。
# **ページの本文は保存しない**（ログイン中の名前などが入るため）。楽天はクラウドから hb.afl → 検索結果（scid=af_pc_etc）まで確認済み。120 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t821-hap-shop-links.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 加湿空気清浄機の記事の 3 店ボタンの行き先（t821・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **\`playwright-core\` が無い。ここで止める。**" >> "$OUT"; cat "$OUT"; exit 0
fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "⚠️ **Chrome が CDP（$PORT）で応答しない。ここで止める。**" >> "$OUT"; cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"

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

SCRIPT="$RDIR/.t821-links.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const items = [
  ['シャープ KI-WX75', 'KI-WX75'], ['シャープ KI-WX70', 'KI-WX70'], ['シャープ KI-WS50', 'KI-WS50'],
  ['ダイキン MCK707A', 'MCK707A'], ['ダイキン MCK557A', 'MCK557A'],
  ['パナソニック F-VX70D', 'F-VX70D'], ['パナソニック F-VXW90', 'F-VXW90'],
];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const t0 = Date.now();
let n = 0, ok = 0;
for (const [kw, model] of items) {
  for (const [shop, url] of [
    ['Yahoo!', `https://shopping.yahoo.co.jp/search?p=${encodeURIComponent(kw)}`],
    ['Amazon', `https://www.amazon.co.jp/s?k=${encodeURIComponent(kw)}&tag=dailyhack-22`],
  ]) {
    if (Date.now() - t0 > 105000) { console.log('- ⏱ 時間切れ'); break; }
    n++;
    try {
      const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
      await p.waitForTimeout(2500);
      const fin = p.url();
      const title = (await p.title()).slice(0, 60);
      const hits = await p.evaluate((m) => (document.body.innerText.match(new RegExp(m, 'g')) || []).length, model);
      const tagKept = shop === 'Amazon' ? /tag=dailyhack-22/.test(fin) : null;
      if (r && r.status() < 400 && hits > 0) ok++;
      console.log(`- ${shop} ${model}: HTTP ${r ? r.status() : '?'} / 型番 ${hits} 回 / ${tagKept === null ? '' : `tag ${tagKept ? '残る' : '**消えた**'} / `}着いた先 ${fin.slice(0, 110)} / 題名「${title}」`);
    } catch (e) { console.log(`- ${shop} ${model}: ⚠️ ${String(e).slice(0, 100)}`); }
  }
}
console.log(`\n対象 ${items.length * 2} / 開いた ${n} / 型番が出た ${ok}`);
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t821-res.txt"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 120 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
head -c 9000 "$OUT"
