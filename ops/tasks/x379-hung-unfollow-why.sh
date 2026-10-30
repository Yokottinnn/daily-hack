#!/bin/bash
# **15 時間止まったままの reply-followers-cleanup と unfollow-handle を、理由を記録してから終わらせる（x379）。押さない・$0。**
# 利用者が「止まったままの処理を終わらせ、理由を調べる」を選んだ（2026-10-30）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x379-hung-unfollow.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(unfollow-handle\.js )[A-Za-z0-9_]+/$1<伏せ>/g'; }
secs() { echo "$1" | awk -F'[-:]' '{n=NF; s=$n+$(n-1)*60; if(n>=3)s+=$(n-2)*3600; if(n>=4)s+=$(n-3)*86400; print s}'; }
{
echo "# 止まった外す処理の理由（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## 1. 止まっている処理と親子"; echo '```'
ps -axo pid,ppid,etime,command | grep -E 'node .*scripts/(reply-followers-cleanup|unfollow-handle)\.js' | grep -v grep | cut -c1-140 | hide
echo '```'
echo; echo "## 2. reply-followers-cleanup のログの最後 25 行（.log と .err）"; echo '```'
tail -25 "$W/logs/reply-followers-cleanup.log" 2>/dev/null | cut -c1-220 | hide
echo "--- err"; tail -15 "$W/logs/reply-followers-cleanup.err" 2>/dev/null | cut -c1-220 | hide
echo '```'
echo; echo "## 3. reply-followers-cleanup が unfollow-handle を呼ぶところ（時間切れの有無）"; echo '```'
grep -nE 'unfollow-handle|execSync|spawnSync|timeout' "$W/scripts/reply-followers-cleanup.js" 2>/dev/null | head -15 | cut -c1-200
echo '```'
echo; echo "## 4. unfollow-handle.js の待ちと時間切れ"; echo '```'
grep -nE 'waitFor|timeout|connectOverCDP|process\.exit|goto' "$W/scripts/unfollow-handle.js" 2>/dev/null | head -25 | cut -c1-200
echo '```'
echo; echo "## 5. 終わらせる（30 分以上動いているものだけ・子から）"; echo '```'
for name in unfollow-handle reply-followers-cleanup; do
  ps -axo pid=,etime=,command= | grep -E "node .*scripts/$name\.js" | grep -v grep | while read -r pid et cmd; do
    s=$(secs "$et"); if [ "${s:-0}" -ge 1800 ]; then kill -TERM "$pid" 2>/dev/null; sleep 2; kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null; echo "終わらせた: $name pid=$pid 経過 $et"; fi
  done
done
sleep 2; echo "--- 残り"; ps -axo pid,etime,command | grep -E 'node .*scripts/(reply-followers-cleanup|unfollow-handle)\.js' | grep -v grep | cut -c1-120 | hide
echo '```'
echo "**押していない（\$0）。**"
} > "$OUT" 2>&1
echo "x379 / $(basename "$OUT")"
