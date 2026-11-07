#!/bin/bash
# **楽天の初の発生（未確定 1 件）の中身を読む（t563・affiliate・2026-11-06）。** 利用者「楽天のアフィリエイトで159円の報酬が発生しているみたいだけど、これなに？」→ ダイアログで「Mac で注文明細を読む」。asp-results.mjs が楽天の「注文明細」「ショップ別」「成果報酬・確定実績」も辿るようにしたので、それで今すぐ 1 回読む（読むだけ・購入や設定の変更なし）。LLM 不使用・**$0**。
#   ① 4 社のレポート画面を読み、数字入りの JSON を作る（scripts/asp/asp-results.mjs の collect）。**数字は公開ブランチに出さない**
#   ② その JSON を非公開リポジトリ Yokottinnn/daily-hack-affiliate のブランチ data/asp-results に送る（scripts/asp/asp-results-push.sh。出すのは件数と終了コードだけ）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t563-asp-results-shape.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# ASP の成果のレポート画面の形（t563・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
SYNC="$RDIR/.asp-sync.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
JS="$RDIR/.asp-results.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-results.mjs > "$JS"
[ -s "$JS" ] || { echo "⚠️ scripts/asp/asp-results.mjs が main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
echo '```text' >> "$OUT"
( export ASP_ONLY=a8,rakuten,vc,moshimo OPS_REPORT_DIR="$RDIR/.sync-t563" ASP_SYNC_BUDGET_MS=200000; run_limited 240 "$NODE_BIN" "$SYNC" ) 2>&1 | grep -E "ログイン|login" | head -8 >> "$OUT"
echo '```' >> "$OUT"
PRIV="${TMPDIR:-/tmp}/asp-results-private.json"; rm -f "$PRIV"
( export RESULTS_MODE=collect OPS_REPORT_DIR="${TMPDIR:-/tmp}/asp-results-md" RESULTS_OUT="$PRIV"; run_limited 400 "$NODE_BIN" "$JS" ) > /dev/null 2>&1
echo "- asp-results collect: rc=$?・JSON $( [ -s "$PRIV" ] && wc -c < "$PRIV" | tr -d ' ' || echo 0 ) bytes（中身は出さない）" >> "$OUT"
PUSH="$RDIR/.asp-results-push.sh"; git -C "$REPO" show origin/main:scripts/asp/asp-results-push.sh > "$PUSH"
[ -s "$PRIV" ] && ( run_limited 120 /bin/bash "$PUSH" "$PRIV" ) >> "$OUT" 2>&1
rm -f "$PRIV"
echo "rc=0 / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 7000 "$OUT"
