#!/bin/bash
# **歩いてポイ活の記事（walk-poikatsu-2026）のリライト用に、公式ページの本文を読む（t234）。**
# 読むだけ・LLM 不使用・**$0**。クラウドから届かない公式（JAL・dヘルスケア・エブリポイント・
# ポイすら・ステラウォーク・ヘルスリー）を中心に、描画後の本文をそのまま出す。240 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t234-walk-poikatsu-official.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 歩いてポイ活・公式ページの本文（t234・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **\`playwright-core\` が無い。** ここで止める。" >> "$OUT"; cat "$OUT"; exit 0
fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "⚠️ **Chrome が CDP（$PORT）で応答しない。** ここで止める。" >> "$OUT"; cat "$OUT"; exit 0
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

SCRIPT="$RDIR/.t234-read.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
const URLS = [
  ['jal', 'https://www.jal.co.jp/jp/ja/jmb/wellness/'],
  ['jal-news', 'https://www.jal.co.jp/jp/ja/jmb/wellness/news/'],
  ['jal-faq', 'https://www.jal.co.jp/jp/ja/jmb/wellness/faq/'],
  ['dhc', 'https://health.docomo.ne.jp/'],
  ['dhc-premium', 'https://health.docomo.ne.jp/premium/'],
  ['every', 'https://every-point.jp/'],
  ['poisura', 'https://poisura.com/'],
  ['stella', 'https://stellarwalk.jp/'],
  ['healthree', 'https://healthree.io/'],
  ['cokeon-walk', 'https://c.cocacola.co.jp/app/walk/'],
  ['rakuten-hc', 'https://healthcare.rakuten.co.jp/'],
  ['arucoin', 'https://arucoin.jp/'],
];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
for (const [k, u] of URLS) {
  if (Date.now() - T0 > 200000) { console.log(`## ${k}\n\n（時間切れで読んでいない）\n`); continue; }
  console.log(`## ${k}\n\n- URL: ${u}`);
  try {
    const r = await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await p.waitForTimeout(2500);
    console.log(`- 状態: ${r ? r.status() : '?'} / 最終 URL: ${p.url()}\n`);
    let t = await p.evaluate(() => document.body ? document.body.innerText : '');
    t = t.split('\n').map(s => s.trim()).filter(Boolean).join('\n');
    console.log('```text\n' + t.slice(0, 7000) + '\n```\n');
  } catch (e) {
    console.log(`- ⚠️ 失敗: ${String(e).slice(0, 200)}\n`);
  }
}
await p.close();
process.exit(0);
JS

PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" >> "$OUT" 2>&1
RC=$?
echo "" >> "$OUT"
echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cat "$OUT" | head -c 2000
