#!/bin/bash
# **フォロワー増の現在地を数字で出す。費用 $0。**
#
# ## なぜ最初にこれなのか
#
# 利用者の最優先は**フォロワー増**。だが今のところ、私が持っている数字は
# 「ジョブがロードされている」だけで、**フォロワーが実際に増えているかを知らない。**
#
# 手を打つ順番を決めるには、**どの経路が死んでいるか**を先に知る必要がある。
#
#   フォロー → フォロバ   … **LLM 不使用＝ $0**。数が出る。**最優先で直す**
#   返信 → 認知           … 1 件 推定 $0.003。いま停止中（9/2 から）
#   投稿 → 流入           … 11 件 停止中
#
# **一番効くのに一番安い経路が死んでいたら、そこが最短。**
#
# ## 出すもの（すべて無料・LLM を呼ばない）
#
#   1. **フォロワー数の推移**（スナップショットから。何日で何人 増えたか）
#   2. **フォロー実績の日別**（打ち手が実際に出ているか）
#   3. **フォロバ率**（フォローしたうち何人が返してきたか）
#   4. **止まっている X 系ジョブの一覧**（何を戻せば増えるのかの候補）
#   5. 直近のフォロー系ログの末尾（**エラーで死んでいないか**）
#
# ## やらないこと
#
# **フォローしない。投稿しない。ジョブを触らない（load も unload もしない）。**
# **書き換えない。LLM を呼ばない。**
#
# **ハンドルは伏せる。API キーは値を出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/follower-growth-now.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LA="$HOME/Library/LaunchAgents"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# フォロワー増の現在地（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> **フォローしない。投稿しない。ジョブも触らない。LLM も呼ばない。**"
echo "> 手を打つ順番を決めるために、**どの経路が死んでいるか**を先に数字で出す。"

echo
echo "## 1. フォロワー数の推移"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"), path=require("path");
const dir=process.argv[1];
let files=[];
try{ files=fs.readdirSync(dir).filter(f=>/follower|snapshot|profile|stats/i.test(f)&&/\.(json|jsonl)$/.test(f)); }catch(e){}
if(!files.length){ console.log("（フォロワー数の記録が見つからない）"); }
for(const f of files){
  const p=path.join(dir,f);
  let raw=""; try{ raw=fs.readFileSync(p,"utf8"); }catch(e){ continue; }
  let rows=[];
  if(f.endsWith(".jsonl")){
    rows=raw.split("\n").filter(Boolean).map(l=>{try{return JSON.parse(l)}catch(e){return null}}).filter(Boolean);
  }else{
    let d=null; try{ d=JSON.parse(raw); }catch(e){ continue; }
    rows=Array.isArray(d)?d:Object.values(d||{});
  }
  // フォロワー数らしき数値と日付を持つ行だけ拾う
  const pts=[];
  for(const e of rows){
    if(!e||typeof e!=="object") continue;
    const dk=Object.keys(e).find(k=>/^(date|at|taken_at|captured_at|created_at|ts|timestamp)$/i.test(k));
    const nk=Object.keys(e).find(k=>/^(followers|followers_count|follower_count|count)$/i.test(k));
    if(!dk||!nk) continue;
    const day=String(e[dk]).slice(0,10);
    const n=Number(e[nk]);
    if(!/^\d{4}-\d{2}-\d{2}$/.test(day)||!Number.isFinite(n)) continue;
    pts.push([day,n]);
  }
  if(!pts.length) continue;
  pts.sort((a,b)=>a[0].localeCompare(b[0]));
  const st=fs.statSync(p);
  console.log("["+f+"] 更新 "+st.mtime.toISOString().slice(0,16).replace("T"," "));
  const show=pts.slice(-14);
  let prev=null;
  for(const [d,n] of show){
    const diff = prev===null ? "" : (n-prev>=0?"  +"+(n-prev):"  "+(n-prev));
    console.log("  "+d+"  "+String(n).padStart(6)+diff);
    prev=n;
  }
  if(show.length>=2){
    const days=(new Date(show[show.length-1][0])-new Date(show[0][0]))/86400000;
    const gain=show[show.length-1][1]-show[0][1];
    console.log("  → "+show[0][0]+" から "+days+" 日で "+(gain>=0?"+":"")+gain+" 人"
      + (days>0 ? "（1 日あたり "+(gain/days).toFixed(1)+" 人）" : ""));
  }
  console.log("");
}
' "$W/data" 2>&1 | hide | mask
echo '```'

echo
echo "## 2. フォロー実績（日別）"
echo
echo "**打ち手が実際に出ているか。** 0 が続いていれば、そこが最短の直しどころ。"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"), path=require("path");
const dir=process.argv[1];
let files=[];
try{ files=fs.readdirSync(dir).filter(f=>/follow/i.test(f)&&f.endsWith(".json")&&!/follower-snapshot/i.test(f)); }catch(e){}
if(!files.length){ console.log("（follow 系の状態ファイルが無い）"); }
for(const f of files){
  let d=null; try{ d=JSON.parse(fs.readFileSync(path.join(dir,f),"utf8")); }catch(e){ continue; }
  const rows=Array.isArray(d)?d:Object.values(d||{});
  const byDay={}; let total=0, back=0;
  for(const e of rows){
    if(!e||typeof e!=="object") continue;
    const k=Object.keys(e).find(k=>/^(followed_at|created_at|at|date)$/i.test(k));
    if(k){ const day=String(e[k]).slice(0,10);
      if(/^\d{4}-\d{2}-\d{2}$/.test(day)){ byDay[day]=(byDay[day]||0)+1; total++; } }
    if(Object.keys(e).some(x=>/follow(ed)?_?back|followback|reciprocal/i.test(x)&&e[x])) back++;
  }
  const st=fs.statSync(path.join(dir,f));
  console.log("["+f+"] 全 "+rows.length+" 件 / 日付つき "+total+" / 更新 "+st.mtime.toISOString().slice(0,16).replace("T"," "));
  const days=Object.entries(byDay).sort((a,b)=>b[0].localeCompare(a[0])).slice(0,14);
  if(!days.length) console.log("    （日付つきの記録が無い）");
  days.forEach(([k,v])=>console.log("    "+k+"  "+v+" 件"));
  if(back) console.log("    フォロバ確認: "+back+" 件 / "+rows.length+"（"+(back*100/Math.max(rows.length,1)).toFixed(1)+"%）");
  console.log("");
}
' "$W/data" 2>&1 | hide | mask
echo '```'

echo
echo "## 3. 止まっている X 系ジョブ（**戻せば増える候補**）"
echo
echo '```'
for p in "$LA"/ai.openclaw.*.plist; do
  [ -f "$p" ] || continue
  lbl="$(basename "$p" .plist)"
  case "$lbl" in
    *follow*|*comment*|*reply*|*engage*|*like*|*retweet*|*warmup*|*badge*|*welcome*|*dm*) ;;
    *) continue ;;
  esac
  if launchctl list 2>/dev/null | grep -qF "$lbl"; then
    printf '  ロード   %s\n' "$lbl"
  else
    printf '  **停止** %s   (plist %s)\n' "$lbl" "$(stat -f '%Sm' -t '%Y-%m-%d' "$p" 2>/dev/null)"
  fi
done
echo '```'

echo
echo "## 4. フォロー系ログの末尾（**エラーで死んでいないか**）"
echo
for f in "$W"/logs/*follow*.log; do
  [ -f "$f" ] || continue
  echo "### \`$(basename "$f")\` — 最終更新 **$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)**"
  echo
  echo '```'
  tail -10 "$f" 2>/dev/null | cut -c1-170 | hide | mask
  echo '```'
  echo
done

echo
echo "---"
echo
echo "**何も変えていない。フォローも投稿もしていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**フォロワー増の現在地を出した（変更なし・\$0）** / $(basename "$OUT")"
