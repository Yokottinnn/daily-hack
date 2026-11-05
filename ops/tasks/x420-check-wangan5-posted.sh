#!/bin/bash
# x420（2026-11-04・読むだけ・$0）: 11/4 08:00 に予約した湾岸ニュース5選（x414・x-news-20261104-wangan-5b）が出たかを、
# キューの x_tweet_id（一次情報）と 1 回きりのジョブのログで確かめる。何も書き換えない・押さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/x420-wangan5-posted.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 湾岸ニュース5選の予約投稿は出たか（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);
const e=rows.find(x=>x&&x.id==="x-news-20261104-wangan-5b");
if(!e){console.log("キューに無い");process.exit(0);}
const tc=(e.thread_chain||[]).map(c=>c&&c.x_tweet_id||null);
console.log(JSON.stringify({status:e.status,x_tweet_id:e.x_tweet_id||null,thread_chain_ids:tc,posted_at:e.posted_at||null,last_result:e.last_result||null}));' "$D/post_queue.json" 2>&1
echo "--- 1 回きりのジョブのログ（末尾 25 行）"
tail -n 25 "$W/logs/publish-wangan5-oneshot.log" 2>/dev/null | cut -c1-240 | hide
echo "--- 画像・ALT に触れた行"
grep -iE 'alt|media|image|画像' "$W/logs/publish-wangan5-oneshot.log" 2>/dev/null | tail -8 | cut -c1-240 | hide
echo "--- ジョブはまだ載っているか"
launchctl print "gui/$(id -u)/ai.openclaw.publish-wangan5-oneshot" >/dev/null 2>&1 && echo "載っている（まだ走っていない可能性）" || echo "載っていない（走って自分を外した）"
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
