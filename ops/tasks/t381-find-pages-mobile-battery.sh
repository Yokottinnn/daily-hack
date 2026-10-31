#!/bin/bash
# **3 店ボタンの Amazon・楽天を商品ページへ直接飛ばすため、商品ページの候補（ASIN・楽天の商品 URL）を集める（t381・読むだけ・買わない）。**
# 2026-10-31 利用者がダイアログで「商品ページへ直接飛ばす」を選んだ。検索ページに飛ばすと別の商品しか出ないものがあった（t363・t369 の写真）。
# 本体は scripts/shop/find-product-pages.mjs（origin/main から取り出す）。シリーズ: mobile-battery
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t381-find-pages-mobile-battery.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# 商品ページの候補（t381・mobile-battery・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
SJ="$RDIR/.shop-mobile-battery.json"; git -C "$REPO" show origin/main:src/data/shop/mobile-battery.json > "$SJ"
[ -s "$JS" ] && [ -s "$SJ" ] || { echo "⚠️ スクリプトかデータが main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
( export SERIES="mobile-battery" SHOP_JSON="$SJ" OPS_REPORT_DIR="$RDIR" FIND_BUDGET_MS=230000; run_limited 270 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-pages/mobile-battery/report.md" >> "$OUT" 2>/dev/null || echo "（report.md が無い）" >> "$OUT"
cat "$OUT"
