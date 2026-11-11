#!/bin/bash
# x468（2026-11-11・読むだけ・$0）: ふるさと納税サイト比較の予約投稿（x441・11/11 12:00）が出たかを見る。
set -uo pipefail
W="$HOME/.openclaw/workspace"; OUT="${OPS_REPORT_DIR:-/tmp}/x468-read-furusato-posted.md"
{
echo "# ふるさと納税の予約投稿（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
echo '```'
node -e 'const q=require(process.argv[1]);const r=(Array.isArray(q)?q:(q.queue||q.items||q.posts)).find(x=>x&&x.id==="x-blog-20261111-furusato");console.log(r?JSON.stringify({status:r.status,x_tweet_id:r.x_tweet_id||null,t2:(r.thread_chain&&r.thread_chain[1]&&r.thread_chain[1].x_tweet_id)||null,last_result:r.last_result||null}):"キューに無い")' "$W/data/post_queue.json" 2>&1
for f in "$W"/logs/publish-furusato*.log; do [ -f "$f" ] && { echo "--- $(basename "$f")"; grep -v '^\[run-publish\]' "$f" | tail -n 8 | cut -c1-400 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }; done
echo '```'
} > "$OUT" 2>&1
grep -oE '"x_tweet_id":"?[0-9a-z]+' "$OUT" | head -1
exit 0
