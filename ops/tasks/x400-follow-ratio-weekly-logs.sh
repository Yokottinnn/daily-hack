#!/bin/bash
# x400（2026-11-02・読むだけ・$0）: 毎週のフォロー比率チェック（利用者の指示 2026-10-25）。
# 比率 0.663（447/674）が警戒線 0.480 を超え、前週 0.642 から上がった。外す側（follow-balance・mutual-prune・
# reply-followers-cleanup）とフォローする側の直近 7 日の件数をログから数える。**何も書き換えない・押さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/x400-follow-ratio-weekly-logs.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x|twitter)\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1.com/<伏せ>#g'; }
{
echo "# フォロー比率の週次チェック：直近 7 日の外した・フォローした件数（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
DAYS="$(node -e 'const o=[];for(let i=0;i<7;i++){o.push(new Date(Date.now()+9*3600e3-i*864e5).toISOString().slice(0,10))}console.log(o.join(" "))')"
echo "対象日: $DAYS"
for J in follow-balance mutual-prune reply-followers-cleanup competitor-follower-follow hashtag-follow badge-followback; do
  F="$L/$J.log"
  echo; echo "## $J"
  if [ ! -f "$F" ]; then echo "ログが無い: $F"; continue; fi
  echo '```'
  for d in $DAYS; do
    n_all="$(grep -c "$d" "$F" | head -1)"
    n_un="$(grep "$d" "$F" | grep -ciE 'unfollow|外した|解除' | head -1)"
    n_fo="$(grep "$d" "$F" | grep -viE 'unfollow|解除' | grep -ciE 'followed|フォローした' | head -1)"
    echo "$d 行 $n_all / 外した系 $n_un / フォローした系 $n_fo"
  done
  echo "--- 直近の終わりの行（まとめ）"
  grep -E 'done|完了|まとめ|summary|上限|cap|ratio|比率|何もしない|skip' "$F" | tail -8 | cut -c1-220 | hide
  echo '```'
done
echo; echo "## 載っているか（launchctl print）"; echo '```'
for J in follow-balance mutual-prune reply-followers-cleanup competitor-follower-follow hashtag-follow badge-followback; do
  printf '%s: ' "$J"; launchctl print "gui/$(id -u)/ai.openclaw.$J" 2>/dev/null | grep -E '^\s*(runs|last exit code) =' | tr -s ' \n' ' '; echo
done
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
