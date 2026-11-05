#!/bin/bash
# x427（2026-11-05・読むだけ・$0）: ai.openclaw.* をまとめて外しているのは誰か。
# heartbeat の自動載せ直しが「16 本中 14〜15 本が外れていた」を出した時刻: 10/29 05:30・10/30 05:16・10/31 16:25・10/31 21:33・
# 11/2 22:29・11/4 05:17・11/4 05:47（JST）。11/4 8:00 の 1 回きりの予約ジョブはこの一覧に無いので、外れたまま走らなかった（x426）。
# 外す処理を持つスクリプト（x426 ④）のコードと、外れた時間帯のログを読む。**何も書き換えない・載せ直さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/x427-who-mass-unloads.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-)[A-Za-z0-9-]+/<伏せ>/g'; }
# 外れた時間帯（JST と UTC の両方の書き方）
WIN='2026-11-04[ T]0(4:[45]|5:[0-4])|2026-11-03T(19:[45]|20:[0-4])|2026-10-30[ T]0(4:[45]|5:[01])|2026-10-29T(19:[45]|20:[01])|2026-10-29[ T]0(5:[0-3])|2026-10-28T20:[0-3]|2026-11-02[ T]2(1:[45]|2:[0-2])|2026-11-02T1(2:[45]|3:[0-2])'
{
echo "# ai.openclaw.* をまとめて外しているのは誰か（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 1. 外す処理を持つスクリプトの、launchctl を呼ぶ行"; echo '```'
for f in tab-guard.js daily-supervisor.sh wave-freeze.sh emergency-stop-llm.sh fire-watchdog.js auto-reply.js space-approved-posts.js; do
  [ -f "$S/$f" ] || continue; echo "--- $f"; grep -nE 'launchctl|ai\.openclaw\.\*|openclaw\.' "$S/$f" | grep -iE 'bootout|unload|remove|list|grep' | head -8 | cut -c1-200
done
echo '```'
echo; echo "## 2. 朝 4〜5 時台と夜に動くように設定されたジョブ（plist の StartCalendarInterval）"; echo '```'
for p in "$LA"/ai.openclaw.*.plist "$LA"/com.dailyhack.*.plist; do
  h="$(plutil -extract StartCalendarInterval json -o - "$p" 2>/dev/null)"; [ -n "$h" ] || continue
  echo "$h" | grep -qE '"Hour"\s*:\s*(4|5|16|21|22)\b' && echo "$(basename "$p" .plist): $(echo "$h" | tr -d '\n ' | cut -c1-120)"
done
echo '```'
echo; echo "## 3. 外れた時間帯に、外す系の言葉が出たログ"; echo '```'
for f in "$L"/*.log "$L"/*.txt; do
  [ -f "$f" ] || continue
  m="$(grep -E "$WIN" "$f" 2>/dev/null | grep -iE 'bootout|unload|停止|freeze|stop|halt|lock|kill|一斉|全部|all jobs' | tail -6)"
  [ -n "$m" ] && { echo "--- $(basename "$f")"; printf '%s\n' "$m" | cut -c1-220 | hide; }
done
echo '```'
echo; echo "## 4. tab-guard の止める仕組み（lock の有無・最近の記録）"; echo '```'
ls -la "$W"/data/*lock* "$W"/*.lock "$W"/data/*halt* 2>/dev/null | sed "s#$HOME#~#" | head -10
for f in tab-guard.log wave-freeze.log daily-supervisor.log emergency-stop.log fire-watchdog.log; do [ -f "$L/$f" ] && { echo "--- $f（最後の 5 行）"; tail -5 "$L/$f" | cut -c1-200 | hide; }; done
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
