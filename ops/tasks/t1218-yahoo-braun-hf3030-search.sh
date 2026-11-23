#!/bin/bash
# **Yahoo!ショッピングでブラウン HF3030JBK が出る検索語を探す（t1218）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-24 blog3 の air-fryer-comparison-2026。t1216 で「ブラウン マルチフライ3 HF3030JBK」の検索が 0 件だったので、3 店ボタンの Yahoo! の検索語を直すために、いくつかの語で件数と HF3030 を含む商品名を数える。
# Cookie の無い新しいコンテキストで開く（ログインしない・画面は保存しない）。230 秒で打ち切る。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1218-yahoo-braun-hf3030.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{ echo "# Yahoo!ショッピングの HF3030 の検索語（t1218・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
[ -n "$PWDIR" ] || { echo "⚠️ playwright-core が無い。止める。" >> "$OUT"; cat "$OUT"; exit 0; }
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
[ -n "$VER" ] || { echo "⚠️ Chrome が CDP（$PORT）で応答しない。止める。" >> "$OUT"; cat "$OUT"; exit 0; }
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
SCRIPT="$RDIR/.t1218.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1280, height: 900 } });
const p = await ctx.newPage();
const qs = ['HF3030JBK', 'HF3030', 'ブラウン ノンフライヤー HF3030JBK', 'ブラウン ノンフライヤー', 'ブラウン マルチフライ3', 'BRAUN ノンフライヤー'];
for (const q of qs) {
  try {
    await p.goto(`https://shopping.yahoo.co.jp/search?p=${encodeURIComponent(q)}`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3500);
    const r = await p.evaluate(() => {
      const names = [...document.querySelectorAll('a[href*="store.shopping.yahoo.co.jp"], a[href*="paypaymall"]')].map((a) => (a.innerText || '').replace(/\s+/g, ' ').trim()).filter((t) => t.length > 15);
      const hit = [...new Set(names.filter((t) => /HF3030/i.test(t)))];
      const none = /該当する商品が見つかりませんでした|一致する商品はありません|見つかりませんでした/.test(document.body.innerText);
      return { n: names.length, hit: hit.slice(0, 5), none };
    });
    console.log(`- 「${q}」: 商品名 ${r.n} 件・HF3030 を含む ${r.hit.length} 件${r.none ? '・該当なしの表示' : ''}`);
    for (const h of r.hit) console.log(`  - ${h.slice(0, 120)}`);
  } catch (e) { console.log(`- 「${q}」: ⚠️ ${String(e).slice(0, 100)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t1218-res.txt"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
cat "$OUT"
