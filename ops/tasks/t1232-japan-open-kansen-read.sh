#!/bin/bash
# **ジャパンオープン2026（50m）の観戦の案内を読む（t1232）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# t1231 で swim.or.jp が証明書の期限切れ（ERR_CERT_DATE_INVALID）で開けなかった。代わりに、t1230 で見つけた公式の X の投稿が貼っているリンクを開く:
#   東京都スポーツ（@sports_tokyo・2026-11-11）の「東京都スポーツ観戦招待事業」 https://t.co/31LRTHYf9u
#   日本水泳連盟（@JAQUA1924・2026-11-07）の観戦チケットの販売 https://t.co/C8gOxBalrj
# Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開き、行き先の URL・題名・本文（6000 字まで）を出す。ログインの要るページは開かない。150 秒で打ち切る。

set -uo pipefail
TASK=t1232
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/$TASK-japan-open-kansen.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{
  echo "# ジャパンオープン2026 の観戦の案内（$TASK・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **\`playwright-core\` がどちらにも無い。** ここで止める。" >> "$OUT"; cat "$OUT"; exit 0
fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** ここで止める。" >> "$OUT"; cat "$OUT"; exit 0
fi

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
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
for (const [key, u] of [['tokyo-shotai', 'https://t.co/31LRTHYf9u'], ['jaqua-ticket', 'https://t.co/C8gOxBalrj']]) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    const r = await p.evaluate(() => ({
      url: location.href,
      title: document.title,
      text: (document.querySelector('main') || document.body).innerText.replace(/\n{2,}/g, '\n').slice(0, 6000),
      links: [...document.querySelectorAll('a')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) })).filter((l) => /ジャパンオープン|チケット|ticket|申込|応募|招待|観戦/i.test(l.t + ' ' + l.h)).slice(0, 20),
    }));
    console.log(`\n## ${key}\n- 開いた: ${u}\n- 行き先: ${r.url}\n- 題名: ${r.title}\n\n\`\`\`text\n${r.text}\n\`\`\``);
    for (const l of r.links) console.log(`- ${l.t} — ${l.h}`);
  } catch (e) { console.log(`\n## ${key}\n- ⚠️ 開けない ${u}: ${String(e).slice(0, 160)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.$TASK-res.txt"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 150 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?（rc は証拠にならない。下の本文で見る）" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"
echo "出力の長さ: $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 16000 "$OUT"
