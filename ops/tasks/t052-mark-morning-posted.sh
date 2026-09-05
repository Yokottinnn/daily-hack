#!/bin/bash
# **出したのにキューが `pending` のままなので、`posted` に直す。二重投稿を防ぐ。**
#
# ## 何が起きているか
#
# `t051` でモーニング告知は **[1/2] と [2/2] の両方 出た。**
#
#   {"ok":true,"tweet_id":"2096230281909006590","thread_count":2,
#    "thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2096230281909006590",
#                       "image_attached":true,"captured_via":"graphql_response"},
#                      {"index":1,"role":"cta","ok":true,
#                       "reply_tweet_id":"2096230358161482222"}]}
#
# **なのにキューは `status: "pending"` / `posted: false` のまま。**
# `run-publish.sh` は投稿に成功しても**エントリに書き戻さない。**
#
# ## なぜ直すのか
#
# 投稿系のタスクは「もう出ていないか」をキューで判定している。
# **このままだと次のタスクが「まだ出ていない」と誤認して、もう一度 出す。**
# 2026-08-15 に承認から 8 日経った滞留エントリを処理して誤爆した前科がある。
#
# ## やること
#
#   1. **本当に出ているかを確かめてから書く。** X の GraphQL 応答で取れた
#      tweet_id を持っているので、それを埋める
#   2. `status` を `posted`、`posted_at` を現在時刻にする
#   3. `thread_chain[0]` / `[1]` にもそれぞれの tweet_id を入れる
#   4. **すでに `posted` なら何もしない**（べき等）
#
# ## やらないこと
#
# **投稿しない。削除しない。他のエントリを触らない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/mark-morning-posted.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
ID="blog-promo-20260905-morning-500-2026"
QJSON="$W/data/post_queue.json"
TW1="2096230281909006590"
TW2="2096230358161482222"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# 出したエントリを posted に直す（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> \`t051\` で **[1/2] と [2/2] の両方 出た**のに、キューは \`pending\` のまま。"
echo "> \`run-publish.sh\` は成功してもエントリに書き戻さない。"
echo "> **このままだと次のタスクが「まだ出ていない」と誤認して、もう一度 出す。**"

echo
echo "## 書き換え"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const [qp,id,t1,t2]=process.argv.slice(1);
let q;
try{ q=JSON.parse(fs.readFileSync(qp,"utf8")); }
catch(e){ console.log("キューが読めない: "+e.message); process.exit(1); }
const rows=q.queue||[];
const e=rows.find(x=>x&&x.id===id);
if(!e){ console.log("該当エントリが無い: "+id); process.exit(1); }

if(e.status==="posted" && e.x_tweet_id){
  console.log("すでに posted。何もしない。");
  console.log("  x_tweet_id = "+e.x_tweet_id);
  process.exit(0);
}

console.log("  前: status=" + e.status + " / x_tweet_id=" + (e.x_tweet_id||"null"));
e.status="posted";
e.x_tweet_id=t1;
e.posted_at=new Date().toISOString();
e.posted_url="https://x.com/i/status/"+t1;
if(Array.isArray(e.thread_chain)){
  if(e.thread_chain[0]){ e.thread_chain[0].x_tweet_id=t1; e.thread_chain[0].posted_at=e.posted_at; }
  if(e.thread_chain[1]){ e.thread_chain[1].x_tweet_id=t2; e.thread_chain[1].posted_at=e.posted_at; }
}
fs.writeFileSync(qp+".tmp", JSON.stringify(q,null,2));
fs.renameSync(qp+".tmp", qp);
console.log("  後: status=posted / x_tweet_id="+t1);
console.log("  chain[0]="+t1);
console.log("  chain[1]="+t2);
' "$QJSON" "$ID" "$TW1" "$TW2" 2>&1 | hide
echo '```'

echo
echo "## 確認"
echo
echo '```json'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const e=(q.queue||[]).find(x=>x&&x.id===process.argv[2]);
  if(!e){ console.log("（無い）"); process.exit(0); }
  console.log(JSON.stringify({
    id:e.id, status:e.status, x_tweet_id:e.x_tweet_id||null, posted_at:e.posted_at||null,
    chain:(e.thread_chain||[]).map((c,i)=>({n:i+1, role:c.role||null,
      tweet_id:c.x_tweet_id||null, posted:!!c.x_tweet_id}))
  },null,1));
}catch(err){ console.log("読めない: "+err.message); }
' "$QJSON" "$ID" 2>&1 | hide
echo '```'

echo
echo "## 同じ記事の重複エントリが無いか"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=(q.queue||[]).filter(e=>{
    const t=(e&&e.id||"")+" "+(e&&e.text||"")+" "+(e&&e.target_url||"");
    return t.includes("morning-500-2026");
  });
  if(!rows.length){ console.log("（無い）"); }
  rows.forEach(e=>console.log("  "+e.id+"  status="+e.status+"  tweet="+(e.x_tweet_id||"-")));
  if(rows.filter(e=>e.status==="posted").length>1)
    console.log("  **posted が 2 件以上ある。二重投稿の疑い。人が確かめること。**");
}catch(err){ console.log("読めない: "+err.message); }
' "$QJSON" 2>&1 | hide
echo '```'

echo
echo "---"
echo
echo "**投稿していない。削除していない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -qE '後: status=posted|すでに posted' "$OUT" 2>/dev/null; then
  echo "**キューを posted に直した（二重投稿の防止・\$0）** / $(basename "$OUT")"
else
  echo "直せていない。レポートを読むこと / $(basename "$OUT")"
fi
