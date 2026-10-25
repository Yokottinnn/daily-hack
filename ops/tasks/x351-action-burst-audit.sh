#!/bin/bash
# **シャドウバン対策の下調べ（x351）。X の各種アクションが 30 分あたり何回、どれだけ固まって出ているかを読む。読むだけ・LLM 不使用・$0。**
# 利用者（2026-10-26）「大至急…シャドウバンされないようにして／1日の中でも必ず間隔をおいて各種アクションをするようにして」。
# 目安（@SakuyaAkiV の図）: 返信＋投稿＋リポスト 25 回/30 分・いいね 20 回/30 分・フォロー 8 回/30 分・ハッシュタグ 2 個まで。
set -uo pipefail
W="$HOME/.openclaw/workspace"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x351-action-burst.md"
{
echo "# X のアクションの固まり具合（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 1. 直近 3 日、30 分ごとの最大回数と、1 分以内に続けて出た回数"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs");const W=process.argv[1];const since=Date.now()-3*864e5;const ev=[];
const jst=t=>new Date(t+9*36e5).toISOString().slice(0,16).replace("T"," ");
try{const rf=JSON.parse(fs.readFileSync(W+"/data/reply-followers.json","utf8"));for(const [h,r] of Object.entries(rf)){if(r.followed_at)ev.push(["follow",Date.parse(r.followed_at),r.source||""]);if(r.unfollowed_at)ev.push(["unfollow",Date.parse(r.unfollowed_at),r.unfollow_source||""]);}}catch(e){console.log("reply-followers.json 読めない "+e.message)}
for(const qf of ["post_queue.json","data/post_queue.json"]){try{const q=JSON.parse(fs.readFileSync(W+"/"+qf,"utf8"));const arr=Array.isArray(q)?q:(q.queue||q.items||Object.values(q));for(const e of arr){if(!e||!e.posted_at||!(e.x_tweet_id||e.tweet_id))continue;const k=String(e.kind||e.type||e.id||"");ev.push([/comment|reply/i.test(k)?"reply":"post",Date.parse(e.posted_at),k.slice(0,20)])}console.log("キュー: "+qf);break}catch(e){}}
const E=ev.filter(e=>e[1]>=since&&isFinite(e[1])).sort((a,b)=>a[1]-b[1]);
const types=[...new Set(E.map(e=>e[0]))];
for(const t of types){const xs=E.filter(e=>e[0]===t);const b={};xs.forEach(e=>{const k=Math.floor(e[1]/18e5);b[k]=(b[k]||0)+1});
 const top=Object.entries(b).sort((a,c)=>c[1]-a[1]).slice(0,3).map(([k,n])=>jst(k*18e5)+" に "+n+" 回");
 let burst=0;for(let i=1;i<xs.length;i++)if(xs[i][1]-xs[i-1][1]<60e3)burst++;
 const gaps=xs.slice(1).map((e,i)=>(e[1]-xs[i][1])/1e3).sort((a,c)=>a-c);const med=gaps.length?gaps[Math.floor(gaps.length/2)]:0;
 console.log(t+": 3 日で "+xs.length+" 回 ／ 30 分の最大: "+top.join("、")+" ／ 前の回から 1 分以内: "+burst+" 回 ／ 間隔の中央値 "+Math.round(med)+" 秒");
 const src={};xs.forEach(e=>src[e[2]]=(src[e[2]]||0)+1);console.log("   内訳: "+Object.entries(src).sort((a,c)=>c[1]-a[1]).slice(0,6).map(([k,n])=>(k||"不明")+" "+n).join(" / "));}
const all={};E.filter(e=>e[0]==="reply"||e[0]==="post").forEach(e=>{const k=Math.floor(e[1]/18e5);all[k]=(all[k]||0)+1});
console.log("返信＋投稿の 30 分最大: "+Math.max(0,...Object.values(all)));
' "$W" 2>&1
echo '```'
echo; echo "## 2. X に触る launchd ジョブと起動の間隔"; echo '```'
for P in "$HOME"/Library/LaunchAgents/ai.openclaw.*.plist; do L=$(basename "$P" .plist)
  S=$(plutil -p "$P" 2>/dev/null | grep -A30 -E 'StartCalendarInterval|StartInterval' | grep -E 'StartInterval|Hour|Minute' | tr -d ' ' | tr '\n' ' ' | cut -c1-160)
  A=$(plutil -p "$P" 2>/dev/null | grep -E '\.js"|\.sh"' | head -2 | sed -E 's/.*\/(scripts\/)?//; s/"//g' | tr '\n' ' ')
  echo "$L | $A| $S"; done 2>/dev/null | grep -iE 'follow|comment|reply|like|post|publish|prune|balance|quote|qt|hashtag|repost|warmup|badge' 
echo '```'
echo; echo "## 3. いいね・リポストを押しているスクリプト"; echo '```'
grep -lE '"like"|data-testid="like"|testid=like|\[data-testid=\\?"like|retweetConfirm|unretweet' "$W"/scripts/*.js 2>/dev/null | xargs -n1 basename 2>/dev/null
echo '```'
echo "**読んだだけ。押していない。LLM を呼んでいない（\$0／回）。**"
} > "$OUT" 2>&1
echo "x351 / $(basename "$OUT")"
