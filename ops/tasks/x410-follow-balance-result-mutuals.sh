#!/bin/bash
# x410（2026-11-03・読むだけ・$0）: 利用者「未認証の相互は、アンフォローしても影響なさそうなやつは厳選してアンフォローしていいよ」。
# x409 で 2026-11-03 18:00 JST に走らせた follow-balance（x408 の版）の結果を読む。**何も書き換えない・押さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; F="$W/logs/follow-balance.log"
OUT="${OPS_REPORT_DIR:-/tmp}/x410-follow-balance-result.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x|twitter)\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1.com/<伏せ>#g'; }
{
echo "# 比率の調整：11/3 18:00 に走らせた回の結果（未認証の相互）（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo '```'
n="$(grep -n '2026-11-03T09:0' "$F" | grep 'start' | head -1 | cut -d: -f1)"
if [ -n "$n" ]; then tail -n +"$n" "$F" | awk '!seen[$0]++' | grep -vE '^\s*$' | head -90 | cut -c1-200 | hide; else echo "18:00 以降の start 行が見つからない"; grep 'start' "$F" | tail -3; fi
echo '```'
echo; echo "## 外れた件数（18:00 以降）"; echo '```'
[ -n "$n" ] && tail -n +"$n" "$F" | awk '!seen[$0]++' | grep -c '外れた' | head -1
[ -n "$n" ] && tail -n +"$n" "$F" | awk '!seen[$0]++' | grep -E '外れた' | sed -E 's/^\[([^]]*)\].*/\1/' | head -25
echo '```'
echo; echo "## いまの状態"; echo '```'
launchctl print "gui/$(id -u)/ai.openclaw.follow-balance" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | tr -s ' \n' ' '; echo
"$NODE_BIN" "$W/lib/x-action-pacer.cjs" status 2>&1
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
