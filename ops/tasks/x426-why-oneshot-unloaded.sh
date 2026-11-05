#!/bin/bash
# x426（2026-11-05・読むだけ・$0）: 11/4 8:00 の 1 回きりのジョブ（ai.openclaw.publish-wangan5-oneshot）が走らなかった理由を読む。
# 分かっていること: x414（11/3 23:14）で bootstrap して「載っている」を確かめた。08:19（x420）には載っておらず、
# plist は残っていて、ランナーのログに start の行が無い（＝一度も起動していない）。誰が・いつ外したかを Mac の記録から読む。
# 利用者がダイアログで「予約が走らなかった理由を調べる」を選んだ。**何も書き換えない・載せ直さない・押さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; UIDN="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/x426-why-oneshot-unloaded.md"
TMPD="$W/.x426"; mkdir -p "$TMPD"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-)[A-Za-z0-9-]+/<伏せ>/g'; }
# 素の bash で打ち切る（macOS に timeout は無い・最上位ルール 14）
limited() { local lim="$1" outf="$2"; shift 2; "$@" > "$outf" 2>&1 & local pid=$! w=0
  while [ "$w" -lt "$lim" ]; do kill -0 "$pid" 2>/dev/null || break; sleep 1; w=$((w+1)); done
  if kill -0 "$pid" 2>/dev/null; then kill -TERM "$pid" 2>/dev/null; sleep 2; kill -KILL "$pid" 2>/dev/null; echo "（${lim} 秒で打ち切った）" >> "$outf"; fi; wait "$pid" 2>/dev/null; }
{
echo "# 11/4 8:00 の予約ジョブが走らなかった理由（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 1. 再起動・ログイン・スリープ"; echo '```'
sysctl -n kern.boottime 2>/dev/null
last -10 2>/dev/null | grep -E 'reboot|shutdown|console' | head -8
pmset -g log 2>/dev/null | grep -E '^2026-11-0[34] ' | grep -E ' (Sleep|Wake|DarkWake|Shutdown|Restart) ' | awk '$1=="2026-11-03" && $2>="23:00" || $1=="2026-11-04" && $2<="08:30"' | cut -c1-140 | tail -25
echo '```'
echo; echo "## 2. macOS のログで、このジョブの名前が出た行（11/3 23:10〜11/4 08:25）"; echo '```'
limited 150 "$TMPD/log1.txt" /usr/bin/log show --style compact --start "2026-11-03 23:10:00" --end "2026-11-04 08:25:00" --predicate 'eventMessage CONTAINS "publish-wangan5"'
grep -v '^Timestamp' "$TMPD/log1.txt" | cut -c1-220 | tail -30
echo '```'
echo; echo "## 3. 同じ時間に launchd が外した（bootout / removing）ジョブ"; echo '```'
limited 150 "$TMPD/log2.txt" /usr/bin/log show --style compact --start "2026-11-03 23:10:00" --end "2026-11-04 08:25:00" --predicate 'process == "launchd" AND (eventMessage CONTAINS "bootout" OR eventMessage CONTAINS "removing service" OR eventMessage CONTAINS "Unloading")'
grep -v '^Timestamp' "$TMPD/log2.txt" | grep -oE 'ai\.openclaw\.[A-Za-z0-9._-]+|com\.dailyhack\.[A-Za-z0-9._-]+' | sort | uniq -c | sort -rn | head -30
echo "--- 時刻つき（先頭 15 行）"
grep -v '^Timestamp' "$TMPD/log2.txt" | grep -E 'openclaw|dailyhack' | cut -c1-200 | head -15
echo '```'
echo; echo "## 4. ジョブを外す処理を持つスクリプトのログ（同じ時間帯）"; echo '```'
for f in "$L"/*.log; do
  n="$(awk '/2026-11-03[ T]2[3]:|2026-11-04[ T]0[0-8]:/' "$f" 2>/dev/null | grep -ciE 'bootout|unload|launchctl remove|停止' | head -1)"
  [ "${n:-0}" -gt 0 ] && { echo "--- $(basename "$f")（$n 行）"; awk '/2026-11-03[ T]2[3]:|2026-11-04[ T]0[0-8]:/' "$f" | grep -iE 'bootout|unload|launchctl remove|停止' | tail -5 | cut -c1-200 | hide; }
done
grep -lE 'launchctl (bootout|unload|remove)' "$W"/scripts/*.js "$W"/scripts/*.sh "$HOME"/projects/anta-baka-x/blog/scripts/*.sh 2>/dev/null | sed "s#$HOME#~#" | head -20
echo '```'
echo; echo "## 5. いま ai.openclaw.* はどれだけ載っているか（plist の数との比較）"; echo '```'
np="$(ls "$HOME"/Library/LaunchAgents/ai.openclaw.*.plist 2>/dev/null | wc -l | tr -d ' ')"
nl="$(launchctl print "gui/$UIDN" 2>/dev/null | grep -cE '\bai\.openclaw\.' | head -1)"
echo "plist $np 本 / launchctl print に出る ai.openclaw $nl 件"
echo "--- 載っていない plist"
for p in "$HOME"/Library/LaunchAgents/ai.openclaw.*.plist; do lb="$(basename "$p" .plist)"; launchctl print "gui/$UIDN/$lb" >/dev/null 2>&1 || echo "$lb"; done | head -20
echo '```'
echo; echo "## 6. 前に同じ作りで成功した予約（11/1 ポイント経済圏・x391）との違い"; echo '```'
ls -la "$HOME"/Library/LaunchAgents/*oneshot* 2>/dev/null | sed "s#$HOME#~#"
tail -3 "$L/publish-points-oneshot.log" 2>/dev/null | cut -c1-160
echo '```'
rm -rf "$TMPD"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
