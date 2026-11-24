#!/bin/bash
# x553（2026-11-24・読むだけ・$0）: 11/24 のクリスマスマーケット（画像 10 枚）が、ALT を 5 枚目まで入れたところで 2 回とも落ちた。
# エラーの全文（本文は伏せる）と、post-via-playwright.js の ALT を入れるところを出す。11/25 のクルーズ船（画像 6 枚）の前に直すため。
# **何も書き換えない・押さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/x553-read-alt-6th-failure.md"
F="$S/post-via-""playwright.js"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g; s/(playwright\.js) \\?"[A-Za-z0-9+\/=]{20,}\\?"/$1 <本文>/g'; }
{
echo "# ALT の 6 枚目で落ちた原因（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 1. エラーの全文（1 回目）"; echo '```'
grep -h '"step":"thread-main-exec"' "$L/publish-xmas-market-hikaku-oneshot.log" 2>/dev/null | head -1 | clean | fold -w 200 | head -40
echo '```'
echo; echo "## 2. ALT を入れるところ（前後）"; echo '```'
ls -la "$F" | sed "s#$HOME#~#"
n="$(grep -n 'altTextWrapper' "$F" | head -1 | cut -d: -f1)"
[ -n "${n:-}" ] && sed -n "$(( n > 25 ? n - 25 : 1 )),$(( n + 50 ))p" "$F" | cut -c1-220
echo '```'
echo; echo "## 3. 6 枚・10 枚でテストしたとき（x538・x539）の ALT"; echo '```'
grep -h -i 'alt' "$L"/*x538* "$L"/*x539* 2>/dev/null | head -10 | cut -c1-200
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
