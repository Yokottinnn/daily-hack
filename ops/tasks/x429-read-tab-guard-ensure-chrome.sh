#!/bin/bash
# x429（2026-11-07・読むだけ・$0）: 利用者が「再起動の直後は止めないようにする」を選んだ。
# 直す前に、tab-guard.js の全文と、ensure-chrome.sh が自動化用の Chrome を再起動する部分を読む（差し込む場所を推測で決めない・最上位ルール 20）。
# **何も書き換えない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/x429-read-tab-guard-ensure-chrome.md"
mask() { sed -E -e 's#(xox[abp]-)[A-Za-z0-9-]+#\1<MASKED>#g' -e 's#(sk-ant-)[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(hooks\.slack\.com/services/)[A-Za-z0-9/]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g'; }
{
echo "# tab-guard.js と ensure-chrome.sh を読む（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## tab-guard.js（全文）"; echo '```js'
cat -n "$S/tab-guard.js" | mask
echo '```'
echo; echo "## ensure-chrome.sh（再起動の前後）"; echo '```bash'
wc -l < "$S/ensure-chrome.sh" | xargs -I{} echo "# {} 行"
N="$(grep -n 'CDP hang confirmed' "$S/ensure-chrome.sh" | head -1 | cut -d: -f1)"
if [ -n "$N" ]; then sed -n "$((N>40?N-40:1)),$((N+45))p" "$S/ensure-chrome.sh" | cat -n | mask; else echo "（CDP hang confirmed の行が無い）"; grep -n -iE 'restart|kill|open -a|launch' "$S/ensure-chrome.sh" | head -30 | mask; fi
echo '```'
echo; echo "## どのポートの Chrome か"; echo '```'
grep -n -E '1881[0-9]|9222|remote-debugging-port|user-data-dir' "$S/ensure-chrome.sh" | head -10 | mask
pgrep -fl 'remote-debugging-port' 2>/dev/null | sed -E 's#--user-data-dir=[^ ]+#--user-data-dir=<dir>#g' | cut -c1-200 | head -5
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
