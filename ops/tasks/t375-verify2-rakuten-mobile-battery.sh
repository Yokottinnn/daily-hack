#!/bin/bash
# **3 店ボタンを本番の記事で押して、着いた先とアフィリエイトの印を確かめ、写真を残す（t375・読むだけ・買わない）。**
# 2026-10-31 利用者「すべて、確実にそこからの購入で商品が購入できるかどうかを確認してその証跡も私に見せて」。記事: mobile-battery-comparison-2026・店: rakuten
# **2 回目: 検索結果の 1 件ずつに型番があるか（＝その商品がそこで買えるか）まで見る。** 1 回目は検索欄・見出しの文字で「あり」と出ていた。
# 本体は scripts/shop/verify-buttons.mjs（origin/main から取り出す）。写真は $OPS_REPORT_DIR/shop-verify/mobile-battery-comparison-2026/。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t375-verify2-rakuten.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# 3 店ボタンの確認（t375・mobile-battery-comparison-2026・rakuten・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
JS="$RDIR/.shop-verify2-buttons.mjs"; git -C "$REPO" show origin/main:scripts/shop/verify-buttons.mjs > "$JS"
SJ="$RDIR/.shop-mobile-battery.json"; git -C "$REPO" show origin/main:src/data/shop/mobile-battery.json > "$SJ"
[ -s "$JS" ] || { echo "⚠️ scripts/shop/verify-buttons.mjs が main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
( export SLUG="mobile-battery-comparison-2026" STORE="rakuten" SHOP_JSON="$SJ" OUT_SUFFIX="-v2" SHOT_PREFIX="v" OPS_REPORT_DIR="$RDIR" VERIFY_BUDGET_MS=170000; run_limited 200 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-verify/mobile-battery-comparison-2026/report-rakuten-v2.md" >> "$OUT" 2>/dev/null || echo "（report-rakuten-v2.md が無い）" >> "$OUT"
ls -la "$RDIR/shop-verify/mobile-battery-comparison-2026/" | grep "v.*rakuten" | head -20 >> "$OUT"
cat "$OUT"
