#!/bin/bash
# **VC にアソビュー・じゃらん遊び体験・さとふるを 1 件ずつ申請する（applyvc5・t618 の一括提携の方法はボタンが出なかったので、t549 で通った方法で）（t619）。** 2026-11-14 利用者がダイアログで選んだ。LLM 不使用・**$0**。
# 費用の語がある確認・ボタンが決まらないときは押さない（applyvc5 の決まり）。
# 上限 60+48×4 秒（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t619-vc-apply-one-by-one.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# VC の提携申請（アソビュー・じゃらん遊び体験・さとふる）（t619・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
[ -n "$NODE_BIN" ] || { echo "⚠️ node が無い" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
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
JS="$RDIR/.asp-probe.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-probe.mjs > "$JS"
echo '```text' >> "$OUT"
SYNC="$RDIR/.asp-sync.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
ASP_ONLY=vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=50000 run_limited 60 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
for item in "アソビュー！|アソビュー|2130178" "じゃらん 遊び・体験予約|じゃらん 遊び|2139176" "さとふる（定率）|さとふる|2150664" "さとふる（定額）|さとふる|2143780"; do
  rm -f "$RDIR/asp-probe/applyvc5.md"
  VC_LIST="$item" ASP_PROBE=applyvc5 OPS_REPORT_DIR="$RDIR" run_limited 48 "$NODE_BIN" "$JS" > /dev/null 2>&1; rc=$?
  echo "## ${item%%|*}（rc=$rc）" >> "$OUT"
  if [ -f "$RDIR/asp-probe/applyvc5.md" ]; then grep -E '申請前|申請後|⛔|押す|問いの文|見えない' "$RDIR/asp-probe/applyvc5.md" | cut -c1-200 >> "$OUT"; else echo "- 結果が書き出されなかった（打ち切り）" >> "$OUT"; fi
done
echo '```' >> "$OUT"
head -c 4000 "$OUT"
