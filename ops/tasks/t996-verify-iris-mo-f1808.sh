#!/bin/bash
# **オーブンレンジ比較記事で替えたアイリス MO-F1808-B の 3 店ボタン（楽天・Yahoo!・Amazon）を本番の記事で押して、着いた先とアフィリエイトの印を確かめる（t996・読むだけ・買わない）。**
# 2026-11-22 利用者がダイアログで「オーブンレンジのアイリスを売っている機種に替える」を選んだ。PR #1974 で MS-F3002-B から MO-F1808-B に替えた。記事: oven-range-comparison-2026
# 本体は scripts/shop/verify-buttons.mjs（origin/main から取り出す・MATCH=MO-F1808 で替えた機種のボタンだけ）。写真は Mac の手元（private-shots）だけ。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t996-verify-iris-mo-f1808.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
SLUG="oven-range-comparison-2026"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# 3 店ボタンの確認（t996・$SLUG・MO-F1808-B・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
# 本番に新しい版（MO-F1808-B の入った記事）が出るまで最大 60 秒待つ
for i in $(seq 1 6); do
  n=$(curl -s --max-time 10 "https://daily-hack.fieldbeside.com/posts/$SLUG/" | grep -c "MO-F1808" | head -1)
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  [ "$n" -gt 0 ] && break; sleep 10
done
echo "- 本番の記事に MO-F1808 の行: $n" >> "$OUT"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
JS="$RDIR/.shop-verify-t996.mjs"; git -C "$REPO" show origin/main:scripts/shop/verify-buttons.mjs > "$JS"
SJ="$RDIR/.shop-oven-range-t996.json"; git -C "$REPO" show origin/main:src/data/shop/oven-range.json > "$SJ"
[ -s "$JS" ] && [ -s "$SJ" ] || { echo "⚠️ スクリプトかデータが main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
for ST in rakuten yahoo amazon; do
  ( export SLUG="$SLUG" STORE="$ST" MATCH="MO-F1808" SHOP_JSON="$SJ" OUT_SUFFIX="-t996" SHOT_PREFIX="t996-" OPS_REPORT_DIR="$RDIR" VERIFY_BUDGET_MS=60000; run_limited 80 "$NODE_BIN" "$JS" ) > /dev/null 2>&1
  echo "- $ST rc=$?" >> "$OUT"
  cat "$RDIR/shop-verify/$SLUG/report-$ST-retry-t996.md" >> "$OUT" 2>/dev/null || echo "（report-$ST-retry-t996.md が無い）" >> "$OUT"
  echo "" >> "$OUT"
done
cat "$OUT"
