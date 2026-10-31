#!/bin/bash
# **3 店ボタンを本番の記事で押して、着いた先とアフィリエイトの印を確かめ、写真を残す（t386・読むだけ・買わない）。**
# 2026-10-31 利用者「すべて、確実にそこからの購入で商品が購入できるかどうかを確認してその証跡も私に見せて」。記事: mobile-battery-comparison-2026・店: amazon
# **3 回目: 商品ページへ張り替えたあと（PR #1278 ほか）。着いた先が型番の商品ページで、購入ボタンがあるかを見る。**
# 本体は scripts/shop/verify-buttons.mjs（origin/main から取り出す）。写真は $OPS_REPORT_DIR/shop-verify/mobile-battery-comparison-2026/。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t386-verify3-amazon.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# 3 店ボタンの確認（t386・mobile-battery-comparison-2026・amazon・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
JS="$RDIR/.shop-verify3-buttons.mjs"; git -C "$REPO" show origin/main:scripts/shop/verify-buttons.mjs > "$JS"
SJ="$RDIR/.shop-mobile-battery.json"; git -C "$REPO" show origin/main:src/data/shop/mobile-battery.json > "$SJ"
[ -s "$JS" ] || { echo "⚠️ scripts/shop/verify-buttons.mjs が main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
# 本番に張り替えが出るまで待つ（main に入ってから Cloudflare の公開まで 5 分ほどかかる・最大 240 秒）
for i in $(seq 1 24); do curl -s -m 15 "https://daily-hack.fieldbeside.com/posts/mobile-battery-comparison-2026/" | grep -q "B0H1G5LYR8" && { echo "- 本番に張り替えが出た（$((i*10)) 秒以内）" >> "$OUT"; break; }; sleep 10; done
( export SLUG="mobile-battery-comparison-2026" STORE="amazon" SHOP_JSON="$SJ" OUT_SUFFIX="-v3" SHOT_PREFIX="w" OPS_REPORT_DIR="$RDIR" VERIFY_BUDGET_MS=170000; run_limited 200 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-verify/mobile-battery-comparison-2026/report-amazon-v3.md" >> "$OUT" 2>/dev/null || echo "（report-amazon-v3.md が無い）" >> "$OUT"
ls -la "$RDIR/shop-verify/mobile-battery-comparison-2026/" | grep "w.*amazon" | head -20 >> "$OUT"
cat "$OUT"
