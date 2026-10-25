#!/bin/bash
# **10/12 からのフォロワー増（346 → 618）の内訳を、Mac のフォロー記録から数える（x344）。読むだけ。費用 $0。**
# 利用者の問い「10/18 の投稿でフォロワーが 73 人増えたのはなぜか・再現性はあるか」。
# 投稿の表示は 355 回・読者 1 人。10/12 に青バッジ＋フォローの的を認証済みへ寄せた（x278）。**フォロバ由来か、投稿由来か**を分けたい。
# **外さない・フォローしない・画面は撮らない。ハンドルは出さない（件数だけ）。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/followback-breakdown.md"
{
echo "# フォロワー増の内訳（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"),path=require("path");const D=process.argv[1];
const files=fs.readdirSync(D).filter(f=>f.endsWith(".json")&&/follow|engaged|reply-followers|competitor|hashtag/i.test(f));
const day=s=>s?String(s).slice(0,10):null;
for(const f of files){
  let j;try{j=JSON.parse(fs.readFileSync(path.join(D,f),"utf8"))}catch(e){continue}
  let rows=Array.isArray(j)?j:(j&&typeof j==="object"?Object.values(j):[]);
  rows=rows.filter(r=>r&&typeof r==="object");
  if(rows.length<5)continue;
  const keys={};rows.slice(0,200).forEach(r=>Object.keys(r).forEach(k=>keys[k]=(keys[k]||0)+1));
  const fk=["followed_at","followedAt","at","ts","date"].find(k=>keys[k]);
  console.log("--- "+f+"（"+rows.length+" 件）項目: "+Object.keys(keys).slice(0,18).join(","));
  if(!fk)continue;
  const since=rows.filter(r=>day(r[fk])>="2026-10-12");
  const by={};since.forEach(r=>{const d=day(r[fk]);by[d]=by[d]||{n:0,fb:0,no:0,ver:0,src:{}};by[d].n++;
    const st=r.followback_status||r.followback||r.status;if(st==="yes"||st===true||st==="followed_back")by[d].fb++;if(st==="no")by[d].no++;
    if(r.verified===true)by[d].ver++;const s=r.source||r.via||r.from||"?";by[d].src[s]=(by[d].src[s]||0)+1;});
  const tot=since.length,fb=since.filter(r=>{const st=r.followback_status||r.followback||r.status;return st==="yes"||st===true||st==="followed_back"}).length;
  console.log("  10/12 以降に記録 "+tot+" 件 / フォロバあり "+fb+" 件 / 認証済み "+since.filter(r=>r.verified===true).length+" 件（基準の項目: "+fk+"）");
  Object.keys(by).sort().forEach(d=>console.log("   "+d+" 記録 "+by[d].n+" / フォロバ "+by[d].fb+" / 返さず "+by[d].no+" / 認証済み "+by[d].ver+" / 出どころ "+JSON.stringify(by[d].src)));
}' "$W/data" 2>&1 | head -120
echo '```'
echo "**読んだだけ。ハンドルは出していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x344 / $(basename "$OUT")"
