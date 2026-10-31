#!/bin/bash
# **reply-followers-cleanup.js が unfollow-handle の結果をどう扱うかを読む（x385）。読むだけ・$0。**
# x384: 「もうフォローしていない（no unfollow button）」が失敗扱いで記録されず、先頭 20 件に居座る。直す前に該当箇所を読む。
set -uo pipefail
RF="$HOME/.openclaw/workspace/scripts/reply-followers-cleanup.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x385-cleanup-result-handling.md"
{
echo "# 外す処理の結果の扱い（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo "全 $(wc -l < "$RF" | tr -d ' ') 行"; echo '```javascript'
sed -n '1,140p' "$RF" | cut -c1-220 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
echo "**読んだだけ（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x385 / $(basename "$OUT")"
