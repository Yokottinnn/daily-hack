#!/bin/bash
# **run-publish.sh が「出せたのに parse-main-result（stdout が空）で ok:false」を返す原因を読む（x333）。読むだけ。費用 $0。**
# x325・x328・x332 の 3 回とも、投稿は出ていたのに raw が空だった。直す前に、結果の受け渡しの実物を読む。
# **投稿しない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/parse-main-result.md"
mask() { sed -E -e 's#(auth_token=|ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# parse-main-result の原因を読む（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo "## 1. run-publish.sh の単発経路の後半（行番号つき・170 行目から最後まで）"
echo '```'; nl -ba "$S/run-publish.sh" | sed -n '170,$p' | cut -c1-240 | mask; echo '```'
echo "## 2. post-via-playwright.js の 255 行目から最後まで"
echo '```'; nl -ba "$S/post-via-playwright.js" | sed -n '255,$p' | cut -c1-240 | mask; echo '```'
echo "## 3. post-via-playwright.js の中の process.exit と out( の行"
echo '```'; grep -nE 'process\.exit|out\(\{ ?ok: ?true|console\.log' "$S/post-via-playwright.js" | cut -c1-200 | mask; echo '```'
echo "**読んだだけ。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x333 / $(basename "$OUT")"
