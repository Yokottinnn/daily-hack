#!/bin/bash
# x511（2026-11-16・$0）: フォロー比率 0.742（警戒線 0.643 を 2 週続けて超えた）。利用者がダイアログで「未認証の相互をもっと外して釣り合わせる」を選んだ。
#  mutual-prune の MUTUAL_RATIO_CUT を 0.8 → 0（未認証の相互は、相手のフォロー÷フォロワーに関係なく外す候補にする）。認証済みの相互は今までどおり守る
#  1 回に外す数（MAX_UNFOLLOW=8）・猶予（GRACE_DAYS=3）・間隔の決まり（人の動き方・30 分 4 回・深夜は押さない）はそのまま
#  比率が警戒線を下回ったら 0.8 に戻す（毎週の点検・24 時間後の実測で見る）。戻すときは plist の .bak-x511
# LLM を呼ばない。走っている最中なら触らない。
set -uo pipefail
LABEL="ai.openclaw.mutual-prune"; P="$HOME/Library/LaunchAgents/$LABEL.plist"; PB=/usr/libexec/PlistBuddy; UIDN="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/x511-mutual-prune-all-unverified.md"
{
echo "# 未認証の相互も外す候補にする（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
if [ ! -f "$P" ]; then echo "plist が無い"; echo '```'; exit 0; fi
ST="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')"
if [ "$ST" = "running" ]; then echo "**いま走っている。触らない**（次の周回でやり直す）"; echo '```'; exit 0; fi
cp -p "$P" "$P.bak-x511"
echo "変える前: MUTUAL_RATIO_CUT=$("$PB" -c "Print :EnvironmentVariables:MUTUAL_RATIO_CUT" "$P" 2>/dev/null || echo 未設定)・MAX_UNFOLLOW=$("$PB" -c "Print :EnvironmentVariables:MAX_UNFOLLOW" "$P" 2>/dev/null || echo 未設定)・GRACE_DAYS=$("$PB" -c "Print :EnvironmentVariables:GRACE_DAYS" "$P" 2>/dev/null || echo 未設定)"
"$PB" -c "Set :EnvironmentVariables:MUTUAL_RATIO_CUT 0" "$P" 2>/dev/null || "$PB" -c "Add :EnvironmentVariables:MUTUAL_RATIO_CUT string 0" "$P"
if ! plutil -lint "$P" >/dev/null 2>&1; then cp -p "$P.bak-x511" "$P"; echo "**plutil が通らない。元に戻した**"; echo '```'; exit 0; fi
launchctl bootout "gui/$UIDN/$LABEL" 2>/dev/null
launchctl bootstrap "gui/$UIDN" "$P" 2>&1 | head -1
PR="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
if [ -z "$PR" ]; then echo "**載っていない**"; else echo "載っている ← launchd が持っている値:"; printf '%s\n' "$PR" | grep -aE 'MUTUAL_RATIO_CUT|MAX_UNFOLLOW|GRACE_DAYS' | sed 's/^[[:space:]]*/  /'; fi
echo '```'
echo; echo "**何も外していない（次の周回から効く）。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '載っている|走っている|元に戻した|変える前' "$OUT" | head -3 | cut -c1-140
exit 0
