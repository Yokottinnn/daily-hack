#!/bin/bash
# **駅の乗降客数の公式ページを Chrome で読む（t623・blog3）。読むだけ・LLM 不使用・$0。**
#
# 2026-11-14 利用者がダイアログで「駅の乗降客数を Mac で確かめる」を選んだ。t622 は curl で JR東日本・東京メトロとも 403。
# Mac の Chrome で描画して、表の行（駅名と数字）とリンクを書き出す。推測で埋めない（最上位ルール 20）。
# 全体で 260 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t623-station-ridership-chrome.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 駅の乗降客数の公式ページを読む（t623・**\$0**）"
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
    echo "⚠️ **\`playwright-core\` がどちらにも無い。**"
    echo ""
    echo '```text'
    ls -d "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules" 2>&1
    echo '```'
    echo ""
    echo "**ここで止める。** 推測で埋めない（最上位ルール 20）。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: **\`$PWDIR\`** に在る" >> "$OUT"

# ── Chrome が CDP で上がっているか（**ポートの LISTEN では足りない**・ルール 13） ──
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  {
    echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** 新しく起動はしない（t174 と同じ）"
    echo ""
    echo "**ここで止める。** Chrome が戻ってから同じものを出し直す。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"
echo "" >> "$OUT"

# ── 描画して読む ──
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

SCRIPT="$RDIR/.t623-read.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1300, height: 1600 });
const q = (s) => encodeURIComponent(s);
const PAGES = [
  ['JR東日本 各駅の乗車人員', 'https://www.jreast.co.jp/passenger/'],
  ['東京メトロ 各駅の乗降人員ランキング', 'https://www.tokyometro.jp/corporate/enterprise/passenger_rail/transportation/passengers/index.html'],
];
for (const [name, url] of PAGES) {
  if (Date.now() - T0 > 220000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  console.log(`## ${name}\n\n${url}\n`);
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(6000);
    const info = await p.evaluate(() => {
      const rows = [...document.querySelectorAll('tr')].map(tr => tr.innerText.replace(/\s+/g, ' ').trim()).filter(t => /[0-9][0-9,]{3,}/.test(t)).slice(0, 140);
      const links = [...document.querySelectorAll('a')].map(a => (a.innerText.trim() + ' -> ' + a.href)).filter(t => /乗車人員|乗降人員|年度|ランキング|\.pdf/i.test(t)).slice(0, 30);
      const head = document.body.innerText.split('\n').map(s => s.trim()).filter(s => /年度|集計|定期|乗車人員|乗降人員/.test(s)).slice(0, 15);
      return { title: document.title, final: location.href, hit: head.concat(['--- 表 ---'], rows, ['--- リンク ---'], links), imgs: [], og: '' };
    });
    console.log(`- HTTP ${r ? r.status() : '?'} ／ 題名: ${info.title} ／ 最終 URL: ${info.final.slice(0, 140)}\n`);
console.log('```text\n' + (info.hit.join('\n') || '（行が 0 件）') + '\n```\n');
  } catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 140)}\n`); }
}
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t623-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 260 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
