#!/bin/bash
# **湾岸ニュースの表紙の材料: 江東区の「子育て応援給付事業（こども1人につき1万円）」の公式ページの画面を撮る（t1160）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-24 blog3 の湾岸ニュース（koto-kosodate-oen-kyufu-2026）。区のページに画像が無いので、公式ページの見出しの部分を表紙にする。
# Mac の Chrome（CDP）に Cookie の無い新しいコンテキストで開く（ログインの情報を持ち込まない・公開のページだけ）。
# 画像は reports/t1160/（PNG）。90 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1160-koto-benefit-shot.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{ echo "# 江東区 子育て応援給付の公式ページの画面（t1160・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
[ -n "$PWDIR" ] || { echo "⚠️ playwright-core が無い。ここで止める" >> "$OUT"; cat "$OUT"; exit 0; }
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
[ -n "$VER" ] || { echo "⚠️ Chrome が CDP（$PORT）で応答しない。ここで止める" >> "$OUT"; cat "$OUT"; exit 0; }
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"

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
D="$RDIR/t1160"; rm -rf "$D"; mkdir -p "$D"
SCRIPT="$RDIR/.t1160.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 2 });
const p = await ctx.newPage();
const pages = [
  ['benefit-main', 'https://www.city.koto.lg.jp/281000/kosodatesien/2026benefit.html'],
];
for (const [key, url] of pages) {
  try {
    const r = await p.goto(url, { waitUntil: 'load', timeout: 30000 });
    console.log(`- ${key}: HTTP ${r ? r.status() : '?'} ${url}`);
    await p.waitForTimeout(1500);
    // 本文の見出しの位置まで動かして、上 720px を撮る
    const h = await p.$('h1');
    if (h) { await h.scrollIntoViewIfNeeded(); await p.evaluate(() => window.scrollBy(0, -120)); }
    await p.screenshot({ path: `${D}/${key}-view.png` });
    const main = await p.$('#tmp_contents, #contents, main, #main');
    if (main) await main.screenshot({ path: `${D}/${key}-main.png` });
    console.log(`  - 撮った: ${key}-view.png${main ? ' / ' + key + '-main.png' : ''}`);
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 200)}`); }
}
await ctx.close();
await b.close().catch(() => {});
JS
( export PW_DIR="$PWDIR" D="$D" CDP_PORT="$PORT"; run_limited 90 "$NODE_BIN" "$SCRIPT" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
echo >> "$OUT"
echo '```text' >> "$OUT"; ls -la "$D" >> "$OUT" 2>&1; echo '```' >> "$OUT"
cat "$OUT"
