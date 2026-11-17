#!/bin/bash
# x519（2026-11-17・読むだけ・$0）: JAL の告知（x485）が 12:00 に thread-main-exec で失敗した。エラーの末尾（スクリプトの引数の後ろ＝本当の理由）を読む。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x519-read-jal-error.md"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g; s/(Bearer )[A-Za-z0-9._-]{12,}/$1<伏せ>/g'; }
{
echo "# JAL の告知の失敗の理由（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"; echo '```'
"$NODE_BIN" -e '
const s=require("fs").readFileSync(process.argv[1],"utf8");const line=s.split("\n").filter(l=>l.includes("thread-main-exec")).pop()||"";
let j;try{j=JSON.parse(line)}catch(e){console.log("JSON で読めない: "+line.slice(-1500));process.exit(0)}
const e=String(j.error||"");const parts=e.split("\n");
console.log("error の長さ "+e.length+" 字・"+parts.length+" 行");
parts.forEach((p,i)=>{ if(i===0){console.log("[1行目の末尾] "+p.slice(-300))} else console.log("["+(i+1)+"] "+p.slice(0,400)) });
for(const k of Object.keys(j)) if(k!=="error") console.log(k+": "+JSON.stringify(j[k]).slice(0,300));' "$L/publish-jal-tour-oneshot.log" 2>&1 | clean | tail -60
echo '```'
echo; echo "## post-via-playwright の直近のログ（12:00 前後）"; echo '```'
for f in "$L"/post-via-playwright*.log "$L"/run-publish*.log; do [ -f "$f" ] || continue; echo "--- $(basename "$f")"; grep -a '2026-11-17' "$f" | tail -20 | cut -c1-300 | clean; done
echo '```'
echo; echo "## 直近 1 日に出た投稿（返信以外）"; echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);const t0=Date.now()-36*3600e3;
rows.filter(e=>e&&e.kind!=="comment"&&(e.x_tweet_id||e.tweet_id)&&Date.parse(e.posted_at||"")>=t0).forEach(e=>console.log(e.id+" "+e.posted_at+" "+(e.x_tweet_id||e.tweet_id)))' "$W/data/post_queue.json" 2>&1
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
head -12 "$OUT" | tail -8 | cut -c1-160
exit 0
