#!/bin/bash
# **J-TRIP の検索を 1 回だけ試す（t596・t594 の出し直し。11/9 23:59 は Chrome が未起動だった・blog3）。読むだけ・予約しない・LLM 不使用・$0。**
#
# t593 で J-TRIP のトップに GET の検索フォーム（tour.jtrip.co.jp/tour40/）があると分かった。行き先（arrAirport）の選択肢は出発地を選ぶと入るので、
# 画面で出発地＝羽田を選んで選択肢を書き出し、札幌（新千歳）・2026-12-12 発・1 泊 2 日・2 名 1 室でフォームを送って、結果の値段の行と URL を読む。
# 全体で 200 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t596-jtrip-search-retry.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# J-TRIP の検索を 1 回だけ試す（t596・**\$0**）"
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

SCRIPT="$RDIR/.t594-read.mjs"
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
console.log('## J-TRIP 検索\n');
try {
  await p.goto('https://www.jtrip.co.jp/', { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(5000);
  await p.selectOption('select[name=depAirport]', 'GHND').catch(e => console.log('出発地を選べない: ' + String(e).slice(0, 100)));
  await p.waitForTimeout(3000);
  const arr = await p.evaluate(() => [...document.querySelectorAll('select[name=arrAirport] option')].map(o => o.value + '=' + o.textContent.trim()).slice(0, 80));
  console.log('```text\n行き先の選択肢（' + arr.length + ' 件）\n' + arr.join('\n') + '\n```\n');
  const rt = await p.evaluate(() => [...document.querySelectorAll('select[name=rtype] option')].map(o => o.value + '=' + o.textContent.trim()));
  console.log('```text\n部屋の選択肢\n' + rt.join('\n') + '\n```\n');
  const cts = arr.find(x => /札幌|新千歳/.test(x));
  if (cts) {
    const code = cts.split('=')[0];
    const url = `https://tour.jtrip.co.jp/tour40/?depAirport=GHND&arrAirport=${encodeURIComponent(code)}&date=2026-12-12&year=2026&month=12&day=12&days=2&rtype=2&dec=1&pid=ts&icon1=6&kID=JTRIPKAK`;
    console.log('結果の URL: ' + url + '\n');
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(8000);
    const info = await p.evaluate(() => {
      const L = document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean);
      return { title: document.title, final: location.href, yen: L.filter(s => /[0-9,]+\s?円/.test(s)).slice(0, 30), head: L.slice(0, 40) };
    });
    console.log(`- HTTP ${r ? r.status() : '?'} ／ 題名: ${info.title.slice(0, 80)} ／ 最終: ${info.final.slice(0, 160)}\n`);
    console.log('```text\n--- 値段の行 ---\n' + info.yen.join('\n') + '\n--- 先頭 ---\n' + info.head.join('\n') + '\n```\n');
  } else console.log('札幌の行き先が見つからない\n');
} catch (e) { console.log(`⚠️ ${String(e).slice(0, 160)}\n`); }
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t594-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 150 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。予約はしない。" >> "$OUT"
cat "$OUT"
