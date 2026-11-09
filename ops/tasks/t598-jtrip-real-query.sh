#!/bin/bash
# **J-TRIP の検索を 1 回だけ試す（t598・t597 でフォームが作った中身そのままで開く。ボタンの押下では画面が移らなかった・blog3）。読むだけ・予約しない・LLM 不使用・$0。**
#
# t593 で J-TRIP のトップに GET の検索フォーム（tour.jtrip.co.jp/tour40/）があると分かった。行き先（arrAirport）の選択肢は出発地を選ぶと入るので、
# 画面で出発地＝羽田を選んで選択肢を書き出し、札幌（新千歳）・2026-12-12 発・1 泊 2 日・2 名 1 室でフォームを送って、結果の値段の行と URL を読む。
# 全体で 200 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t598-jtrip-real-query.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# J-TRIP の検索を 1 回だけ試す（t598・**\$0**）"
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

SCRIPT="$RDIR/.t598-read.mjs"
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
  // t597 で画面のフォームが実際に作った中身（FormData）をそのまま使う。項目は type・kID が行き先ごとに違う。
  const QS = [
    ['札幌・2名1室', 'depAirport=GHND&arrAirport=CTS&date=2026-12-10&year=2026&month=12&day=10&days=2&type=2&dec=1&pid=ts&icon1=6&kID=KAKUHOK'],
    ['札幌・1名1室', 'depAirport=GHND&arrAirport=CTS&date=2026-12-10&year=2026&month=12&day=10&days=2&type=1&dec=1&pid=ts&icon1=6&kID=KAKUHOK'],
    ['沖縄・2名1室', 'depAirport=GHND&arrAirport=OKA&date=2026-12-10&year=2026&month=12&day=10&days=2&type=2&dec=1&pid=ts&icon1=6&kID=KAKUOKI'],
  ];
  for (const [label, qs] of QS) {
    const url = 'https://tour.jtrip.co.jp/tour40/?' + qs;
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(e => { console.log('開けない: ' + String(e).slice(0, 100)); return null; });
    await p.waitForTimeout(9000);
    const info = await p.evaluate(() => {
      const L = document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean);
      return { title: document.title, final: location.href, yen: L.filter(s => /[0-9,]+\s?円/.test(s)).slice(0, 30), head: L.slice(0, 30), items: L.filter(s => /ホテル|旅館|イン|泊/.test(s)).slice(0, 15) };
    });
    console.log(`### ${label}\n\n- URL: ${url}\n- HTTP ${r ? r.status() : '?'} ／ 題名: ${info.title.slice(0, 60)} ／ 最終: ${info.final.slice(0, 200)}\n`);
    console.log('```text\n--- 値段の行 ---\n' + info.yen.join('\n') + '\n--- 宿らしい行 ---\n' + info.items.join('\n') + '\n--- 先頭 ---\n' + info.head.join('\n') + '\n```\n');
    if (Date.now() - T0 > 120000) { console.log('（時間切れで打ち切り）'); break; }
  }
} catch (e) { console.log(`⚠️ ${String(e).slice(0, 160)}\n`); }
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t598-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 170 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。予約はしない。" >> "$OUT"
cat "$OUT"
