#!/bin/bash
# x470（2026-11-12・読むだけ・$0）: ららぽーと豊洲ブラックフライデーの予約投稿（x446・11/12 12:00）と見張り（x459）の結果を見る。
set -uo pipefail
W="$HOME/.openclaw/workspace"; OUT="${OPS_REPORT_DIR:-/tmp}/x470-read-lalaport-posted.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# ららぽーとの予約投稿（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
echo '```'
node -e 'const q=require(process.argv[1]);const r=(Array.isArray(q)?q:(q.queue||q.items||q.posts)).find(x=>x&&x.id==="x-news-20261112-lalaport-bf");console.log(r?JSON.stringify({status:r.status,x_tweet_id:r.x_tweet_id||null,last_result:r.last_result||null}):"キューに無い")' "$W/data/post_queue.json" 2>&1
for f in "$W"/logs/lalaport-guard-1112.log "$W"/logs/publish-lalaport*.log; do [ -f "$f" ] && { echo "--- $(basename "$f")"; grep -v '^\[run-publish\]\|^\[step\]' "$f" | tail -n 10 | cut -c1-400 | hide; }; done
echo '```'
} > "$OUT" 2>&1
grep -oE '"x_tweet_id":"?[0-9a-z]+' "$OUT" | head -1
exit 0
