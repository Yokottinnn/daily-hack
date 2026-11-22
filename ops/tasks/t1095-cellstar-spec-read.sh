#!/bin/bash
# **ドライブレコーダーの比較記事の材料: セルスター CS-N210 の「仕様」タブ（付属品・電源・画角）と発表のお知らせを読む（t1095）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# t1093 の innerText には隠れたタブ（仕様）が出なかったので、タブを押して読み、textContent も取る。Cookie の無い新しいコンテキスト。200 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1095-dashcam-official.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ドライブレコーダー セルスター CS-N210 の仕様の公式ページ（t1095・**\$0**）"
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

# ── 描画して読む ──────────────────────────────────────────
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
D="$RDIR/t1095"; rm -rf "$D"; mkdir -p "$D/img"
SCRIPT="$RDIR/.t1095.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
// 1) CS-N210 の「仕様」「設定一覧」タブ（隠れているタブは innerText に出ないので textContent も取る）
try {
  await p.goto('https://www.cellstar.co.jp/products/recorder/cs/cs-n210.html', { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(3000);
  for (const label of ['仕様', '設定一覧', 'ご購入前に']) {
    const clicked = await p.evaluate((label) => { for (const el of document.querySelectorAll('a,button,li,[role=tab]')) { if ((el.innerText || '').trim() === label) { el.click(); return true; } } return false; }, label);
    await p.waitForTimeout(1500);
    const txt = await p.evaluate(() => document.body.innerText);
    fs.writeFileSync(`${D}/cellstar-csn210-${label}.txt`, txt.slice(0, 60000));
    console.log(`- 「${label}」 押した: ${clicked} / 本文 ${txt.length} 文字`);
  }
  const all = await p.evaluate(() => { const m = document.querySelector('main') || document.body; return m.textContent.replace(/[ \t]+/g, ' ').replace(/\n\s*\n+/g, '\n'); });
  fs.writeFileSync(`${D}/cellstar-csn210-textContent.txt`, all.slice(0, 120000));
  console.log(`- textContent ${all.length} 文字`);
  const lines = all.split('\n').filter((l) => /付属|電源|コード|画角|画素|発売|水平|垂直|対角|シガー|消費/.test(l)).slice(0, 60);
  console.log('\n```text\n' + lines.join('\n').slice(0, 6000) + '\n```');
} catch (e) { console.log(`- ⚠️ CS-N210: ${String(e).slice(0, 140)}`); }
// 2) セルスターのお知らせから CS-N210 の発表を探す（発売日）
try {
  await p.goto('https://www.cellstar.co.jp/', { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(2500);
  const news = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim() })).filter((x) => /N210|新製品|ニュース|news|release/i.test(x.t + x.h)).slice(0, 30));
  console.log('\n- トップのお知らせ・新製品のリンク'); for (const n of news) console.log(`  - ${n.t.slice(0, 80)} — ${n.h}`);
  const hit = news.find((x) => /N210/.test(x.t + x.h));
  if (hit) {
    await p.goto(hit.h, { waitUntil: 'domcontentloaded', timeout: 25000 }); await p.waitForTimeout(2500);
    const t = await p.evaluate(() => document.body.innerText);
    fs.writeFileSync(`${D}/cellstar-news-n210.txt`, `URL: ${p.url()}\n\n` + t.slice(0, 30000));
    console.log(`- 開いた: ${p.url()}（${t.length} 文字）`);
  }
} catch (e) { console.log(`- ⚠️ お知らせ: ${String(e).slice(0, 140)}`); }
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
JS
RES="$RDIR/.t1095-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; ls -la "$D" | awk '{print $5, $9}' >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 15000 "$OUT"
