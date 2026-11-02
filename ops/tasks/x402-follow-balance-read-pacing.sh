#!/bin/bash
# x402（2026-11-02・$0）: x401 で分かったこと
#   ① ai.openclaw.follow-balance が launchd に載っていない（kickstart が「サービスが無い」rc=113）
#   ② 1 回 20 件まで外せるのに、候補を探す時間（150 秒）で打ち切られて 6 件しか外せていない
#   ③ 外す間隔が約 11 秒（最上位ルール 23 はフォロー解除 120 秒・30 分 6 回）
# ここでは **載せ直す（bootstrap）だけ**。走らせない（③ を直す前に走らせると、11 秒間隔で外すため）。
# あとはコードを読む: 打ち切りの秒数・外す処理の待ち・pacer を使っているか。LLM を呼ばない（$0）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts/follow-balance.js"; UIDN="$(id -u)"
P="$HOME/Library/LaunchAgents/ai.openclaw.follow-balance.plist"; L="gui/$UIDN/ai.openclaw.follow-balance"
OUT="${OPS_REPORT_DIR:-/tmp}/x402-follow-balance-read-pacing.md"
{
echo "# 比率の調整：載せ直しと、外す間隔の作りを読む（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo; echo "## ① 載せ直す（走らせない）"; echo '```'
ls -la "$P" "$P".disabled 2>&1 | head -3
launchctl print "$L" >/dev/null 2>&1 && echo "もう載っている" || { launchctl bootstrap "gui/$UIDN" "$P" 2>&1; echo "bootstrap rc=$?"; }
launchctl print "$L" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | tr -s ' \n' ' '; echo
launchctl print "$L" >/dev/null 2>&1 && echo "**載っている**" || echo "**載っていない**"
grep -n 'follow-balance' "$HOME/projects/anta-baka-x/blog/ops/data/autoload-jobs.txt" 2>/dev/null || echo "autoload 一覧に無い"
plutil -extract StartCalendarInterval json -o - "$P" 2>/dev/null | head -c 200; echo
plutil -extract EnvironmentVariables json -o - "$P" 2>/dev/null | head -c 600; echo
echo '```'
echo; echo "## ② 打ち切りの秒数（DECIDE_BUDGET）"; echo '```'
grep -nE 'DECIDE_BUDGET|timeUp' "$S" | head -12 | cut -c1-200
echo '```'
echo; echo "## ③ 外す処理の待ち（pacer・waitForTimeout・sleep）"; echo '```'
grep -nE 'pacer|x-action|ledger|waitForTimeout|setTimeout|sleep|unfollow|confirmationSheetConfirm|-unfollow' "$S" | head -40 | cut -c1-200
echo '```'
n="$(grep -n 'confirmationSheetConfirm' "$S" | head -1 | cut -d: -f1)"
if [ -n "$n" ]; then echo; echo "## ③ 外す処理の前後 40 行"; echo '```'; sed -n "$((n>30?n-30:1)),$((n+15))p" "$S" | cut -c1-200; echo '```'; fi
echo; echo "## pacer の部品が在るか"; echo '```'
ls -la "$HOME/projects/anta-baka-x/blog/ops/lib/x-action-pacer.cjs" "$W/scripts/x-action-pacer.cjs" 2>&1 | head
grep -l 'x-action-pacer' "$W"/scripts/*.js 2>/dev/null | head -10
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
