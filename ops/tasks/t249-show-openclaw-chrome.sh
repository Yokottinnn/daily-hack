#!/bin/bash
# **OpenClaw の Chrome（CDP 18810）がどの窓かを利用者に分かるようにする（t249）。** $0。
# 大きく「これが OpenClaw の Chrome です」と書いたタブと、楽天アフィリエイトのログイン画面を開いて前に出す。
# 利用者のいつもの Chrome とはログイン状態が別なので、こちらで 1 回 ログインしてもらう（t248 で判明）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t249-show-openclaw-chrome.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{ echo "# OpenClaw の Chrome を見せる（t249・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
[ -n "$PWDIR" ] || { echo "⚠️ playwright-core が無い" >> "$OUT"; cat "$OUT"; exit 0; }
SCRIPT="$RDIR/.t249.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const { chromium } = createRequire(process.env.PW_DIR + '/x.js')('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const sign = await ctx.newPage();
await sign.setContent('<html><head><title>★ これが OpenClaw の Chrome</title></head><body style="font:bold 44px sans-serif;background:#ffeb3b;padding:40px;line-height:1.6">これが <u>OpenClaw の Chrome</u> です。<br>この窓の「ログイン - 楽天」タブで、楽天アフィリエイトにログインしてください。<br><span style="font-size:24px">（いつもの Chrome とはログイン状態が別です）</span></body></html>');
const login = await ctx.newPage();
await login.goto('https://affiliate.rakuten.co.jp/report/summary', { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
await sign.bringToFront();
console.log(`- 案内のタブと、楽天のログイン画面（${(await login.title()).slice(0, 30)}）を開いた`);
process.exit(0);
JS
PW_DIR="$PWDIR" CDP_PORT="$PORT" /opt/homebrew/bin/node "$SCRIPT" >> "$OUT" 2>&1
RC=$?
echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cat "$OUT"
