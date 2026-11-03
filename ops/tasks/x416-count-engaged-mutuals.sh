#!/bin/bash
# x416（2026-11-04・読むだけ・$0）: 利用者が「反応をくれた人も見直す」を選んだ。
# follow-balance が「反応をくれた人」として守っている相互を、認証済みか・最後の反応がいつかで分けて数える。
# **何も書き換えない・押さない。ハンドルは出さない（件数と項目名だけ）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts/follow-balance.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x416-count-engaged-mutuals.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 「反応をくれた人」を数える（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 反応の記録の場所と読み方（コード）"; echo '```'
grep -nE 'ENGAGED|function harvest|harvest\(' "$S" | head -8 | cut -c1-200
n="$(grep -n 'function harvest' "$S" | head -1 | cut -d: -f1)"; [ -n "$n" ] && sed -n "${n},$((n+22))p" "$S" | cut -c1-200
echo '```'
echo; echo "## 数"; echo '```'
cd "$W" && ENG="$(grep -oE 'ENGAGED *= *[^;]+' "$S" | head -1)" "$NODE_BIN" -e '
const fs=require("fs"),path=require("path");const rd=(f,d)=>{try{return JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){return d}};
const low=h=>String(h||"").replace(/^@/,"").toLowerCase();
console.log("ENGAGED の定義:",process.env.ENG||"(見つからない)");
const m=String(process.env.ENG||"").match(/["\x27`]([^"\x27`]+\.json)["\x27`]/g)||[];
const files=m.map(x=>x.slice(1,-1)).map(f=>f.startsWith("/")?f:path.join("data",path.basename(f)));
console.log("読むファイル:",files.join(", ")||"(無し)");
const eng=new Map();
for(const f of files){const j=rd(f,null);if(!j){console.log(" 読めない:",f);continue}
 const ents=Array.isArray(j)?j.map(x=>[typeof x==="string"?x:(x.handle||x.user||x.screen_name||""),x]):Object.entries(j);
 const first=ents[0]&&ents[0][1];console.log(" ",f,ents.length,"件・項目:",first&&typeof first==="object"?Object.keys(first).join(","):typeof first);
 for(const [h,v] of ents){const k=low(h);if(!k)continue;let t=null;if(v&&typeof v==="object"){for(const key of ["last_at","at","ts","last","updated_at","date","time"]){if(v[key]){t=Date.parse(v[key]);break}} if(!t&&Array.isArray(v.events)&&v.events.length){t=Math.max(...v.events.map(e=>Date.parse(e.at||e.ts||e)||0))}}
  const prev=eng.get(k);eng.set(k,Math.max(prev||0,t||0)||null);}
}
const L=rd("data/follow-balance-lists.json",{});const fol=new Set((L.following||[]).map(low)),fer=new Set((L.followers||[]).map(low));
const notF=new Set((rd("data/follow-balance-notfollowing.json",[])||[]).map(low));
const mutual=[...fol].filter(h=>fer.has(h)&&!notF.has(h));
const ver=new Set();const B=rd("data/badge-followback-state.json",{});(B.processed||[]).forEach(h=>ver.add(low(h)));(B.followed_back||[]).forEach(x=>ver.add(low(x.handle||x)));
const now=Date.now();const bucket=t=>t?((now-t)/864e5<30?"30日以内":(now-t)/864e5<90?"30〜90日":"90日より前"):"日付なし";
const c={eng_mutual:0,ver:0,unv:0};const by={"30日以内":0,"30〜90日":0,"90日より前":0,"日付なし":0};
for(const h of mutual){if(!eng.has(h))continue;c.eng_mutual++;if(ver.has(h)){c.ver++;continue}c.unv++;by[bucket(eng.get(h))]++;}
console.log("相互",mutual.length,"件のうち 反応の記録あり",c.eng_mutual,"件 → 認証済み",c.ver,"／ **未認証",c.unv,"**");
console.log("未認証で反応の記録ありの、最後の反応:",JSON.stringify(by));
' 2>&1
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
