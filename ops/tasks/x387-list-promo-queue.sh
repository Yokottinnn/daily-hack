#!/bin/bash
# **告知の投稿キューを一覧にする（x387）。読むだけ・$0。**
# 作戦室に「投稿準備中の下書き」を出すため、どの組が投稿済みかを一次情報（x_tweet_id）で分ける。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x387-promo-queue.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 告知の投稿キュー（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"; echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const a=Array.isArray(q)?q:(q.queue||q.items||Object.values(q));
const rows=a.filter(e=>/blog-promo|promo|thread/.test(String(e.id||"")+String(e.kind||"")));
console.log("全体",a.length,"／ 告知",rows.length);
for(const e of rows){const ids=[e.x_tweet_id||e.tweet_id,...((e.thread_chain||[]).map(c=>c.x_tweet_id||c.tweet_id))].filter(Boolean);
console.log([String(e.id).slice(0,60),e.status||"",e.slug||"",(e.created_at||e.createdAt||"").slice(0,16),ids.join(",")].join("\t"))}' "$W/data/post_queue.json" 2>&1 | tail -80
echo '```'
echo "**読んだだけ（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x387 / $(basename "$OUT")"
