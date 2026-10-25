#!/bin/bash
# **1 日の返信の数がいくつで動いているかを読む（x350）。読むだけ・LLM 不使用・$0。**
# 利用者（2026-10-26）「1日の返信の数を30くらいにする施策はもう動いているんだっけ？」。設定（発火の時刻・1 回の件数・上限）と、直近 7 日の実際に出た件数を並べる。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x350-reply-volume.md"
P="$HOME/Library/LaunchAgents/ai.openclaw.comment-warmup.plist"
{
echo "# 返信の数の設定と実績（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## comment-warmup の plist（発火の時刻と環境変数）"; echo '```'
plutil -p "$P" 2>&1 | grep -vE 'TOKEN|KEY|SECRET|PASSWORD' | head -60
echo '```'
echo; echo "## launchd に載っているか"; echo '```'
launchctl print "gui/$(id -u)/ai.openclaw.comment-warmup" 2>&1 | grep -E 'state =|runs =|last exit' | head -5
echo '```'
echo; echo "## comment-orchestrator.sh の中の件数・上限の設定"; echo '```'
grep -nE 'PICKS|CAP|LIMIT|MAX_' "$W/scripts/comment-orchestrator.sh" 2>/dev/null | head -20
echo '```'
echo; echo "## 直近 7 日、実際に出た返信の数（comment-warmup.log の ok:true・日付は entry_id の JST）"; echo '```'
grep -hoE '^\{"ok":true,"entry_id":"comment-[0-9]{8}-[0-9]{4}' "$W/logs/comment-warmup.log" 2>/dev/null | sed -E 's/.*comment-([0-9]{8})-([0-9]{2})[0-9]{2}/\1 \2/' \
 | awk '{d[$1]++; h[$1" "$2]++} END {for (k in d) print k, d[k]"件"; }' | sort | tail -7
echo "--- 時刻ごと（直近 2 日）"
grep -hoE '^\{"ok":true,"entry_id":"comment-[0-9]{8}-[0-9]{4}' "$W/logs/comment-warmup.log" 2>/dev/null | sed -E 's/.*comment-([0-9]{8})-([0-9]{2})[0-9]{2}/\1 \2時/' | sort | uniq -c | tail -14
echo '```'
echo "**読んだだけ。LLM を呼んでいない（\$0／回）。**"
} > "$OUT" 2>&1
echo "x350 / $(basename "$OUT")"
