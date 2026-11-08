#!/bin/bash
# **肌着の記事の「要確認」を読む（t590・blog3）。読むだけ・買わない・LLM 不使用・$0。**
#
# グンゼ公式（楽天市場のグンゼ公式通販）の快適工房 KW3008 の商品画像と洗濯表示、トップバリュ PEACE FIT WARM・無印良品のあったか綿の
# 素材・価格・洗濯表示は、クラウドから開けなかった。Mac の Chrome で描画して、本文の行と画像の URL を書き出す。推測で埋めない（最上位ルール 20）。
# 全体で 260 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t590-inner-official-pages.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 肌着の公式ページを読む（t590・**\$0**）"
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

SCRIPT="$RDIR/.t590-read.mjs"
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
  ['グンゼ公式（楽天）快適工房 KW3008', 'https://item.rakuten.co.jp/gunze/kw3008/'],
  ['トップバリュ PEACE FIT 検索', `https://www.topvalu.net/search/?q=${q('ピースフィット ウォーム メンズ 長袖')}`],
  ['イオンスタイル PEACE FIT WARM', `https://www.aeonnetshop.com/shop/goods/search.aspx?keyword=${q('ピースフィット ウォーム 長袖 メンズ')}`],
  ['無印良品 あったか綿', 'https://www.muji.com/jp/ja/store/cmdty/detail/4547315446605'],
  ['無印良品 あったか綿 検索', `https://www.muji.com/jp/ja/store/search?q=${q('あったか綿 長袖 紳士')}`],
];
for (const [name, url] of PAGES) {
  if (Date.now() - T0 > 220000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  console.log(`## ${name}\n\n${url}\n`);
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(6000);
    const info = await p.evaluate(() => {
      const lines = document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean);
      const hit = lines.filter(s => /綿|ポリエステル|アクリル|レーヨン|ポリウレタン|素材|組成|洗濯|手洗|乾燥|税込|円|サイズ/.test(s)).slice(0, 50);
      const imgs = [...document.images].map(i => i.currentSrc || i.src).filter(u => /\.(jpe?g|png|webp)/i.test(u) && !/logo|icon|banner|bnr/i.test(u)).filter((u, i, a) => a.indexOf(u) === i).slice(0, 10);
      const og = document.querySelector('meta[property="og:image"]')?.content || '';
      return { title: document.title, final: location.href, hit, imgs, og };
    });
    console.log(`- HTTP ${r ? r.status() : '?'} ／ 題名: ${info.title} ／ 最終 URL: ${info.final.slice(0, 140)}\n- og:image: ${info.og}\n`);
    console.log('```text\n' + (info.hit.join('\n') || '（素材・価格らしい行が 0 件）') + '\n--- 画像 ---\n' + info.imgs.join('\n') + '\n```\n');
  } catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 140)}\n`); }
}
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t590-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 260 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。買い物はしない。" >> "$OUT"
cat "$OUT"
