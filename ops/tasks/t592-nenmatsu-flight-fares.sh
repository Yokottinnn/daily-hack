#!/bin/bash
# **年末年始の航空券の記事の運賃を読む（t592・blog3）。読むだけ・買わない・LLM 不使用・$0。**
#
# 「いつ・どの日に飛ぶと安いか」を推測で書かないため、Google フライトの片道の検索結果を Mac の Chrome で描画して読む。
# 東京→札幌・福岡・沖縄の 3 路線で、年末の出発（12/27・12/29）、年始の戻り（1/3・逆向き）、混まない日（12/9・1/13）を比べる。
# 1 ページ 8 秒待って、航空会社名と「円」の行だけを拾う。全体で 270 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t592-wrap-prices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 年末年始の航空券の運賃を読む（t592・**\$0**）"
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

SCRIPT="$RDIR/.t592-read.mjs"
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
const R = [['東京', 'TYO', '札幌', 'CTS'], ['東京', 'TYO', '福岡', 'FUK'], ['東京', 'TYO', '沖縄', 'OKA']];
const PAGES = [];
for (const [fn, f, tn, t] of R) {
  for (const d of ['2026-12-27', '2026-12-29', '2026-12-09']) PAGES.push([`${fn}→${tn} ${d}`, f, t, d]);
  for (const d of ['2027-01-03', '2027-01-13']) PAGES.push([`${tn}→${fn} ${d}`, t, f, d]);
}
const AIR = /(日本航空|JAL|全日空|ANA|ピーチ|Peach|スカイマーク|Skymark|ジェットスター|Jetstar|スプリング|SPRING|ソラシド|AIRDO|エア・ドゥ|スターフライヤー|ZIPAIR)/;
for (const [name, f, t, d] of PAGES) {
  if (Date.now() - T0 > 240000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  const url = `https://www.google.com/travel/flights?q=${q(`Flights from ${f} to ${t} on ${d} one way`)}&hl=ja&gl=JP&curr=JPY`;
  console.log(`## ${name}\n\n${url}\n`);
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(8000);
    const info = await p.evaluate((src) => {
      const AIR = new RegExp(src);
      const lines = document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean);
      const out = [];
      for (let i = 0; i < lines.length && out.length < 14; i++) {
        if (AIR.test(lines[i])) out.push(lines.slice(Math.max(0, i - 3), i + 6).join(' ｜ ').slice(0, 300));
      }
      const yen = lines.filter(s => /[¥￥]\s?[0-9,]+|[0-9,]+\s?円/.test(s)).slice(0, 16);
      const hint = lines.filter(s => /(安い|高い|通常|価格の推移|最安)/.test(s)).slice(0, 6);
      return { title: document.title, out, yen, hint };
    }, AIR.source);
    console.log(`- HTTP ${r ? r.status() : '?'} ／ 題名: ${info.title.slice(0, 80)}\n`);
    console.log('```text\n' + (info.out.join('\n') || '（航空会社の行が 0 件）') + '\n--- 価格らしい行 ---\n' + info.yen.join('\n') + '\n--- 目安の行 ---\n' + info.hint.join('\n') + '\n```\n');
  } catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 140)}\n`); }
}
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t592-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 270 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。予約はしない。" >> "$OUT"
cat "$OUT"
