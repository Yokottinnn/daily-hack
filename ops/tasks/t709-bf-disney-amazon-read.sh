#!/bin/bash
# **ディズニーストアのブラックフライデー（11/17 の続報）と Amazon のブラックフライデーの会場ページを Chrome で開き、日付・割引の行だけを抜き出す（t709）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-15 利用者がダイアログで「11/19 の正午にこの会話へ予約を入れる」を選んだ作業。ディズニーストアの公式ページはクラウドから 403 になるため Mac で読む。
# **ログイン後の画面の本文は出さない。** 名前・お届け先・アカウントの行は捨て、日付・割引・セール名の行だけを出す。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t709-bf-disney-amazon-read.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{
  echo "# ディズニーストアと Amazon のブラックフライデー（t709・読むだけ・\$0）"
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

SCRIPT="$RDIR/.t709.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [
  ["disney", "https://store.disney.co.jp/special/black-friday-sale.html"],
  ["amazonbf", "https://www.amazon.co.jp/blackfriday"],
];
const KEEP = /(\d{1,2}\/\d{1,2}|\d{1,2}月\d{1,2}日|20\d\d年|〜|～|まで|期間|OFF|％|%|ブラックフライデー|BLACK ?FRIDAY|先行|セール|ポイント)/i;
const DROP = /(こんにちは|様|お届け先|アカウント|ログイン|サインイン|注文履歴|郵便番号|〒|カート)/;
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(6000);
    await p.evaluate(()=>window.scrollTo(0,document.body.scrollHeight)).catch(()=>{});
    await p.waitForTimeout(1500);
    const t = await p.evaluate(() => document.body ? document.body.innerText : '');
    const ti = await p.title();
    const lines = [...new Set(t.split('\n').map(s=>s.trim()).filter(s=>s && s.length<=160 && KEEP.test(s) && !DROP.test(s)))].slice(0,120);
    console.log(`\n## ${k}\n\n- タイトル: ${DROP.test(ti) ? '(省略)' : ti}\n- URL: ${p.url().slice(0,120)}\n- 本文 ${t.length} 文字のうち、日付・割引の行 ${lines.length} 行\n\n\`\`\`text\n${lines.join('\n')}\n\`\`\``);
  } catch (e) { console.log(`\n## ${k}\n\n- ⚠️ ${String(e).slice(0,160)}`); }
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t709-res.txt"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 120 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 9000 "$OUT"
