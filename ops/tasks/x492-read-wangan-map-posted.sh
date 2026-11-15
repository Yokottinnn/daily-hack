#!/bin/bash
# **読むだけ・$0。** 湾岸エリアイベントマップの告知（x-blog-20261115-wangan-map・11/15 12:00 予約）が出たかを、キューの x_tweet_id とログで見る（x492）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; OUT="${OPS_REPORT_DIR:-/tmp}/x492-read-wangan-map-posted.md"
{
echo "# マップの告知が出たか（$(date '+%F %T') JST・読むだけ）"; echo '```'
/usr/local/bin/node -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const r=(Array.isArray(q)?q:(q.queue||q.items||q.posts)).find(x=>x&&x.id==="x-blog-20261115-wangan-map");console.log(r?JSON.stringify({status:r.status,x_tweet_id:r.x_tweet_id||null,posted_at:r.posted_at||null,t2:(r.thread_chain&&r.thread_chain[1]&&r.thread_chain[1].x_tweet_id)||null,last_result:r.last_result||null}):"entry なし")' "$W/data/post_queue.json"
echo "--- publish-wangan-map-oneshot.log"; tail -15 "$W/logs/publish-wangan-map-oneshot.log" 2>/dev/null | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo "--- err"; tail -5 "$W/logs/publish-wangan-map-oneshot-err.log" 2>/dev/null
echo '```'
} > "$OUT" 2>&1
echo "マップの告知の結果を読んだ / $(basename "$OUT")"
