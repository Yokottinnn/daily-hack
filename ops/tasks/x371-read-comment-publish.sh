#!/bin/bash
# **返信が「積んだまま出ない」理由を読む（x371）。読むだけ・$0。** x370 で 10/27 以降の返信 19 件がキューに pending のまま残っていると分かった。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x371-comment-publish.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 返信を出す段のコード（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## comment-orchestrator.sh の 125 行目以降"; echo '```'; sed -n '125,230p' "$W/scripts/comment-orchestrator.sh" | cut -c1-220; echo '```'
echo; echo "## comment-warmup.log の 10/26〜10/27 の行（ok 行のあと何が出ているか）"; echo '```'
grep -nE '2026-10-2[67]T' "$W/logs/comment-warmup.log" | head -40 | cut -c1-240 | hide
echo '```'
echo; echo "## comment-warmup-err.log の最後 30 行"; echo '```'; tail -30 "$W/logs/comment-warmup-err.log" 2>/dev/null | cut -c1-240 | hide; echo '```'
echo; echo "## 10/26 以降に変わったスクリプト"; echo '```'; find "$W/scripts" -maxdepth 1 -newermt "2026-10-25 12:00" -type f 2>/dev/null | xargs ls -la 2>/dev/null | awk '{print $6,$7,$8,$9}'; echo '```'
echo; echo "## run-publish.sh の最終更新と先頭 30 行"; echo '```'; ls -la "$W/scripts/run-publish.sh" | awk '{print $6,$7,$8}'; sed -n '1,30p' "$W/scripts/run-publish.sh" | cut -c1-200; echo '```'
} > "$OUT" 2>&1
echo "x371 / $(basename "$OUT")"
