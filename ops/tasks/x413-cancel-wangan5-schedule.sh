#!/bin/bash
# x413（2026-11-03・$0）: 11/4 8:00 の湾岸ニュース5選の予約（x412）を外す。
# blog3 経由の利用者の選択「お台場に直してから出す／間に合わなければ 8:00 には出ない」（2026-11-03・「エリアの名前は青海じゃなくてお台場にして」）。
# 直した版を利用者に見せ、「投稿して」をもらってから予約し直す。**投稿しない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"
LABEL="ai.openclaw.publish-wangan5-oneshot"; UIDN="$(id -u)"; ID="x-news-20261104-wangan-5"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x413-cancel-wangan5-schedule.md"
{
echo "# 湾岸ニュース5選の 8:00 の予約を外す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
launchctl bootout "gui/$UIDN/$LABEL" 2>&1; echo "bootout rc=$?"
rm -f "$LA/$LABEL.plist" "$S/publish-wangan5-oneshot.sh" "$S/.publish-wangan5-writeback.js"
launchctl print "gui/$UIDN/$LABEL" >/dev/null 2>&1 && echo "**まだ載っている**" || echo "**外れた（載っていない）**"
ls "$LA/$LABEL.plist" 2>/dev/null && echo "**plist が残っている**" || echo "plist なし"
"$NODE_BIN" -e '
const fs=require("fs");const [qp,id]=process.argv.slice(1);const q=JSON.parse(fs.readFileSync(qp,"utf8"));
const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);const e=rows.find(x=>x&&x.id===id);
if(!e){console.log("キューに無い");process.exit(0)}
if(e.x_tweet_id){console.log("**もう出ている: "+e.x_tweet_id+"**");process.exit(0)}
e.status="cancelled";e.auto_publish=false;e.cancelled_at=new Date().toISOString();e.cancel_note="x413: 利用者の選択「お台場に直してから出す」。直した版で予約し直す";
fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);JSON.parse(fs.readFileSync(qp,"utf8"));
console.log("キューの "+id+" を cancelled にした（auto_publish false）");' "$D/post_queue.json" "$ID" 2>&1
echo '```'
echo "**投稿していない。LLM を呼ばない（\$0）。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
