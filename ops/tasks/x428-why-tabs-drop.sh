#!/bin/bash
# x428（2026-11-07・読むだけ・$0）: tab-guard が「タブの一括破壊」と判断して ai.openclaw.* を全部外す件の、タブが減った原因を読む。
# 利用者がダイアログで「朝 5 時のタブ急減の原因を調べる」を選んだ。
# 全停止の時刻（UTC）: 2026-11-03T20:05（23→9 枚）・20:18（9→1 枚）・2026-11-02T13:08（22→6 枚）。朝 5 時（JST）は daily-supervisor（5:00）が動く時間。
#   ① tab-guard.js が何を数えて、どの条件で全停止するか（コード）
#   ② daily-supervisor.sh が Chrome に何をするか（コード）
#   ③ 全停止の前後 15 分の、Chrome 関係・supervisor のログ
# **何も書き換えない・載せ直さない・押さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/x428-why-tabs-drop.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-)[A-Za-z0-9-]+/<伏せ>/g; s#https?://(?!x\.com|127\.0\.0\.1|localhost)[^\s"]+#<URL>#g'; }
WIN='2026-11-03T(19:[5]|20:[0-3])|2026-11-04[ T]0(4:5|5:[0-3])|2026-11-02T1(2:5|3:[01])|2026-11-02[ T]2(1:5|2:[01])'
{
echo "# タブが急に減った原因（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## ① tab-guard.js（何を数えて、いつ全停止するか）"; echo '```js'
wc -l < "$S/tab-guard.js" | xargs -I{} echo "// {} 行"
grep -nE 'CDP|cdp|port|1881|9222|targets|json/list|tabs|一括|全消滅|threshold|THRESH|ratio|<|>|unload|lock|interval|Jordan' "$S/tab-guard.js" | head -60 | cut -c1-200 | hide
echo '```'
echo; echo "## ② daily-supervisor.sh（Chrome に何をするか）"; echo '```'
wc -l < "$S/daily-supervisor.sh" | xargs -I{} echo "# {} 行"
grep -nE -i 'chrome|cdp|kill|pkill|restart|open -a|quit|osascript|bootout|kickstart|tab' "$S/daily-supervisor.sh" | head -40 | cut -c1-200 | hide
echo '```'
echo; echo "## ③ 全停止の前後のログ（Chrome・CDP・supervisor・tab-guard）"; echo '```'
for f in "$L"/*.log; do
  b="$(basename "$f")"
  case "$b" in *chrome*|*cdp*|*supervisor*|*tab-guard*|*ensure*|*heal*|*restart*|*cookie*|*refresh*) ;; *) continue ;; esac
  m="$(grep -E "$WIN" "$f" 2>/dev/null | tail -12)"
  [ -n "$m" ] && { echo "--- $b"; printf '%s\n' "$m" | cut -c1-220 | hide; }
done
echo "--- daily-supervisor.log の 11/3 20:00Z〜20:50Z（全部）"
awk '/2026-11-03T20:0[0-9]/,/2026-11-03T20:5/' "$L/daily-supervisor.log" 2>/dev/null | head -40 | cut -c1-200 | hide
echo '```'
echo; echo "## ④ 同じ時間帯に Chrome を起動・終了したプロセスの記録（macOS のログ・90 秒で打ち切り）"; echo '```'
T="$W/.x428-log.txt"
/usr/bin/log show --style compact --start "2026-11-04 04:58:00" --end "2026-11-04 05:20:00" --predicate '(process == "launchd" OR process == "Google Chrome" OR process == "Google Chrome for Testing") AND (eventMessage CONTAINS "exited" OR eventMessage CONTAINS "Terminat" OR eventMessage CONTAINS "SIGTERM" OR eventMessage CONTAINS "SIGKILL" OR eventMessage CONTAINS "spawn")' > "$T" 2>&1 &
p=$!; w=0; while [ $w -lt 90 ]; do kill -0 $p 2>/dev/null || break; sleep 1; w=$((w+1)); done; kill -0 $p 2>/dev/null && { kill -TERM $p; sleep 2; kill -KILL $p 2>/dev/null; echo "（90 秒で打ち切った）"; }
grep -v '^Timestamp' "$T" | grep -iE 'chrome|openclaw|dailyhack' | cut -c1-200 | head -25 | hide
rm -f "$T"
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
