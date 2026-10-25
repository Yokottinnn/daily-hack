#!/bin/bash
# **x341 の直しのあと、その場で走らせた follow-balance の結果を読む（x343）。読むだけ。費用 $0。**
# 外せた件数・「購入する」がまだ出るか・プロフィールのヘッダーの数を見る。**外さない・フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs/follow-balance.log"; UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-after-fix-2.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 直したあとの follow-balance（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo '```'
launchctl print "gui/$UID_N/ai.openclaw.follow-balance" 2>/dev/null | grep -E '^\s+(state|runs|last exit code) ' | head -3
echo "--- 08:29Z（17:29 JST）以降のログ（重複行は 1 回にまとめる）"
awk '$1 >= "[2026-10-25T08:29"' "$L" 2>/dev/null | uniq | grep -E '実数|目標|外れた|外れていない|解除ボタン|購入|=== |例外|上限|候補' | tail -n 40 | cut -c1-200 | hide
echo '```'
echo "**読んだだけ。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x343 / $(basename "$OUT")"
