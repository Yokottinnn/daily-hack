#!/bin/bash
# **t321 で走らせ直した作戦室の取得の結果を、巻き戻しで消える前に送る。X の数字を読み直す（t323）。**
# t322 で分かった原因: heartbeat は毎回 worktree を origin に巻き戻す（reset --hard）ので、
# 毎朝のジョブが書き換えた既存のファイルは送られる前に消えていた。mac-weekly.sh には「書いたらすぐ送る」を足した（同じ PR）。
#
#   ① board-weekly の起動スクリプト（~/.openclaw/bin/board-weekly-boot.sh）が main の mac-weekly.sh を使っているか
#   ② X の数字を読み直す（7D を押してから読むように直した x-numbers.js）
#   ③ reports/board を index に載せる（この後 ops-run-tasks が commit・push する）
#
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
WT="$(cd "$RDIR/.." && pwd)"
OUT="$RDIR/t323-board-save.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
W="$HOME/.openclaw/workspace"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || echo /usr/local/bin/node)"
{ echo "# 作戦室の取得結果を送る・X の数字を読み直す（t323・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
{ echo "## ① 起動スクリプト"; echo; echo '```bash'; cat "$HOME/.openclaw/bin/board-weekly-boot.sh" 2>&1 | head -30; echo '```'; echo
  echo "### いま mac-weekly が動いているか"; echo; echo '```text'; pgrep -fl "mac-weekly|asp-probe|gsc-dump" 2>&1 | head -5; echo '```'; echo
  echo "### reports/board"; echo; echo '```text'; ls -la "$WT/reports/board" "$WT/reports/board/asp-probe" 2>&1 | head -20; echo '```'; echo; } >> "$OUT"

git -C "$REPO" fetch -q origin main 2>/dev/null; git -C "$REPO" show origin/main:scripts/strategy-board/x-numbers.js > "$W/.x-numbers.js"
( cd "$W" && "$NODE_BIN" "$W/.x-numbers.js" "$RDIR/board/x-numbers.json" > "$W/.x-numbers.log" 2>&1 & echo $! > "$W/.x-numbers.pid" )
XPID="$(cat "$W/.x-numbers.pid")"; t0=$(date +%s)
while kill -0 "$XPID" 2>/dev/null; do [ $(( $(date +%s) - t0 )) -ge 170 ] && { kill "$XPID" 2>/dev/null; echo "- ⚠️ x-numbers が 170 秒で終わらなかった" >> "$OUT"; break; }; sleep 3; done
{ echo "## ② X の数字"; echo; echo '```json'; cat "$RDIR/board/x-numbers.json" 2>/dev/null; echo; echo '```'; echo; } >> "$OUT"

git -C "$WT" add -f reports/board 2>>"$OUT"
{ echo "## ③ 載せたもの"; echo; echo '```text'; git -C "$WT" diff --cached --stat -- reports/board | tail -10
  for f in gsc-weekly.json asp-probe/a8partnered.json mac-weekly-status.json x-numbers.json; do echo "$f: $(grep -o '"generated"[^,}]*' "$WT/reports/board/$f" 2>/dev/null | head -1)"; done; echo '```'; } >> "$OUT"
cat "$OUT"
