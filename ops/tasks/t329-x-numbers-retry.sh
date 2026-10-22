#!/bin/bash
# **今朝読めなかった X の数字を読み直す。読めなければ、開いた画面の URL・題名・冒頭の文を残す（t329）。**
# 10/22 6:4x の x-numbers.json は全部 null だった（エラーも出さずに数字が 1 つも取れていない）。読むだけ・押さない・投稿しない。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t329-x-numbers.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
W="$HOME/.openclaw/workspace"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || echo /usr/local/bin/node)"
mkdir -p "$RDIR/board"
{ echo "# X の数字の読み直し（t329・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
{ echo "## 毎朝のジョブのログ（x-numbers の部分）"; echo; echo '```text'; tail -40 "$HOME/.openclaw/logs/board-weekly.log" 2>/dev/null | grep -iE "x_numbers|x-numbers|error|CDP|board weekly" | tail -10; echo '```'; echo; } >> "$OUT"
git -C "$REPO" fetch -q origin main 2>/dev/null; git -C "$REPO" show origin/main:scripts/strategy-board/x-numbers.js > "$W/.x-numbers.js"
( cd "$W" && "$NODE_BIN" "$W/.x-numbers.js" "$RDIR/.x-numbers-try.json" > "$W/.x-numbers.log" 2>&1 & echo $! > "$W/.x-numbers.pid" )
XPID="$(cat "$W/.x-numbers.pid")"; t0=$(date +%s)
while kill -0 "$XPID" 2>/dev/null; do [ $(( $(date +%s) - t0 )) -ge 170 ] && { kill "$XPID" 2>/dev/null; echo "- ⚠️ 170 秒で終わらなかった" >> "$OUT"; break; }; sleep 3; done
{ echo "## いま読んだもの"; echo; echo '```json'; cat "$RDIR/.x-numbers-try.json" 2>/dev/null || tail -5 "$W/.x-numbers.log"; echo; echo '```'; echo; } >> "$OUT"
if "$NODE_BIN" -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.exit(j.header&&j.header.followers?0:1)' "$RDIR/.x-numbers-try.json" 2>/dev/null; then
  mv "$RDIR/.x-numbers-try.json" "$RDIR/board/x-numbers.json"; echo "- **読めた。** reports/board/x-numbers.json を置き換えた" >> "$OUT"
else
  echo "- **まだ読めない。** 上の debug（URL・題名・冒頭）が原因の手がかり" >> "$OUT"
fi
cat "$OUT"
