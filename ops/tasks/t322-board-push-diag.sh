#!/bin/bash
# **Mac で毎朝作られている作戦室の元データが、ops/heartbeat に送られない原因を調べて、今朝の分を送る（t322）。**
# t321（2026-10-19）で分かったこと: worktree の reports/board/gsc-weekly.json などは 10/19 06:49 に作り直されているのに、
# ops/heartbeat 上は 10/12 のまま。毎日のジョブは動いていた。**送られていないだけ**だった。
# 同じ場所の trend/<日付>.json（毎日新しいファイル）は送られている。**既にあるファイルの書き換えだけが落ちている**ように見える。
#
#   ① 落ちる理由を git に聞く（status・check-ignore・index のフラグ・中身の日付と HEAD の日付）
#   ② 今朝の分を index に載せる（このタスクの後に ops-run-tasks が commit・push する）
#
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
WT="$(cd "$RDIR/.." && pwd)"
OUT="$RDIR/t322-board-push.md"
{ echo "# 作戦室の元データが送られない理由（t322・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**・worktree: \`$WT\`"; echo; } > "$OUT"
F="reports/board/gsc-weekly.json"
{
  echo "## ① git の見え方"; echo; echo '```text'
  echo "--- status reports/board"; git -C "$WT" status --porcelain --ignored reports/board 2>&1 | head -20
  echo "--- check-ignore"; git -C "$WT" check-ignore -v "$F" reports/board/x-weekly.json reports/board/mac-weekly-status.json 2>&1 | head
  echo "--- ls-files -v（h=assume-unchanged / S=skip-worktree）"; git -C "$WT" ls-files -v reports/board | head -20
  echo "--- 中身の generated（worktree）"; grep -o '"generated"[^,]*' "$WT/$F" 2>/dev/null | head -1
  echo "--- 中身の generated（HEAD）"; git -C "$WT" show "HEAD:$F" 2>/dev/null | grep -o '"generated"[^,]*' | head -1
  echo "--- HEAD / origin"; git -C "$WT" log -1 --format='%h %ci %s' HEAD; git -C "$WT" log -1 --format='%h %ci %s' "origin/ops/heartbeat" 2>&1
  echo "--- info/exclude"; cat "$(git -C "$WT" rev-parse --git-common-dir)/info/exclude" 2>/dev/null | grep -v '^#' | head
  echo "--- core.excludesFile"; git -C "$WT" config --get core.excludesFile 2>&1
  echo '```'; echo
} >> "$OUT"

# ② 今朝の分を載せる（-f で除外設定も越える。index のフラグも外す）
git -C "$WT" update-index --no-assume-unchanged --no-skip-worktree $(git -C "$WT" ls-files reports/board) 2>/dev/null || true
git -C "$WT" add -f reports/board 2>>"$OUT"
{ echo "## ② 載せたもの"; echo; echo '```text'; git -C "$WT" diff --cached --stat -- reports/board | tail -10; echo '```'; } >> "$OUT"
cat "$OUT"
