#!/bin/bash
# x404（2026-11-03・読むだけ・$0）: 利用者が「終わったら結果を読む」を選んだ。
# x403 で 2026-11-02 22:16 JST に走らせた follow-balance（外す間隔を台帳に合わせた版）の結果を読む。**何も書き換えない・押さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; F="$W/logs/follow-balance.log"
OUT="${OPS_REPORT_DIR:-/tmp}/x404-follow-balance-result.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x|twitter)\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1.com/<伏せ>#g'; }
{
echo "# 比率の調整：22:16 に走らせた回の結果（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo '```'
n="$(grep -n '2026-11-02T13:1[5-9]\|2026-11-02T13:[2-5]' "$F" | grep 'start' | head -1 | cut -d: -f1)"
if [ -n "$n" ]; then tail -n +"$n" "$F" | awk '!seen[$0]++' | grep -vE '^\s*$' | head -90 | cut -c1-200 | hide; else echo "22:16 以降の start 行が見つからない"; grep 'start' "$F" | tail -3; fi
echo '```'
echo; echo "## 外れた件数（22:16 以降）"; echo '```'
[ -n "$n" ] && tail -n +"$n" "$F" | awk '!seen[$0]++' | grep -c '— 外れた' | head -1
[ -n "$n" ] && tail -n +"$n" "$F" | awk '!seen[$0]++' | grep -E '外れた' | sed -E 's/^\[([^]]*)\].*/\1/' | head -25
echo '```'
echo; echo "## いまの状態"; echo '```'
launchctl print "gui/$(id -u)/ai.openclaw.follow-balance" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | tr -s ' \n' ' '; echo
"$NODE_BIN" "$W/lib/x-action-pacer.cjs" status 2>&1
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
