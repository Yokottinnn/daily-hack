#!/bin/bash
# **卓上食洗機の比較記事（countertop-dishwasher-comparison-2026）の 3 店ボタンの Amazon を商品ページ（ASIN）へ直接飛ばすため、候補を集める（t972・読むだけ・買わない）。**
# 2026-11-22 利用者「商品の比較記事を増やして」。型番検索だと先頭に付属品が出るので、題名に型番が入る ASIN を拾う。問い合わせは ops/data/shop/find-pages-dishwasher.json。
# 本体は scripts/shop/find-product-pages.mjs（origin/main から取り出す・写真は Mac の手元の private-shots にだけ置く）。
# 本体は scripts/shop/find-product-pages.mjs（origin/main から取り出す）。シリーズ: dishwasher
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t972-find-pages-dishwasher.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# 商品ページの候補（t972・dishwasher・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
SJ="$RDIR/.shop-rechargeable-kairo.json"; git -C "$REPO" show origin/main:src/data/shop/rechargeable-kairo.json > "$SJ"
QJ="$RDIR/.shop-find-pages-dishwasher.json"; git -C "$REPO" show origin/main:ops/data/shop/find-pages-dishwasher.json > "$QJ"
[ -s "$JS" ] && [ -s "$SJ" ] || { echo "⚠️ スクリプトかデータが main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
( export SERIES="dishwasher" SHOP_JSON="$SJ" QUERIES="$QJ" OPS_REPORT_DIR="$RDIR" FIND_BUDGET_MS=230000; run_limited 270 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-pages/dishwasher/report.md" >> "$OUT" 2>/dev/null || echo "（report.md が無い）" >> "$OUT"
cat "$OUT"
