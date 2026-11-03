#!/bin/bash
# x406（2026-11-03・読むだけ・$0）: 利用者「外せる相互の数を先に数える」。
# 相互（フォロー中 ∩ フォロワー）を、認証済みか・反応をくれたか・ホワイトリストか・いつフォローしたかで分けて数える。
# **何も書き換えない・押さない。ハンドルは出さない。** 認証済みの見分けは手元の記録（badge-followback・followed.json・reply-followers.json）だけ。
set -uo pipefail
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts/follow-balance.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x406-count-removable-mutuals.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 外せる相互を数える（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## follow-balance が「反応」をどこから読んでいるか"; echo '```'
grep -nE 'react|反応|interact|liked|replied' "$S" | head -15 | cut -c1-200
echo '```'
echo; echo "## 数"; echo '```'
cd "$W" && "$NODE_BIN" -e '
const fs=require("fs"),D="data/";const rd=(f,d)=>{try{return JSON.parse(fs.readFileSync(D+f,"utf8"))}catch(e){return d}};
const low=(h)=>String(h||"").replace(/^@/,"").toLowerCase();
const L=rd("follow-balance-lists.json",{});const fol=new Set((L.following||[]).map(low)),fer=new Set((L.followers||[]).map(low));
const notF=new Set((rd("follow-balance-notfollowing.json",[])||[]).map(low));
const mutual=[...fol].filter(h=>fer.has(h)&&!notF.has(h));
console.log("一覧の時刻:",L.at,"／ フォロー中(一覧)",fol.size,"・フォロワー(一覧)",fer.size,"・覚えている未フォロー",notF.size,"→ 相互",mutual.length);
// 認証済み
const ver=new Set();const B=rd("badge-followback-state.json",{});
(B.processed||[]).forEach(h=>ver.add(low(h)));(B.followed_back||[]).forEach(x=>ver.add(low(x.handle||x)));
const FD=rd("followed.json",{});const fdE=Array.isArray(FD)?FD:Object.entries(FD).map(([k,v])=>Object.assign({handle:k},v||{}));
const fdMap=new Map();for(const e of fdE){const h=low(e.handle||e.screen_name||e.user);if(!h)continue;fdMap.set(h,e);if(e.verified===true)ver.add(h);}
const RF=rd("reply-followers.json",{});for(const [k,v] of Object.entries(RF)){if(v&&v.verified===true)ver.add(low(k));}
// ホワイトリスト
const wl=new Set();for(const f of ["mutual-prune-whitelist.json","unfollow-whitelist.json","whitelist.json"]){const j=rd(f,[]);(Array.isArray(j)?j:Object.keys(j)).forEach(h=>wl.add(low(typeof h==="string"?h:h.handle)));}
console.log("認証済みと分かっている人(手元の記録)",ver.size,"・ホワイトリスト",wl.size,"・followed.json",fdMap.size,"件（項目: "+(fdE[0]?Object.keys(fdE[0]).join(","):"-")+"）");
// 反応: 候補ファイルを探す
let react=new Set(),rsrc="(見つからない)";
for(const f of fs.readdirSync("data")){if(!/react|interact|engag/i.test(f)||!f.endsWith(".json"))continue;const j=rd(f,null);if(!j)continue;const ks=Array.isArray(j)?j.map(x=>typeof x==="string"?x:(x.handle||x.user||"")):Object.keys(j);ks.forEach(h=>react.add(low(h)));rsrc=(rsrc==="(見つからない)"?"":rsrc+",")+f+"("+ks.length+")";}
console.log("反応の記録:",rsrc,"→",react.size,"人");
const now=Date.now();
const age=(h)=>{const e=fdMap.get(h)||RF[h]||RF["@"+h];const t=e&&(e.followed_at||e.at||e.ts);return t?(now-Date.parse(t))/864e5:null;};
const cat={ver:0,wl:0,react:0,unv_noreact:0};const ages={"7日未満":0,"7〜30日":0,"30日以上":0,"不明":0};
for(const h of mutual){if(ver.has(h)){cat.ver++;continue}if(wl.has(h)){cat.wl++;continue}if(react.has(h)){cat.react++;continue}cat.unv_noreact++;const a=age(h);ages[a===null?"不明":a<7?"7日未満":a<30?"7〜30日":"30日以上"]++;}
console.log("相互の内訳: 認証済み",cat.ver,"／ ホワイトリスト",cat.wl,"／ 反応をくれた",cat.react,"／ **未認証・反応なし",cat.unv_noreact,"**");
console.log("未認証・反応なしの、フォローしてからの日数:",JSON.stringify(ages));
const mp=rd("mutual-prune-state.json",{});console.log("mutual-prune がこれまでに外した:",Object.keys(mp).length,"件");
' 2>&1
echo '```'
echo "**注意: 認証済みは手元の記録で分かっている人だけ。記録に無い認証済みは「未認証」側に入る。外す前にプロフィールで確かめる**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
