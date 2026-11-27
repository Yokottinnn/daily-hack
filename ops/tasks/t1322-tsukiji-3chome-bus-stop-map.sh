#!/bin/bash
# **都営バス 築地三丁目（晴海埠頭方向）のりば移設後の位置図を取ってくる（t1322）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# t1321 で読んだお知らせ（https://www.kotsu.metro.tokyo.jp/pickup_information/news/bus/2026/bus_i_2026112712926_h.html）の図。
# クラウドからは kotsu.metro.tokyo.jp が Incapsula で弾かれるので、Mac の Chrome（CDP）でお知らせのページを開き、同じページの中から画像を取って $OPS_REPORT_DIR に PNG で置く。90 秒で打ち切る。

set -uo pipefail
TASK=t1322
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/$TASK-tsukiji-3chome-bus-stop-map.md"
IMG="$RDIR/$TASK-tsukiji-3chome-bus-stop-map.png"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{
  echo "# 築地三丁目（晴海埠頭方向）のりば移設後の位置図（$TASK・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then echo "⚠️ playwright-core が無い。ここで止める。" >> "$OUT"; cat "$OUT"; exit 0; fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then echo "⚠️ Chrome が CDP（$PORT）で応答しない。ここで止める。" >> "$OUT"; cat "$OUT"; exit 0; fi

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

SCRIPT="$RDIR/.$TASK.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });
const p = await ctx.newPage();
const page = 'https://www.kotsu.metro.tokyo.jp/pickup_information/news/bus/2026/bus_i_2026112712926_h.html';
const src = 'https://www.kotsu.metro.tokyo.jp/pickup_information/news/i/2026/bus_i_2026112712926_h_01.png';
try {
  await p.goto(page, { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(2500);
  const r = await p.request.get(src, { headers: { referer: page } });
  const buf = await r.body();
  console.log(`- 画像: HTTP ${r.status()} / ${r.headers()['content-type']} / ${buf.length} bytes`);
  if (r.status() === 200 && buf.length > 1000 && buf[0] === 0x89) { fs.writeFileSync(process.env.IMG, buf); console.log(`- 保存: ${process.env.IMG}`); }
  else console.log('- ⚠️ PNG ではない／小さすぎる。保存しない');
} catch (e) { console.log(`- ⚠️ 失敗: ${String(e).slice(0, 160)}`); }
await ctx.close().catch(() => {});
process.exit(0);
JS
IMG="$IMG" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 90 node "$SCRIPT" >> "$OUT" 2>&1
echo "rc=$?" >> "$OUT"
if [ -f "$IMG" ]; then echo "- 置いた画像の大きさ: $(wc -c < "$IMG") bytes" >> "$OUT"; else echo "- 画像は置けていない" >> "$OUT"; fi
cat "$OUT"
