#!/bin/bash
# **ポータブル電源の記事の素材を読む（t605・blog3）。読むだけ・買わない・LLM 不使用・$0。**
#
# BLUETTI 公式（bluettipower.jp）と、消費者庁のリコール情報サイト・経済産業省の製品安全のリコール一覧は、クラウドから開けなかった。Mac の Chrome で描画して、本文の行と画像の URL を書き出す。推測で埋めない（最上位ルール 20）。
# 全体で 260 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t605-inner-official-pages.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ポータブル電源の公式ページとリコールを読む（t605・**\$0**）"
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

SCRIPT="$RDIR/.t605-read.mjs"
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
  ['BLUETTI Elite 100 V2', 'https://www.bluettipower.jp/products/elite-100-v2'],
  ['BLUETTI 製品一覧', 'https://www.bluettipower.jp/collections/all'],
  ['消費者庁 リコール ポータブル電源', `https://www.recall.caa.go.jp/result/index.php?search_type=free&keyword=${q('ポータブル電源')}`],
  ['経済産業省 製品安全 リコール一覧', 'https://www.meti.go.jp/product_safety/recall/index.html'],
  ['NITE リコール情報', `https://www.nite.go.jp/jiko/chuikanki/recall/index.html`],
];
for (const [name, url] of PAGES) {
  if (Date.now() - T0 > 220000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  console.log(`## ${name}\n\n${url}\n`);
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(6000);
    const info = await p.evaluate(() => {
      const lines = document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean);
      const hit = lines.filter(s => /ポータブル電源|Wh|定格|出力|リン酸|LFP|サイクル|回|重量|kg|税込|円|型番|Jackery|EcoFlow|エコフロー|Anker|アンカー|BLUETTI|ブルーティ|DJI|発火|回収|リコール|交換/.test(s)).slice(0, 80);
      const imgs = [...document.images].map(i => i.currentSrc || i.src).filter(u => /\.(jpe?g|png|webp)/i.test(u) && !/logo|icon|banner|bnr/i.test(u)).filter((u, i, a) => a.indexOf(u) === i).slice(0, 10);
      const og = document.querySelector('meta[property="og:image"]')?.content || '';
      return { title: document.title, final: location.href, hit, imgs, og };
    });
    console.log(`- HTTP ${r ? r.status() : '?'} ／ 題名: ${info.title} ／ 最終 URL: ${info.final.slice(0, 140)}\n- og:image: ${info.og}\n`);
    console.log('```text\n' + (info.hit.join('\n') || '（それらしい行が 0 件）') + '\n--- 画像 ---\n' + info.imgs.join('\n') + '\n```\n');
  } catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 140)}\n`); }
}
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t605-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 260 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。買い物はしない。" >> "$OUT"
cat "$OUT"
