#!/bin/bash
# **OpenClaw 用の Chrome（CDP 18810）に、楽天アフィリエイトのログイン画面を開いて前に出す（t246）。**
# 利用者がそこで 1 回 手でログインする。自動ログインは楽天側で止められている（エラーも出ずに進まない・t243）。
# 開くだけ・LLM 不使用・**$0**。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t246-open-rakuten-login.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{ echo "# 楽天アフィリエイトのログイン画面を開く（t246・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
[ -n "$PWDIR" ] || { echo "⚠️ playwright-core が無い" >> "$OUT"; cat "$OUT"; exit 0; }
SCRIPT="$RDIR/.t246.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const { chromium } = createRequire(process.env.PW_DIR + '/x.js')('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();   // **閉じない**（利用者がこのタブでログインする）
await p.goto('https://affiliate.rakuten.co.jp/report/summary', { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
await p.bringToFront();
console.log(`- 開いた: ${p.url().slice(0, 80)}`);
console.log(`- 題名: ${await p.title()}`);
process.exit(0);
JS
PW_DIR="$PWDIR" CDP_PORT="$PORT" /opt/homebrew/bin/node "$SCRIPT" >> "$OUT" 2>&1
# Chrome を手前に出す（OpenClaw の Chrome が通常の Chrome と同じアプリ名でも、少なくとも Chrome が前に来る）
/usr/bin/osascript -e 'tell application "Google Chrome" to activate' >/dev/null 2>&1 || true
echo "rc=$? / $(wc -c < "$OUT") bytes" >> "$OUT"
cat "$OUT"
