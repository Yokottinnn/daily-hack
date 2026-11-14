#!/bin/bash
# x476（2026-11-14・読むだけ・$0）: X にスパム（プラットフォーム操作）のラベルを付けられた。直近 8 日の X への操作を、ジョブのログから
# 日ごと・種類ごと・ジョブごとに数え、30 分あたりの最大と、操作の時刻の偏りを出す。いま載っている X のジョブの一覧も出す。何も変えない。ハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x476-read-spam-label-causes.md"
{
echo "# スパムのラベルの原因を読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 1〜4. ログから数えた操作"
"$NODE_BIN" - "$L" <<'JS'
const fs=require("fs"),path=require("path");const L=process.argv[2];
const since=Date.now()-8*86400000;
// 種類ごとの判定（行の中身で決める）
const R=[
 ["unfollow",/✂.*外れた|unfollowed|フォロー解除した|アンフォローした|unfollow ok|=> unfollowed/i],
 ["follow",/followed back|follow @\S+: followed|: ✅$|followed @|フォローした(?!数)|follow ok/i],
 ["reply",/replied|返信した|reply posted|posted reply|リプライした|✅ reply/i],
 ["like",/liked|いいねした|like ok/i],
 ["post",/tweet posted|投稿した|x_tweet_id/i],
];
const per={},perJob={},times={follow:[],unfollow:[],reply:[],like:[]},hours={};
for(const f of fs.readdirSync(L).filter(f=>f.endsWith(".log"))){
  let s;try{const st=fs.statSync(path.join(L,f));if(st.mtimeMs<since)continue;s=fs.readFileSync(path.join(L,f),"utf8")}catch(e){continue}
  const seen=new Set();
  for(const line of s.split("\n")){
    const m=line.match(/^\[(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z?)\]/);if(!m)continue;
    if(seen.has(line))continue;seen.add(line);
    let t=Date.parse(m[1].endsWith("Z")?m[1]:m[1]+"Z");if(!(t>=since))continue;
    for(const[k,re]of R){if(re.test(line)){
      const d=new Date(t+9*3600000).toISOString().slice(0,10);
      per[d]=per[d]||{};per[d][k]=(per[d][k]||0)+1;
      const j=f.replace(/\.log$/,"");perJob[j]=perJob[j]||{};perJob[j][k]=(perJob[j][k]||0)+1;
      if(times[k])times[k].push(t);
      const h=new Date(t+9*3600000).getUTCHours();hours[h]=(hours[h]||0)+1;break}}
  }
}
const K=["follow","unfollow","reply","like","post"];
console.log("\n### 1. 日ごと（JST）\n```\n日付        "+K.join("  "));
for(const d of Object.keys(per).sort())console.log(d+"  "+K.map(k=>String(per[d][k]||0).padStart(k.length)).join("  "));
console.log("```\n\n### 2. ジョブごと（8 日の合計）\n```");
for(const[j,v]of Object.entries(perJob).sort((a,b)=>Object.values(b[1]).reduce((x,y)=>x+y,0)-Object.values(a[1]).reduce((x,y)=>x+y,0)))console.log(j+": "+K.filter(k=>v[k]).map(k=>k+"="+v[k]).join(" "));
console.log("```\n\n### 3. 30 分あたりの最大（種類ごと・その時刻 JST）と、前の回との間隔の最小\n```");
for(const k of Object.keys(times)){const xs=times[k].sort((a,b)=>a-b);let best=0,at=0,j=0,gap=Infinity;
  for(let i=0;i<xs.length;i++){while(xs[i]-xs[j]>1800000)j++;if(i-j+1>best){best=i-j+1;at=xs[j]}if(i)gap=Math.min(gap,xs[i]-xs[i-1])}
  console.log(k+": 30分で最大 "+best+" 回（"+(at?new Date(at+9*3600000).toISOString().slice(5,16).replace("T"," "):"-")+"）／最小の間隔 "+(gap===Infinity?"-":Math.round(gap/1000)+" 秒")+"／8日で "+xs.length+" 回")}
const fu=times.follow.concat(times.unfollow).sort((a,b)=>a-b);let b2=0,a2=0,j2=0;for(let i=0;i<fu.length;i++){while(fu[i]-fu[j2]>1800000)j2++;if(i-j2+1>b2){b2=i-j2+1;a2=fu[j2]}}
console.log("follow+unfollow: 30分で最大 "+b2+" 回（"+(a2?new Date(a2+9*3600000).toISOString().slice(5,16).replace("T"," "):"-")+"）");
console.log("```\n\n### 4. 時刻（JST）ごとの操作の数（8 日の合計）\n```");
for(let h=0;h<24;h++)console.log(String(h).padStart(2)+"時 "+"#".repeat(Math.min(80,Math.round((hours[h]||0)/2)))+" "+(hours[h]||0));
console.log("```");
JS
echo; echo "## 5. いま載っている X のジョブ（launchctl list の ai.openclaw.*）"; echo '```'
launchctl list 2>/dev/null | awk '$3 ~ /^ai\.openclaw\./ {print $3, "pid=" $1, "last=" $2}' | sort
echo '```'
echo; echo "## 6. 鍵（認証）以外で、X から返っている警告（直近 8 日のログ）"; echo '```'
grep -hiE 'automated|suspicious|rate limit|429|spam|制限|Something went wrong|ロック' "$L"/*.log 2>/dev/null | grep -E '^\[2026-11-(0[6-9]|1[0-4])' | awk '!s[$0]++' | tail -25 | cut -c1-200 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
} > "$OUT" 2>&1
grep -E '^follow\+unfollow|^follow:|^unfollow:' "$OUT" | head -3 | cut -c1-140
exit 0
