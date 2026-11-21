#!/bin/bash
# **カニ通販の記事の楽天の検索リンク 3 本（hgc）の行き先を確かめる（t743）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-20 利用者「ブログの進行中の記事をちゃんと進めて公開までしてね」。kani-tsuhan-kaitougo-tanka-2026 で楽天に同じ商品が見つからなかった 3 品は、楽天の検索結果へのリンクにした。成果リンクから開いて、検索結果に着いて商品が並ぶかを見る。Cookie の無いコンテキストで開く。


set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t743-kani-rakuten-search-links.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# カニ通販の楽天の検索リンクの行き先（t743・**\$0**）"
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

SCRIPT="$RDIR/.t743.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const AFF = '587f2635.77bb335f.587f2636.e34c8733';
const hgc = (u) => `https://hb.afl.rakuten.co.jp/hgc/${AFF}/?pc=${encodeURIComponent(u)}&m=${encodeURIComponent(u)}`;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
const L = [
  ['甲羅組 カット生ずわい', 'https://search.rakuten.co.jp/search/mall/' + encodeURIComponent('甲羅組 カット生ずわい蟹 特盛 1.8kg') + '/'],
  ['ますよね タラバ', 'https://search.rakuten.co.jp/search/mall/' + encodeURIComponent('ますよね タラバ 総重量1kg') + '/'],
  ['森源 ずわいポーション', 'https://search.rakuten.co.jp/search/mall/' + encodeURIComponent('森源商店 ずわい蟹 ポーション 1kg') + '/'],
];
for (const [k, u] of L) {
  try {
    await p.goto(hgc(u), { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3000);
    const items = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href*="item.rakuten.co.jp/"]')].map((a) => (a.innerText || '').replace(/\s+/g, ' ').trim()).filter((t) => t.length > 15))].slice(0, 3));
    console.log(`- ${k}: 着いた先 **${p.url().split('?')[0]}** 「${(await p.title()).slice(0, 60)}」 商品 ${items.length} 件`);
    for (const t of items) console.log(`  - ${t.slice(0, 90)}`);
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0, 120)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t743-res.txt"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 120 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 6000 "$OUT"
