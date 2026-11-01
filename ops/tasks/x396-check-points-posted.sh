#!/bin/bash
# x396（2026-11-01・読むだけ・$0）: 11/1 12:00 に予約したポイント経済圏（blog-promo-20261101-points）が出たかを、
# キューの x_tweet_id（一次情報）と 1 回きりのジョブのログで確かめる。何も書き換えない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/x396-points-posted.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# ポイント経済圏の予約投稿は出たか（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);
const e=rows.find(x=>x&&x.id==="blog-promo-20261101-points");
if(!e){console.log("キューに無い");process.exit(0);}
const tr=(e.thread_results||[]).map(r=>r&&(r.reply_tweet_id||r.tweet_id)).filter(Boolean);
console.log(JSON.stringify({status:e.status,x_tweet_id:e.x_tweet_id||null,thread_ids:tr,posted_at:e.posted_at||null,error:e.error||e.last_error||null}));' "$D/post_queue.json" 2>&1
echo "--- 1 回きりのジョブのログ（末尾 15 行）"
tail -n 15 "$W/logs/publish-points-oneshot.log" 2>/dev/null | cut -c1-220 | hide
echo "--- ジョブはまだ載っているか"
launchctl print "gui/$(id -u)/ai.openclaw.publish-points-oneshot" >/dev/null 2>&1 && echo "載っている（まだ走っていない可能性）" || echo "載っていない（走って自分を外した）"
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
