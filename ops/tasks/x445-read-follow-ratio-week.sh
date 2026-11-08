#!/bin/bash
# x445（2026-11-09・読むだけ・$0）: 毎週のフォロー比率チェック。11/8 朝のヘッダーで 504/721＝0.699 と警戒線（0.647）を超え、前週（11/3・0.653）より上がった。
# この 1 週間に、フォローした件数・外した件数を日ごとに数え、follow-balance が外せなかった理由を読む。毎朝の数字（x-numbers.json）が 11/9 に更新されていない理由も見る。
# **何も書き換えない・押さない。** 他人のハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/x445-follow-ratio-week.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x|twitter)\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1.com/<伏せ>#g'; }
{
echo "# フォロー比率の 1 週間（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 外した件数（follow-balance・日ごと・JST の日付ではなくログの日付）"; echo '```'
F="$L/follow-balance.log"
for d in 2026-11-02 2026-11-03 2026-11-04 2026-11-05 2026-11-06 2026-11-07 2026-11-08; do
  s="$(grep -c "^\[$d.*start" "$F" 2>/dev/null | head -1)"; u="$(grep "^\[$d" "$F" 2>/dev/null | awk '!seen[$0]++' | grep -c '外れた' | head -1)"
  printf '%s  起動 %s 回 ／ 外れた %s 件\n' "$d" "${s:-0}" "${u:-0}"
done
echo "--- 直近の回の終わり"
tail -n 25 "$F" 2>/dev/null | cut -c1-200 | hide
echo '```'
echo; echo "## フォローした件数（ログに出る件数・日ごと）"; echo '```'
for f in "$L"/*follow*.log; do
  case "$f" in *follow-balance*|*unfollow*) continue;; esac
  [ -f "$f" ] || continue
  echo "[$(basename "$f")]"
  for d in 2026-11-02 2026-11-03 2026-11-04 2026-11-05 2026-11-06 2026-11-07 2026-11-08; do
    n="$(grep "$d" "$f" 2>/dev/null | grep -ciE 'followed|フォローした|✓ follow|follow ok' | head -1)"
    [ "${n:-0}" != "0" ] && printf '  %s  %s 件\n' "$d" "$n"
  done
done
echo '```'
echo; echo "## 載っているフォロー系のジョブ"; echo '```'
for lb in ai.openclaw.follow-balance ai.openclaw.mutual-prune ai.openclaw.badge-followback ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  printf '%-44s ' "$lb"; launchctl print "gui/$(id -u)/$lb" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | tr -s ' \n' ' ' || true; echo
done
echo '```'
echo; echo "## 毎朝の数字（x-numbers）の更新"; echo '```'
ls -la "$W/data"/x-numbers*.json "$L"/*x-numbers*.log 2>/dev/null | sed "s#$HOME#~#"
for f in "$L"/*x-numbers*.log "$L"/*board-numbers*.log; do [ -f "$f" ] && { echo "--- $(basename "$f")"; tail -n 8 "$f" | cut -c1-200 | hide; }; done
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
