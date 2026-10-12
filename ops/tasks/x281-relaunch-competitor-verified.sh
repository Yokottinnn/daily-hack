#!/bin/bash
# **x279 の起動が開始行だけで止まった原因を全文ログで見て、launchd の正規ジョブとして起動し直す。費用 $0。**
#
# x280（21:54）: ログは「start: ... cap=10」の 1 行だけ。scraped も ✅ も無く、フォローは 0 件。
# nohup で ops の実行の子として起動したため、ops 側の終了と一緒に落ちた可能性がある（全文で確かめる）。
# 起動し直しは **launchctl kickstart**（ops から切り離される）。plist の上限は 30。
# 比率はいま 202／366＝0.552。30 件 全部 フォローしても 232／366＝0.634 で帯（〜0.65）の中（最上位ルール 19）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/relaunch-competitor-verified.md"
LABEL="ai.openclaw.competitor-follower-follow"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 競合の認証済みフォロワーからのフォローを起動し直す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## x279 のログ全文（stderr 込み）"
echo '```'
cat "$W/logs/x279-competitor-verified.log" 2>/dev/null | hide | tail -40
echo '```'
echo
echo "## ジョブ本体のログ（直近 15 行）"
echo '```'
tail -15 "$W/logs/competitor-follower-follow.log" 2>/dev/null | hide
echo '```'
echo
echo "## launchd で起動"
echo '```'
launchctl print "gui/$(id -u)/$LABEL" 2>&1 | grep -E "state =|runs =|last exit code" | head -4
launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>&1 | head -3; echo "kickstart rc=$?"
sleep 8
launchctl print "gui/$(id -u)/$LABEL" 2>&1 | grep -E "state =|runs =|last exit code|pid =" | head -5
echo '```'
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 結果は次のタスクで読む。"
} > "$OUT" 2>&1
echo "競合の認証済みフォロワーからのフォローを launchd で起動し直した / $(basename "$OUT")"
