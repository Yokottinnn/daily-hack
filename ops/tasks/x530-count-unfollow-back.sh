#!/bin/bash
# x530（2026-11-21・読むだけ・$0）: 外し返しが多いのかを数える（利用者「相互の解除を外す件はそもそも外し返しが多いのかどうかも合わせて教えて」）。
#  mutual-prune が外した相互（mutual-prune-state.json・外した時点では相手はこちらをフォローしていた）のうち、
#  いまのフォロワーの一覧（follow-balance-lists.json の followers・follow-balance が 20:24 に読んだもの）にもう居ない人を「外し返した」と数える。
#  外した日ごと・経過日数ごと・11/16 の前後で分ける。**数だけ出す。ハンドルは出さない。**
#  あわせて follow-handle.js の「相手のフォロワー数」のふるい分け（80〜115 行目）を読む（次の変更の下調べ）。
#  x528 のレポートの ③ にファイルのキー（他人のハンドル）が出ていたので、伏せた版で上書きする。
# 何も押さない。LLM 不使用。
set -uo pipefail
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
RD="${OPS_REPORT_DIR:-/tmp}"; OUT="$RD/x530-count-unfollow-back.md"
# x528 の ③ を伏せる（ハンドルが出ていた行を消す）
if [ -f "$RD/x528-read-follow-filters-and-unfollow-back.md" ]; then
  perl -i -ne 'print unless /^   \.[A-Za-z0-9_]{2,15}: (オブジェクト|配列)/ && !/^   \.(processed|followed_back|initialized|at|me|following|followers|secs|snapshots|version|target|deadline|baseline_count|baseline_date|last_run|consec_behind|last_pace_actual|phase|started_at|target_ratio_phase_a|current_ratio|unfollow_log|tier_snapshot|halt_flags|description|last_updated|whitelist|notes|timestamp|total_inactive):/' "$RD/x528-read-follow-filters-and-unfollow-back.md"
fi
{
echo "# 外し返しを数える（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 1. mutual-prune が外した相互のうち、いまフォロワーに居ない人"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs"),D=process.argv[1];
const st=JSON.parse(fs.readFileSync(D+"/mutual-prune-state.json","utf8"));
const L=JSON.parse(fs.readFileSync(D+"/follow-balance-lists.json","utf8"));
const fol=new Set((L.followers||[]).map(x=>String(typeof x==="string"?x:(x.handle||x.screen_name||"")).toLowerCase().replace(/^@/,"")));
const ing=new Set((L.following||[]).map(x=>String(typeof x==="string"?x:(x.handle||x.screen_name||"")).toLowerCase().replace(/^@/,"")));
console.log("フォロワーの一覧: "+fol.size+" 件（読んだ時刻 "+L.at+"）・フォロー中の一覧: "+ing.size+" 件");
const rows=Object.entries(st).filter(([k,v])=>v&&typeof v==="object"&&v.unfollowed_at);
const now=Date.now();let tot=0,gone=0,refol=0;const byDay={},byAge={"0-1日":[0,0],"2-3日":[0,0],"4-7日":[0,0],"8-14日":[0,0],"15日以上":[0,0]};const byWhy={};
const pre=[0,0],post=[0,0];
for(const[k,v]of rows){const h=k.toLowerCase();const t=Date.parse(v.unfollowed_at);if(!isFinite(t))continue;tot++;const g=!fol.has(h);if(g)gone++;if(ing.has(h))refol++;
 const d=new Date(t+9*3600e3).toISOString().slice(0,10);byDay[d]=byDay[d]||[0,0];byDay[d][0]++;if(g)byDay[d][1]++;
 const a=(now-t)/864e5;const b=a<2?"0-1日":a<4?"2-3日":a<8?"4-7日":a<15?"8-14日":"15日以上";byAge[b][0]++;if(g)byAge[b][1]++;
 const w=String(v.why||"").slice(0,24);byWhy[w]=byWhy[w]||[0,0];byWhy[w][0]++;if(g)byWhy[w][1]++;
 const P=d>="2026-11-16"?post:pre;P[0]++;if(g)P[1]++;}
const pc=(a,b)=>a?Math.round(b/a*1000)/10+"%":"-";
console.log("外した相互: "+tot+" 人 ／ いまフォロワーに居ない: "+gone+" 人（"+pc(tot,gone)+"）／ こちらがまたフォローしている: "+refol+" 人");
console.log("11/16 より前に外した: "+pre[0]+" 人 → 居ない "+pre[1]+"（"+pc(pre[0],pre[1])+"）");
console.log("11/16 から外した: "+post[0]+" 人 → 居ない "+post[1]+"（"+pc(post[0],post[1])+"）");
console.log("-- 外してからの日数ごと（外した人 / 居ない人）");for(const[b,[a,g]]of Object.entries(byAge))console.log("  "+b+": "+a+" / "+g+"（"+pc(a,g)+"）");
console.log("-- 外した日ごと（直近 21 日）");for(const d of Object.keys(byDay).sort().slice(-21))console.log("  "+d+": "+byDay[d][0]+" / "+byDay[d][1]);
console.log("-- 外した理由ごと");for(const[w,[a,g]]of Object.entries(byWhy).sort((x,y)=>y[1][0]-x[1][0]).slice(0,8))console.log("  "+(w||"(なし)")+": "+a+" / "+g+"（"+pc(a,g)+"）");
' "$D" 2>&1 | perl -pe 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
echo; echo "## 2. 比べるための数: こちらが外していない相互が、自然に外れる割合"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs"),D=process.argv[1];
try{const p=JSON.parse(fs.readFileSync(D+"/follow-balance-followers-prev.json","utf8"));const L=JSON.parse(fs.readFileSync(D+"/follow-balance-lists.json","utf8"));
const n=x=>String(typeof x==="string"?x:(x.handle||x.screen_name||"")).toLowerCase().replace(/^@/,"");
const a=new Set((p.followers||[]).map(n)),b=new Set((L.followers||[]).map(n));let lost=0,gain=0;for(const h of a)if(!b.has(h))lost++;for(const h of b)if(!a.has(h))gain++;
console.log("前回の一覧 "+p.at+"（"+a.size+" 件）→ 今回 "+L.at+"（"+b.size+" 件）: 居なくなった "+lost+" ／ 新しく増えた "+gain);}catch(e){console.log("読めない "+e.message.slice(0,80))}' "$D" 2>&1
echo '```'
echo; echo "## 3. follow-handle.js の相手のフォロワー数のふるい分け（80〜115 行目）"; echo '```'
sed -n 80,115p "$S/follow-handle.js" 2>&1 | cut -c1-200 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo "-- minFollowers を決めている行"; grep -nE 'minFollowers' "$S/follow-handle.js" | head -6 | cut -c1-200
echo '```'
echo; echo "**読むだけ。数だけを出した（ハンドルは出していない）。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '外した相互:|11/16' "$OUT" | head -3
exit 0
