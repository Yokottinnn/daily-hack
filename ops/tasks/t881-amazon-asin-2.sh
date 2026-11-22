#!/bin/bash
# **3 店ボタンの Amazon を検索リンクから商品ページ（ASIN）へ直すため、Amazon の検索結果から候補の ASIN を拾う（t881・読むだけ・買わない・カートに入れない）。**
# 2026-11-22 利用者がダイアログで「Amazon は商品ページに直接飛ばす」を選んだ。型番の検索だと先頭に付属品（フィルター・保護フィルムなど）が出る機種があった。
# 対象は 2026-11-22 公開の比較記事 8 本（＋替えブラシ）の 67 機種を 6 つに分けた 2 番目（ops/data/shop/amazon-asin-2.json）。
# 本体は scripts/shop/find-product-pages.mjs（origin/main から取り出す）。出すのは ASIN・題名・価格・広告枠かどうかだけ。写真は Mac の手元（private-shots）にだけ置く。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t881-amazon-asin-2.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# Amazon の ASIN の候補（t881・amz2・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
SJ="$RDIR/.shop-amz2-base.json"; git -C "$REPO" show origin/main:src/data/shop/smartwatch.json > "$SJ"
QJ="$RDIR/.shop-amazon-asin-2.json"; git -C "$REPO" show origin/main:ops/data/shop/amazon-asin-2.json > "$QJ"
[ -s "$JS" ] && [ -s "$SJ" ] && [ -s "$QJ" ] || { echo "⚠️ スクリプトかデータが main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
( export SERIES="amz2" SHOP_JSON="$SJ" QUERIES="$QJ" OPS_REPORT_DIR="$RDIR" FIND_BUDGET_MS=220000; run_limited 260 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-pages/amz2/report.md" >> "$OUT" 2>/dev/null || echo "（report.md が無い）" >> "$OUT"
cat "$OUT"
