#!/bin/bash
# **ラップの記事の「要確認」を読む（t584・blog3）。読むだけ・買わない・LLM 不使用・$0。**
#
# クレラップ・サランラップは公式に希望小売価格が無く、1m あたりの値段が出せない。
# 通販（楽天・Amazon・LOHACO）のその日の価格を Mac の Chrome で描画して読み、記事には「○月○日の通販価格」と書く。
# ニトリの 2 品の価格が税込かどうかも画面の表示で確かめる。推測で埋めない（最上位ルール 20）。
# 1 ページ 6 秒待って本文から価格の行だけを拾う。全体で 260 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t584-wrap-prices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ラップの通販価格を読む（t584・**\$0**）"
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

SCRIPT="$RDIR/.t584-read.mjs"
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
  ['楽天 NEWクレラップ 30cm×50m', `https://search.rakuten.co.jp/search/mall/${q('NEWクレラップ 30cm 50m')}/`],
  ['楽天 サランラップ 30cm×50m', `https://search.rakuten.co.jp/search/mall/${q('サランラップ 30cm 50m')}/`],
  ['Amazon NEWクレラップ 30cm×50m', `https://www.amazon.co.jp/s?k=${q('NEWクレラップ 30cm×50m')}`],
  ['Amazon サランラップ 30cm×50m', `https://www.amazon.co.jp/s?k=${q('サランラップ 30cm×50m')}`],
  ['LOHACO クレラップ', `https://lohaco.yahoo.co.jp/search/?searchWord=${q('クレラップ 30cm 50m')}`],
  ['LOHACO サランラップ', `https://lohaco.yahoo.co.jp/search/?searchWord=${q('サランラップ 30cm 50m')}`],
  ['ニトリ 耐熱ラップECO', 'https://www.nitori-net.jp/ec/product/2111200006308/'],
  ['ニトリ 島忠フードラップ', 'https://www.nitori-net.jp/ec/product/4850379s/'],
];
for (const [name, url] of PAGES) {
  if (Date.now() - T0 > 220000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  console.log(`## ${name}\n\n${url}\n`);
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(6000);
    const info = await p.evaluate(() => {
      const lines = document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean);
      const out = [];
      for (let i = 0; i < lines.length && out.length < 40; i++) {
        if (/(クレラップ|サランラップ|ラップ)/.test(lines[i]) && /30\s*cm|30cm|×\s*50|50\s*m/.test(lines[i])) {
          out.push(lines.slice(i, i + 6).join(' ｜ ').slice(0, 260));
        }
      }
      const tax = lines.filter(s => /税込|税抜|円/.test(s)).slice(0, 12);
      return { title: document.title, final: location.href, out, tax };
    });
    console.log(`- HTTP ${r ? r.status() : '?'} ／ 題名: ${info.title} ／ 最終 URL: ${info.final.slice(0, 120)}\n`);
    console.log('```text\n' + (info.out.join('\n') || '（商品名と大きさの行が 0 件）') + '\n--- 価格らしい行 ---\n' + info.tax.join('\n') + '\n```\n');
  } catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 140)}\n`); }
}
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t584-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 260 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。買い物はしない。" >> "$OUT"
cat "$OUT"
