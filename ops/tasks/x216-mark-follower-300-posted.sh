#!/bin/bash
# **キューの blog-promo-20261003-follower-300 を posted に書き戻す（二重投稿を防ぐ）。費用 $0。**
#
# x214 で投稿は X に出ていた（x215 で確認: https://x.com/heng_ji31590/status/2106354716733235381・GIF つき）。
# だが post-via-playwright.js の出力が空で、run-publish.sh が parse-main-result で ok:false を返したため、
# **キューは pending・auto_publish:true・scheduled_at 済みのまま。** 自動投稿に拾われると二重投稿になる。
#
# **投稿しない。この 1 件の status と x_tweet_id だけを書き換える。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261003-follower-300"
TID="2106354716733235381"
OUT="${OPS_REPORT_DIR:-/tmp}/mark-follower-300-posted.md"
{
echo "# キューを posted に書き戻す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo '```'
node -e '
const fs=require("fs");
const [qp,id,tid]=process.argv.slice(1);
let q; try{ q=JSON.parse(fs.readFileSync(qp,"utf8")); }catch(e){ console.log("  キューが読めない: "+e.message); process.exit(1); }
const e=(q.queue||[]).find(x=>x&&x.id===id);
if(!e){ console.log("  エントリが無い"); process.exit(1); }
console.log("  前: status="+e.status+" x_tweet_id="+(e.x_tweet_id||null)+" auto_publish="+e.auto_publish);
e.status="posted"; e.x_tweet_id=tid; e.posted_at=e.posted_at||"2026-10-03T12:04:00.000Z"; e.auto_publish=false;
if(Array.isArray(e.thread_chain)&&e.thread_chain[0]) e.thread_chain[0].x_tweet_id=tid;
fs.writeFileSync(qp+".tmp", JSON.stringify(q,null,2)); fs.renameSync(qp+".tmp", qp);
const q2=JSON.parse(fs.readFileSync(qp,"utf8")); const e2=(q2.queue||[]).find(x=>x&&x.id===id);
console.log("  後: status="+e2.status+" x_tweet_id="+e2.x_tweet_id+" auto_publish="+e2.auto_publish);
' "$QJSON" "$ID" "$TID" 2>&1
echo "  (rc=$?)"
echo '```'
echo
echo "**投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
if grep -q '後: status=posted' "$OUT"; then echo "キューを posted に書き戻した / $(basename "$OUT")"; else echo "**書き戻せていない** / $(basename "$OUT")"; fi
