#!/bin/bash
# x513（2026-11-16・読むだけ・$0）: 1 日の上限を外し人の動き方で散らした（x500〜x502、11/15 21:31 から）24 時間の実数を読む。
# 間隔の決まりの台帳・押す直前の記録（出どころ）・follow-handle の [x502] の行・その日の動き方・プロフィールのヘッダーの数。他人のハンドルは出さない。何も押さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; LIB="$W/lib"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x513-measure-24h-no-cap.md"
{
echo "# 上限なしの 24 時間の実数（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 間隔の決まりの台帳（11/15 21:31〜いま）"; echo '```'
"$NODE_BIN" -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const t0=Date.parse("2026-11-15T12:31:00Z"),now=Date.now();
const jst=t=>new Date(t+9*3600e3).toISOString().slice(5,16).replace("T"," ");
for(const k of ["follow","unfollow","like","tweet"]){const xs=(j[k]||[]).filter(t=>t>=t0).sort((a,b)=>a-b);
 const g=xs.slice(1).map((t,i)=>(t-xs[i])/60000);const mn=g.length?Math.min(...g).toFixed(1):"-";const med=g.length?g.sort((a,b)=>a-b)[Math.floor(g.length/2)].toFixed(1):"-";
 let m30=0;for(const t of xs){const n=xs.filter(u=>u>=t&&u<t+1800e3).length;if(n>m30)m30=n}
 const hr=Array(24).fill(0);xs.forEach(t=>hr[new Date(t+9*3600e3).getUTCHours()]++);
 const night=xs.filter(t=>new Date(t+9*3600e3).getUTCHours()<7).length;
 console.log(k+": "+xs.length+" 回・最短間隔 "+mn+" 分・間隔の中央 "+med+" 分・30 分の最大 "+m30+" 回・深夜（0〜7 時） "+night+" 回");
 console.log("   時間帯 "+hr.map((n,h)=>n?h+"時:"+n:"").filter(Boolean).join(" "));
 if(k==="follow"||k==="unfollow")console.log("   時刻 "+xs.map(jst).join(", "));}
const both=["follow","unfollow"].flatMap(k=>(j[k]||[]).filter(t=>t>=t0)).sort((a,b)=>a-b);let m=0;for(const t of both){const n=both.filter(u=>u>=t&&u<t+1800e3).length;if(n>m)m=n}
console.log("フォロー＋解除: "+both.length+" 回・30 分の最大 "+m+" 回（上限 4）");' "$W/data/x-action-ledger.json" 2>&1
echo '```'
echo; echo "## その日の動き方（11/15・11/16）"; echo '```'
"$NODE_BIN" -e '
const p=require(process.argv[1]);const hm=x=>String(Math.floor(x/60)).padStart(2,"0")+":"+String(x%60).padStart(2,"0");
for(const d of ["2026-11-15T03:00:00Z","2026-11-16T03:00:00Z","2026-11-17T03:00:00Z"]){const x=p.dayPlan(Date.parse(d));console.log(d.slice(5,10)+" "+hm(x.start)+"〜"+hm(x.end)+" 休憩 "+x.breaks.map(b=>hm(b[0])+"-"+hm(b[1])).join(" ")+" "+x.mood+"（間隔 "+x.level.toFixed(2)+" 倍）")}' "$LIB/x-action-pacer.cjs" 2>&1
echo '```'
echo; echo "## 押す直前の記録（出どころ別・11/15 21:31〜）"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs");const t0=Date.parse("2026-11-15T12:31:00Z");const rows=fs.readFileSync(process.argv[1],"utf8").split("\n").filter(Boolean).map(l=>{try{return JSON.parse(l)}catch{return null}}).filter(r=>r&&r.t>=t0);
const src=r=>{const s=r.script+" "+r.parent;return /badge-followback/.test(s)?"認証済みへのフォロー返し":/incoming-reply-watcher/.test(s)?"返信をくれた人":/comment-orchestrator|comment-warmup/.test(s)?"コメントした人":/mutual-prune/.test(s)?"相互の解除":/follow-balance/.test(s)?"片思いの解除":/reply-followers-cleanup/.test(s)?"返さない人の解除":/competitor-follower/.test(s)?"競合のフォロワー":/hashtag-follow/.test(s)?"ハッシュタグ":"その他（"+r.script+"）"};
const c={};rows.forEach(r=>{const k=r.type+"・"+src(r);c[k]=(c[k]||0)+1});Object.entries(c).sort((a,b)=>b[1]-a[1]).forEach(([k,v])=>console.log(k+": "+v))' "$W/data/x-action-shadow.jsonl" 2>&1
echo '```'
echo; echo "## follow-handle の [x502] [x507] の行（11/15 21:31〜）"; echo '```'
for f in "$L"/competitor-follower-follow*.log "$L"/hashtag-follow*.log "$L"/incoming-reply-watcher*.log "$L"/comment-orchestrator*.log "$L"/comment-warmup*.log; do [ -f "$f" ] || continue; n1=$(grep -ac 'いいねしてからフォロー' "$f" | head -1); n2=$(grep -ac 'いいねは間隔待ちで見送り' "$f" | head -1); n3=$(grep -ac '眺める段で失敗' "$f" | head -1); n4=$(grep -ac 'ホームを眺めてから' "$f" | head -1); [ "$n1$n2$n3$n4" = "0000" ] && continue; echo "$(basename "$f"): いいねしてから $n1・いいね見送り $n2・眺める段で失敗 $n3・ホームを眺めた $n4"; done
echo "（ログの全期間の数。x502 は 11/15 21:35、x507 は 11/15 23:5x に入れた）"
echo '```'
echo; echo "## プロフィールのヘッダー（毎朝の数字）"; echo '```'
F="$HOME/.openclaw/ops-heartbeat-wt/reports/board/x-numbers.json"; [ -f "$F" ] || F="$(ls -t "$W"/data/x-numbers*.json 2>/dev/null | head -1)"
[ -n "$F" ] && "$NODE_BIN" -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const h=j.header||{};console.log("生成 "+j.generated+"・フォロー中 "+h.following+"・フォロワー "+h.followers+"・比率 "+(h.following/h.followers).toFixed(3)+"・認証済みフォロワー "+((j.d7||{}).verifiedFollowers||"?"))' "$F" 2>&1
grep -aE '実数（ヘッダー）' "$L/follow-balance.log" 2>/dev/null | tail -1 | cut -c1-200
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E 'フォロー＋解除|^follow:|^unfollow:' "$OUT" | head -3 | cut -c1-140
exit 0
