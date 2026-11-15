#!/bin/bash
# **読むだけ・$0。** 押す係の試し運転（com.dailyhack.x-action-dispatcher・DRY_RUN=1）の記録と、押す直前の記録（shadow）を読む。第 1 段（x477・x480・x481）の後のフォロー・解除の回数・30 分の最大・最小の間隔も出す（x493）。利用者が 11/14 にダイアログで「明日の夕方に試し運転の記録を読んで見せる」を選んだ。
set -uo pipefail
W="$HOME/.openclaw/workspace"; D="$W/data"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x493-read-dispatcher-dry.md"
{
echo "# 押す係の試し運転を読む（$(date '+%F %T') JST・読むだけ・\$0）"
echo; echo "## 0. ジョブ"; echo '```'
launchctl print "gui/$(id -u)/com.dailyhack.x-action-dispatcher" 2>/dev/null | grep -E '^\s+(state|runs|last exit code) ' | sed 's/^/  /' || echo "  載っていない"
echo '```'
echo; echo "## 1. 試し運転の記録（x-action-dispatcher-dry.jsonl）"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs");const f=process.argv[1];let L=[];try{L=fs.readFileSync(f,"utf8").trim().split("\n").filter(Boolean).map(x=>{try{return JSON.parse(x)}catch(e){return null}}).filter(Boolean)}catch(e){console.log("  記録なし: "+e.message);process.exit(0)}
console.log("  行数 "+L.length+" ／ 最初 "+(L[0]&&(L[0].at||L[0].ts))+" ／ 最後 "+(L[L.length-1]&&(L[L.length-1].at||L[L.length-1].ts)));
const by={};for(const r of L){const k=(r.decision||r.action||r.kind||r.type||"?")+"";by[k]=(by[k]||0)+1}console.log("  内訳 "+JSON.stringify(by));
const hours={};for(const r of L){const t=Date.parse(r.at||r.ts);if(!t)continue;const h=new Date(t+9*3600e3).getUTCHours();hours[h]=(hours[h]||0)+1}console.log("  時刻（JST）ごと "+JSON.stringify(hours));
console.log("  --- 直近 15 行（ハンドルは伏せる）");for(const r of L.slice(-15))console.log("  "+JSON.stringify(r).replace(/@?(?!heng_ji31590\b)[A-Za-z0-9_]{4,15}(?=")/g,m=>/^\d|^(follow|unfollow|like|reply|tweet|skip|pick|dry|ok|true|false|null|badge|replier|commenter|competitor|hashtag|decision|action|kind|type|reason|source|at|ts)$/i.test(m)?m:"<伏せ>").slice(0,300));
' "$D/x-action-dispatcher-dry.jsonl"
echo '```'
echo; echo "## 2. 押す直前の記録（x-action-shadow.jsonl）"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs");let L=[];try{L=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").filter(Boolean).map(x=>{try{return JSON.parse(x)}catch(e){return null}}).filter(Boolean)}catch(e){console.log("  記録なし: "+e.message);process.exit(0)}
const since=Date.now()-24*3600e3;const R=L.filter(r=>Date.parse(r.at||r.ts)>=since);
console.log("  全 "+L.length+" 行 ／ 直近 24 時間 "+R.length+" 行");
const kinds={};for(const r of R){const k=r.kind||r.type||"?";(kinds[k]=kinds[k]||[]).push(Date.parse(r.at||r.ts))}
for(const[k,ts]of Object.entries(kinds)){ts.sort((a,b)=>a-b);let mx=0,mn=Infinity;for(let i=0;i<ts.length;i++){let j=i;while(j<ts.length&&ts[j]-ts[i]<1800e3)j++;mx=Math.max(mx,j-i);if(i)mn=Math.min(mn,(ts[i]-ts[i-1])/1000)}
 const hs={};for(const t of ts){const h=new Date(t+9*3600e3).getUTCHours();hs[h]=(hs[h]||0)+1}
 console.log("  "+k+": 24時間で "+ts.length+" 回 ／ 30分で最大 "+mx+" 回 ／ 最小の間隔 "+(mn===Infinity?"-":Math.round(mn)+" 秒")+" ／ 時刻 "+JSON.stringify(hs))}
' "$D/x-action-shadow.jsonl"
echo '```'
echo; echo "## 3. 台帳（x-action-ledger.json）の直近 24 時間"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs");let j={};try{j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"))}catch(e){console.log("  読めない: "+e.message);process.exit(0)}
const since=Date.now()-24*3600e3;const ev=(Array.isArray(j)?j:(j.events||j.ledger||Object.entries(j).flatMap(([k,v])=>Array.isArray(v)?v.map(t=>({kind:k,at:t})):[])));
const by={};for(const e of ev){const t=typeof e==="number"?e:Date.parse(e.at||e.ts||e.t);if(!(t>=since))continue;const k=e.kind||e.type||"?";(by[k]=by[k]||[]).push(t)}
for(const[k,ts]of Object.entries(by)){ts.sort((a,b)=>a-b);let mx=0,mn=Infinity;for(let i=0;i<ts.length;i++){let jj=i;while(jj<ts.length&&ts[jj]-ts[i]<1800e3)jj++;mx=Math.max(mx,jj-i);if(i)mn=Math.min(mn,(ts[i]-ts[i-1])/1000)}console.log("  "+k+": "+ts.length+" 回 ／ 30分で最大 "+mx+" ／ 最小の間隔 "+(mn===Infinity?"-":Math.round(mn)+" 秒"))}
' "$D/x-action-ledger.json"
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
echo "押す係の試し運転を読んだ / $(basename "$OUT")"
