#!/bin/bash
# **フォロー比率が 0.640（10/25 6:43・ヘッダー 385/602）まで上がっている。follow-balance と mutual-prune とフォロー側が どう動いているかを読む（x335）。読むだけ。費用 $0。**
# 目標（最上位ルール 19・FOLLOW_RATIO_GLIDE）はフォロワー 600 で約 0.46・警戒 約 0.51。**外さない・フォローしない。画面は撮らない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; LA="$HOME/Library/LaunchAgents"; UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-1025.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(https?://(x|twitter)\.com/)(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1<伏せ>#g'; }
{
echo "# フォロー比率の仕組みを読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
for L in ai.openclaw.follow-balance ai.openclaw.mutual-prune; do
  echo; echo "## $L"; echo '```'
  if launchctl print "gui/$UID_N/$L" >/dev/null 2>&1; then launchctl print "gui/$UID_N/$L" | grep -E '^\s+(state|runs|last exit code) ' ; else echo "  **載っていない**"; fi
  P="$LA/$L.plist"; [ -f "$P" ] && /usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables' "$P" 2>/dev/null | grep -vE 'TOKEN|KEY|SECRET|PASS' | head -30
  echo '```'
done
echo; echo "## follow-balance のログ（末尾）"; echo '```'
ls -t "$W"/logs/*follow-balance* 2>/dev/null | head -3
for f in $(ls -t "$W"/logs/*follow-balance* 2>/dev/null | head -2); do echo "--- $(basename "$f")"; tail -n 40 "$f" | cut -c1-240 | hide; done
echo '```'
echo; echo "## mutual-prune のログ（末尾）"; echo '```'
for f in $(ls -t "$W"/logs/*mutual-prune* 2>/dev/null | head -1); do echo "--- $(basename "$f")"; tail -n 20 "$f" | cut -c1-240 | hide; done
echo '```'
echo; echo "## フォローする側のジョブ（載っているもの・1 日の上限の設定）"; echo '```'
launchctl list 2>/dev/null | awk '{print $3}' | grep -iE 'follow' | sort | while read -r L; do
  printf '  %s ' "$L"; P="$LA/$L.plist"; [ -f "$P" ] && /usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables' "$P" 2>/dev/null | grep -iE 'MAX|LIMIT|CAP|DAILY|PER_' | tr -s ' \n' ' '; echo
done
echo '```'
echo; echo "**読んだだけ。外していない・フォローしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x335 / $(basename "$OUT")"
