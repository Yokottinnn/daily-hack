#!/bin/bash
# **3 店ボタンの Amazon・楽天を商品ページへ直接飛ばすため、商品ページの候補（ASIN・楽天の商品 URL）を集める（t1191・読むだけ・買わない）。**
# 2026-11-22 blog3 の drum-washer-dryer-comparison-2026。Amazon は最初から商品ページ（ASIN）へ飛ばす（型番検索だと先頭に付属品が出る）。写真は Mac の手元（private-shots）だけに置く。
# 本体は scripts/shop/find-product-pages.mjs（origin/main から取り出す）。シリーズ: drum-washer-dryer
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1191-find-pages-drum-washer-dryer.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# 商品ページの候補（t1191・drum-washer-dryer・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
[ -n "$NODE_BIN" ] || { echo "⚠️ node が無い" >> "$OUT"; cat "$OUT"; exit 0; }
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
git -C "$REPO" fetch -q origin main 2>/dev/null || true
JS="$RDIR/.shop-find-pages.mjs"; git -C "$REPO" show origin/main:scripts/shop/find-product-pages.mjs > "$JS"
SJ="$RDIR/.shop-drum-washer-dryer.json"; git -C "$REPO" show origin/main:ops/data/shop-find/drum-washer-dryer.json > "$SJ"
[ -s "$JS" ] && [ -s "$SJ" ] || { echo "⚠️ スクリプトかデータが main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
( export SERIES="drum-washer-dryer" SHOP_JSON="$SJ" OPS_REPORT_DIR="$RDIR" FIND_BUDGET_MS=230000; run_limited 270 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-pages/drum-washer-dryer/report.md" >> "$OUT" 2>/dev/null || echo "（report.md が無い）" >> "$OUT"
cat "$OUT"
