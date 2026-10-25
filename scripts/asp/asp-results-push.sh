#!/bin/bash
# ASP の成果（数字入り）を非公開リポジトリ Yokottinnn/daily-hack-affiliate のブランチ data/asp-results に送る（affiliate・2026-10-25）。
# **公開リポジトリ（daily-hack）と公開ブランチ（ops/heartbeat）には数字を出さない。** 出力は件数と終了コードだけ。
#   使い方: asp-results-push.sh <数字入りの JSON>
set -uo pipefail
SRC="$1"; [ -s "$SRC" ] || { echo "push: 入力が無い"; exit 1; }
WT="${TMPDIR:-/tmp}/asp-results-wt"
URL="https://github.com/Yokottinnn/daily-hack-affiliate.git"
BR="data/asp-results"
export GIT_TERMINAL_PROMPT=0
rm -rf "$WT"
if git clone -q --depth 1 --branch "$BR" "$URL" "$WT" 2>/dev/null; then :; else
  git clone -q --depth 1 "$URL" "$WT" 2>/dev/null || { echo "push: clone できない"; exit 1; }
  git -C "$WT" checkout -q --orphan "$BR" && git -C "$WT" rm -rq . 2>/dev/null
fi
mkdir -p "$WT/asp-results"
D="$(date '+%Y-%m-%d')"
cp "$SRC" "$WT/asp-results/latest.json"; cp "$SRC" "$WT/asp-results/$D.json"
printf '# ASP の成果（数字入り・非公開）\n\nMac の scripts/asp/asp-results.mjs（collect）が毎日書く。affiliate がこれを読んで作戦室の db（results/latest）に載せる。\n' > "$WT/README.md"
git -C "$WT" add -A
if git -C "$WT" diff --cached --quiet; then echo "push: 変化なし"; exit 0; fi
git -C "$WT" -c user.name="dailyhack-mac" -c user.email="noreply@fieldbeside.com" commit -q -m "asp-results $D"
for i in 1 2 3; do git -C "$WT" push -q origin "HEAD:$BR" 2>/dev/null && { echo "push: 送った（$BR）"; exit 0; }; sleep 5; done
echo "push: 送れなかった"; exit 1
