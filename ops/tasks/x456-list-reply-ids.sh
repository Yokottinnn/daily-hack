#!/bin/bash
# x456（2026-11-10・読むだけ・$0）: x455 で返信の記録に本文が無かった。11/7〜11/11 の成功した返信の投稿 ID を全部出す（本文はクラウドから X の公開データで読む）。
set -uo pipefail
L="$HOME/.openclaw/workspace/logs"; OUT="${OPS_REPORT_DIR:-/tmp}/x456-list-reply-ids.md"
{
echo "# 返信の投稿 ID（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
echo '```'
grep -hE '^\{"ok":true,"entry_id":"comment-2026(1107|1108|1109|1110|1111)' "$L/comment-warmup.log" 2>/dev/null | grep -oE '"x_tweet_id":"[0-9]{15,}"' | grep -oE '[0-9]{15,}'
echo '```'
} > "$OUT" 2>&1
echo "$(grep -cE '^[0-9]{15,}$' "$OUT") 件"
exit 0
