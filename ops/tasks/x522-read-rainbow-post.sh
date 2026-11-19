#!/bin/bash
# x522（2026-11-17・読むだけ・$0）: 11/18 12:00 に予約した レインボーライドの告知（x-blog-20261118-rainbow-ride・x488）が出たかを、キューの x_tweet_id とジョブのログで確かめる。
# 他人のハンドルと秘密は伏せる。何も押さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; UIDN="$(id -u)"; LABEL="com.dailyhack.publish-rainbow-ride-oneshot"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x522-read-jal-post.md"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g; s/(Bearer )[A-Za-z0-9._-]{12,}/$1<伏せ>/g'; }
{
echo "# レインボーライドの告知が出たか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## キュー"; echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);
const e=rows.find(x=>x&&x.id==="x-blog-20261118-rainbow-ride");
if(!e){console.log("キューに無い");process.exit(0)}
console.log("status="+e.status+" x_tweet_id="+(e.x_tweet_id||"なし")+" posted_at="+(e.posted_at||"なし")+" scheduled_at="+e.scheduled_at);
console.log("last_result="+JSON.stringify(e.last_result||null).slice(0,400));
(e.thread_chain||[]).forEach((c,i)=>console.log("  ["+(i+1)+"] x_tweet_id="+(c.x_tweet_id||"なし")));' "$W/data/post_queue.json" 2>&1 | clean
echo '```'
echo; echo "## ジョブ"; echo '```'
if launchctl print "gui/$UIDN/$LABEL" >/dev/null 2>&1; then launchctl print "gui/$UIDN/$LABEL" | grep -E '^\s+(state|runs|last exit code) ' ; else echo "載っていない（走り終えて自分を外したか、最初から載っていない）"; fi
ls -la "$HOME/Library/LaunchAgents/$LABEL.plist" 2>&1 | tail -1
echo '```'
echo; echo "## ログ（末尾 40 行）"; echo '```'
for f in "$L/publish-rainbow-ride-oneshot.log" "$L/publish-rainbow-ride-oneshot-out.log" "$L/publish-rainbow-ride-oneshot-err.log"; do [ -f "$f" ] && { echo "--- $(basename "$f")"; tail -40 "$f" | cut -c1-300 | clean; }; done
echo '```'
echo; echo "## ほかの予約ジョブ"; echo '```'
ls "$HOME/Library/LaunchAgents/" | grep -E 'publish-.*-oneshot' 
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E 'status=|載って' "$OUT" | head -3 | cut -c1-160
exit 0
