#!/bin/bash
# **J-TRIP の検索を 1 回だけ試す（t601・J-TRIP の先頭ツアーで「ホテルを選択する」を押し、選べる宿を読む・blog3）。読むだけ・予約しない・LLM 不使用・$0。**
#
# t593 で J-TRIP のトップに GET の検索フォーム（tour.jtrip.co.jp/tour40/）があると分かった。行き先（arrAirport）の選択肢は出発地を選ぶと入るので、
# 画面で出発地＝羽田を選んで選択肢を書き出し、札幌（新千歳）・2026-12-12 発・1 泊 2 日・2 名 1 室でフォームを送って、結果の値段の行と URL を読む。
# 全体で 200 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t601-jtrip-hotel-list.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# J-TRIP の検索を 1 回だけ試す（t601・**\$0**）"
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

SCRIPT="$RDIR/.t601-read.mjs"
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
  // J-TRIP の先頭ツアー（HN-388639）の 12/10・ツインで「ホテルを選択する」を押し、選べる宿と差額を読む。
  const det = 'https://tour.jtrip.co.jp/tour40/?pid=cal&tourID=HNHJA-388639-02&kID=KAKUHOK&type=TW&tpID=1&start=2026/12/10&count=1';
  await p.goto(det, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
  await p.waitForTimeout(7000);
  await p.locator('text=12/10(木)').first().click({ timeout: 5000 }).catch(e => console.log('12/10 を押せない: ' + String(e).slice(0, 80)));
  await p.waitForTimeout(7000);
  const pages0 = ctx.pages().length;
  await p.locator('text=ホテルを選択する').first().click({ timeout: 8000 }).catch(e => console.log('ホテルを選択するを押せない: ' + String(e).slice(0, 80)));
  await p.waitForTimeout(9000);
  const pg = ctx.pages().length > pages0 ? ctx.pages()[ctx.pages().length - 1] : p;
  await pg.waitForTimeout(2000);
  const res = await pg.evaluate(() => {
    const L = document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean);
    const i = L.findIndex(s => /ホテル選択|宿泊施設|ホテル一覧|件/.test(s));
    return { final: location.href, lines: L.slice(Math.max(0, i - 5), i + 220).join('\n') };
  });
  console.log('### 選べる宿（12/10・ツイン）\n\n最終: ' + res.final.slice(0, 200) + '\n\n```text\n' + res.lines + '\n```\n');
  if (pg !== p) await pg.close().catch(() => {});
} catch (e) { console.log(`⚠️ ${String(e).slice(0, 160)}\n`); }
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t601-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 170 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。予約はしない。" >> "$OUT"
cat "$OUT"
