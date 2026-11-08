#!/bin/bash
# **スーツケースの記事の「要確認」を読む（t581・blog3）。読むだけ・LLM 不使用・$0。**
#
# Xiaomi 公式（mi.com/jp）の購入ページは価格を JavaScript で読み込み、クラウドからは「0 円」しか見えない。
# RIMOWA は 403、無印良品は 503 で、affiliate の調査で全項目が「要確認」になった。
# Mac の Chrome で描画して、価格・寸法・重さの文字だけを書き出す。推測で埋めない（最上位ルール 20）。
# 1 ページ 6 秒待って本文から価格・寸法の行だけを拾う。全体で 280 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t581-suitcase-prices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# スーツケースの価格を公式で読む（t581・**\$0**）"
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

SCRIPT="$RDIR/.t581-read.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1300, height: 1600 });
const PAGES = [
  ['Xiaomi Classic Pro 購入', 'https://www.mi.com/jp/product/xiaomi-luggage-classic-pro/buy'],
  ['Xiaomi フロントポケット 20 購入', 'https://www.mi.com/jp/product/xiaomi-front-pocket-carry-on-luggage-20/buy'],
  ['Xiaomi エクスパンダブル 購入', 'https://www.mi.com/jp/product/xiaomi-expandable-luggage/buy'],
  ['Xiaomi アルミフレーム 購入', 'https://www.mi.com/jp/product/xiaomi-aluminum-frame-luggage/buy'],
  ['無印良品 ハードキャリーケース 36L', 'https://www.muji.com/jp/ja/store/cmdty/detail/4550723184250'],
  ['RIMOWA 機内持ち込み', 'https://www.rimowa.com/jp/ja/luggage/size/cabin/'],
  ['RIMOWA Essential Cabin', 'https://www.rimowa.com/jp/ja/luggage/colour/black/essential-cabin/83253634.html'],
  ['Xiaomi 公式 楽天市場店 スーツケース', 'https://search.rakuten.co.jp/search/mall/%E3%82%B9%E3%83%BC%E3%83%84%E3%82%B1%E3%83%BC%E3%82%B9/?sid=413034'],
];
for (const [name, url] of PAGES) {
  if (Date.now() - T0 > 230000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  console.log(`## ${name}\n\n${url}\n`);
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(6000);
    const st = r ? r.status() : '?';
    const info = await p.evaluate(() => {
      const t = document.body.innerText.replace(/[ \t]+/g, ' ');
      const lines = t.split('\n').map(s => s.trim()).filter(Boolean);
      const hit = lines.filter(s => /[¥￥]\s?[0-9,]{3,}|[0-9,]{4,}\s?円|税込|kg|容量|サイズ|インチ|Cabin|機内/.test(s)).slice(0, 60);
      return { title: document.title, final: location.href, hit };
    });
    console.log(`- HTTP ${st} ／ 題名: ${info.title} ／ 最終 URL: ${info.final}\n`);
    console.log('```text\n' + (info.hit.join('\n') || '（価格・寸法らしい行が 0 件）') + '\n```\n');
  } catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 140)}\n`); }
}
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t581-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 280 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
