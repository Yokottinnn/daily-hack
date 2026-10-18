#!/bin/bash
# **12:00 の感謝祭の告知が thread-main-exec で 8 秒で落ちた理由を読む（x320）。投稿しない。費用 $0。**
#
# run-publish.sh は post-via-playwright.js の stdout を捨てるので、理由がログに無い。
#   ① post-via-playwright.js の中で、本文の長さ・重み・280・上限・DRY の扱いを grep する（行番号つき）
#   ② 失敗時に何を out() するか（step 名）を一覧にする
#   ③ **投稿しない形**で、同じ本文の重みを、スクリプトと同じ数え方で数え直す
#   ④ CDP の健全性（cdp-health.js）
# **送信は一切しない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/why-prime-post-failed.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 12:00 の告知が落ちた理由（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo
echo "## 1. post-via-playwright.js の長さ・上限の扱い"
echo
echo '```'
wc -l "$S/post-via-playwright.js" | sed 's/^/  /'
grep -nE '280|weight|length|MAX_|limit|too long|DRY|dry|countWeight|twitter-text|isValid' "$S/post-via-playwright.js" | cut -c1-220 | head -60
echo '```'
echo
echo "## 2. 失敗時に出す step の一覧"
echo
echo '```'
grep -noE 'step:\s*"[^"]+"|step\s*=\s*"[^"]+"|ok:\s*false[^)]{0,120}' "$S/post-via-playwright.js" | cut -c1-200 | head -60
echo '```'
echo
echo "## 3. 冒頭 60 行（引数の受け取りと、最初の検査）"
echo
echo '```'
sed -n 1,60p "$S/post-via-playwright.js" | cut -c1-200
echo '```'
echo
echo "## 4. run-publish.sh の thread-main-exec まわり"
echo
echo '```'
grep -nE 'thread-main-exec|post-via-playwright|execSync|maxBuffer|timeout' "$S/run-publish.sh" | cut -c1-220 | head -20
echo '```'
echo
echo "## 5. CDP"
echo
echo '```'
"$NODE_BIN" "$S/cdp-health.js" 2>&1 | tail -2
echo '```'
echo
echo "**投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x320 / $(basename "$OUT")"
