#!/bin/bash
# **ASP の成果のレポート画面の形を読む（t340・affiliate）。** 作戦室の「現状の数字」に成果（クリック・発生・確定）を載せるため（利用者のコメント 0dxd6x2bbryrclqjesc3・2026-10-25）。LLM 不使用・**$0**。
#   ① 4 社にログインを保ったまま、レポート画面の表の見出しと行の名前を読む（**数字は全部 # に伏せる**。本体は scripts/asp/asp-results.mjs の shape）
#   ② 数字入りの結果を非公開の置き場（Yokottinnn/daily-hack-affiliate・非公開リポジトリ）へ送れるかを確かめる（git ls-remote の終了コードだけ）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t340-asp-results-shape.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# ASP の成果のレポート画面の形（t340・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
( export ASP_ONLY=a8,rakuten,vc,moshimo OPS_REPORT_DIR="$RDIR/.sync-t340" ASP_SYNC_BUDGET_MS=200000; run_limited 240 "$NODE_BIN" "$SYNC" ) 2>&1 | grep -E "ログイン|login" | head -8 >> "$OUT"
echo '```' >> "$OUT"
rm -f "$RDIR/asp-results/shape.md"
( export RESULTS_MODE=shape OPS_REPORT_DIR="$RDIR"; run_limited 400 "$NODE_BIN" "$JS" ) > /dev/null 2>&1
echo "- asp-results shape: rc=$?" >> "$OUT"
cat "$RDIR/asp-results/shape.md" >> "$OUT" 2>/dev/null || echo "（出力が無い）" >> "$OUT"
# ② 非公開の置き場に届くか（URL と終了コードだけ。中身は読まない）
echo "" >> "$OUT"; echo "## 非公開の置き場（daily-hack-affiliate）に届くか" >> "$OUT"
for u in "https://github.com/Yokottinnn/daily-hack-affiliate.git" "git@github.com:Yokottinnn/daily-hack-affiliate.git"; do
  ( export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new"; run_limited 30 git ls-remote "$u" HEAD ) > /dev/null 2>&1
  echo "- git ls-remote $u: rc=$?" >> "$OUT"
done
echo "- daily-hack の origin の形: $(git -C "$REPO" remote get-url origin 2>/dev/null | sed -E 's#//[^@/]*@#//［伏せた］@#')" >> "$OUT"
echo "rc=0 / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 7000 "$OUT"
