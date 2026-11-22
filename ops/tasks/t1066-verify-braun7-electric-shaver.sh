#!/bin/bash
# **3 店ボタンを本番の記事で押して、着いた先とアフィリエイトの印を確かめ、写真を残す（t1066・読むだけ・買わない）。**
# 2026-11-22 blog3 が公開した記事の 3 店ボタン（electric-shaver・shaver-blade）が、型番の商品に着くかを確かめる（作ったリンクは遷移先を確かめる）。記事: electric-shaver-comparison-2026・店: 70-N1200s の検索語を「ブラウン 70-N1200s」に直したあとの楽天・Yahoo!
# 本体は scripts/shop/verify-buttons.mjs（origin/main から取り出す）。写真は $OPS_REPORT_DIR/shop-verify/electric-shaver-comparison-2026/。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1066-verify-rakuten.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# 3 店ボタンの確認（t1066・electric-shaver-comparison-2026・70-N1200s の楽天と Yahoo!・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
# 新しい検索語（ブラウン 70-N1200s）が本番に出るまで待つ（古い版を確かめないため）
for i in $(seq 1 22); do c=$(curl -s --max-time 10 "https://daily-hack.fieldbeside.com/posts/electric-shaver-comparison-2026/" | grep -c 'p=%E3%83%96%E3%83%A9%E3%82%A6%E3%83%B3%2070-N1200s' | head -1); [ "${c:-0}" != "0" ] && { c="200（新しい検索語あり）"; break; }; c="新しい検索語がまだ無い"; sleep 10;done
echo "- 本番の記事: HTTP $c" >> "$OUT"
JS="$RDIR/.shop-verify2-buttons.mjs"; git -C "$REPO" show origin/main:scripts/shop/verify-buttons.mjs > "$JS"
SJ="$RDIR/.shop-electric-shaver.json"; git -C "$REPO" show origin/main:src/data/shop/electric-shaver.json > "$SJ"; SJ2="$RDIR/.shop-shaver-blade.json"; git -C "$REPO" show origin/main:src/data/shop/shaver-blade.json > "$SJ2"
[ -s "$JS" ] || { echo "⚠️ scripts/shop/verify-buttons.mjs が main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
( export SLUG="electric-shaver-comparison-2026" STORE="" MATCH="70-N1200s" SHOP_JSON="$SJ,$SJ2" OUT_SUFFIX="-v2" SHOT_PREFIX="v" OPS_REPORT_DIR="$RDIR" VERIFY_BUDGET_MS=60000; run_limited 80 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-verify/electric-shaver-comparison-2026/report-retry-v2.md" >> "$OUT" 2>/dev/null || echo "（report-retry-v2.md が無い）" >> "$OUT"
ls -la "$RDIR/shop-verify/electric-shaver-comparison-2026/" | grep "v" | head -20 >> "$OUT"
cat "$OUT"
