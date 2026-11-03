#!/bin/bash
# x417（2026-11-04・読むだけ・$0）: x416 の数え直し。follow-balance の「反応をくれた人」は data/reply-followers.json（ENGAGED）にある人。
# 相互のうちこの記録にいる人を、認証済みか・どこから来たか（source）・フォローしてからの日数・フォロバの状態で分けて数える。
# **何も書き換えない・押さない。ハンドルは出さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x417-count-engaged-mutuals-2.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 「反応をくれた人」を数え直す（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo '```'
cd "$W" && "$NODE_BIN" -e '
const fs=require("fs");const rd=(f,d)=>{try{return JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){return d}};
const low=h=>String(h||"").replace(/^@/,"").toLowerCase();
const RF=rd("data/reply-followers.json",{});const rf=new Map(Object.entries(RF).map(([k,v])=>[low(k),v||{}]));
console.log("reply-followers.json:",rf.size,"件");
const L=rd("data/follow-balance-lists.json",{});const fol=new Set((L.following||[]).map(low)),fer=new Set((L.followers||[]).map(low));
const notF=new Set((rd("data/follow-balance-notfollowing.json",[])||[]).map(low));
const mutual=[...fol].filter(h=>fer.has(h)&&!notF.has(h));
const ver=new Set();const B=rd("data/badge-followback-state.json",{});(B.processed||[]).forEach(h=>ver.add(low(h)));(B.followed_back||[]).forEach(x=>ver.add(low(x.handle||x)));
for(const [k,v] of rf) if(v.verified===true) ver.add(k);
const now=Date.now();const age=v=>{const t=Date.parse(v.followed_at||v.at||"");return isFinite(t)?(now-t)/864e5:null};
const c={inRF:0,ver:0,unv:0};const src={},ages={"7日未満":0,"7〜30日":0,"30日以上":0,"不明":0},fb={};
for(const h of mutual){const v=rf.get(h);if(!v)continue;c.inRF++;if(ver.has(h)){c.ver++;continue}c.unv++;
 src[v.source||"(なし)"]=(src[v.source||"(なし)"]||0)+1;const a=age(v);ages[a===null?"不明":a<7?"7日未満":a<30?"7〜30日":"30日以上"]++;
 const s=v.followback_status||(v.follows_back===true?"yes":v.follows_back===false?"no":"(なし)");fb[s]=(fb[s]||0)+1;}
console.log("相互",mutual.length,"件のうち reply-followers にいる人",c.inRF,"件 → 認証済み",c.ver,"／ **未認証",c.unv,"**");
console.log("未認証の内訳 どこから来たか:",JSON.stringify(src));
console.log("未認証の内訳 フォローしてからの日数:",JSON.stringify(ages));
console.log("未認証の内訳 フォロバの記録:",JSON.stringify(fb));
const keys=new Set();for(const v of rf.values())Object.keys(v).forEach(k=>keys.add(k));console.log("reply-followers の項目:",[...keys].join(","));
' 2>&1
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
