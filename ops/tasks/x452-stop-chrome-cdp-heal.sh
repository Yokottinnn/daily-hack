#!/bin/bash
# x452（2026-11-10・$0）: ai.openclaw.chrome-cdp-heal を止め、二度と載らないよう plist を .disabled にする。
# 利用者「このメッセージが30件ぐらい来て本当に迷惑だからやめてほしい」（Slack C0A5FKU7T5M に「Chrome CDP heal 失敗」が 5 分おき）。
# 9/8 にも同じジョブが 5 分おきに通知し Chrome を落としていた（docs/browser-destroyed-postmortem.md）。Mac の再起動（11/9）でまた載った。
set -uo pipefail
LABEL="ai.openclaw.chrome-cdp-heal"; LA="$HOME/Library/LaunchAgents"; P="$LA/$LABEL.plist"; U="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/x452-stop-chrome-cdp-heal.md"
{
echo "# chrome-cdp-heal を止める（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo '```'
echo "  前: $(launchctl print gui/$U/$LABEL 2>/dev/null | grep -E '^\s+(state|runs) =' | tr -s ' \n' ' ' || echo 載っていない)"
launchctl bootout "gui/$U/$LABEL" 2>&1 | head -2
[ -f "$P" ] && mv "$P" "$P.disabled" && echo "  plist を .disabled にした"
ls -la "$LA" | grep -i cdp-heal
if launchctl print "gui/$U/$LABEL" >/dev/null 2>&1; then echo "  **まだ載っている**"; else echo "  → 止まった（print に出ない）"; fi
echo '```'
} > "$OUT" 2>&1
grep -E '止まった|まだ載っている' "$OUT" | head -1
exit 0
