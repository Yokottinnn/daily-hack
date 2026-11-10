#!/bin/bash
# x465（2026-11-11・読むだけ・$0）: x464 で、相手の返信（11/3 22:44 JST）の直後も incoming-reply-watcher は「no new replies」だった。
# どの投稿を見ているか（109 行目の絞り込み）と、返信をどう拾っているかを読む。こちらの投稿 2116727000358646078 が見る範囲に入っているかも見る。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts/incoming-reply-watcher.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x465-read-reply-watcher-code.md"
{
echo "# incoming-reply-watcher の見る範囲と拾い方（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
echo '```js'; sed -n '95,170p' "$S" | cut -c1-200; echo '```'
echo; echo "## こちらの投稿のキューの中身"; echo '```'
node -e 'const q=require(process.argv[1]);const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);const e=rows.find(x=>x&&(x.x_tweet_id==="2116727000358646078"||JSON.stringify(x).includes("2116727000358646078")));console.log(e?JSON.stringify({id:e.id,kind:e.kind,status:e.status,x_tweet_id:e.x_tweet_id,posted_at:e.posted_at,chain:(e.thread_chain||[]).map(c=>c.x_tweet_id)}):"無い");console.log("キュー件数 "+rows.length)' "$W/data/post_queue.json" 2>&1
echo '```'
} > "$OUT" 2>&1
echo "x465 / $(basename "$OUT")"
exit 0
