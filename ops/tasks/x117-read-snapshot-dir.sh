#!/bin/bash
# **`data/follower-snapshots/` を読んで日次ペースを出す。測るだけ。費用 $0。**
#
# ## ここまでで分かったこと
#
# `follower-history.json` は **2026-05-23 で止まっていた**うえ、
# **最後の行が `followers: 0` の誤読**だった（前日 51 人 → 0 人）。
#
#   2026-05-22   51 人
#   2026-05-23    0 人   ← -51
#
# **このファイルを信じる仕組みがあれば「フォロワー 0 人」と判断する。**
# 4 か月 気づかれていない。
#
# 一方 `heartbeat` は `followers.now: 266` を出せている。
# **別の場所に実データがある。** `data/` に `follower-snapshots/` があった。
#
# ## 形を決め打ちしない
#
# ディレクトリなのかファイルなのか、中が JSON か JSONL かも分からない。
# **一覧を出し、1 本 だけ中身を見せ、そのうえで読めたら集計する。**
#
# ## やらないこと
#
# **書き換えない。壊れたファイルも消さない（報告してから決める）。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data/follower-snapshots"
OUT="${OPS_REPORT_DIR:-/tmp}/read-snapshot-dir.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# \`follower-snapshots/\` を読む（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`follower-history.json\` は **2026-05-23 で止まっていた**うえ、"
echo "> **最後の行が \`followers: 0\` の誤読**だった（前日 51 人 → 0 人）。"
echo "> \`heartbeat\` は 266 を出せているので、**実データは別の場所にある。**"

echo
echo "## 1. 何が在るか"
echo
echo '```'
if [ -d "$D" ]; then
  echo "  $D"
  echo "  ファイル数: $(ls -1 "$D" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  --- 新しい順に 12 件 ---"
  ls -1t "$D" 2>/dev/null | head -12 | sed 's/^/    /'
  echo "  --- 古い順に 3 件 ---"
  ls -1t "$D" 2>/dev/null | tail -3 | sed 's/^/    /'
elif [ -f "$D" ]; then
  echo "  **ファイルだった**: $D  $(wc -c < "$D" | tr -d ' ') bytes"
else
  echo "  **無い: $D**"
fi
echo '```'

echo
echo "## 2. 1 本 だけ中身を見る（**形を決め打ちしない**）"
echo
echo '```json'
if [ -d "$D" ]; then
  NEW="$(ls -1t "$D" 2>/dev/null | head -1)"
  if [ -n "$NEW" ]; then
    echo "  --- $NEW ---"
    head -c 900 "$D/$NEW" | hide
    echo
  fi
fi
echo '```'

echo
echo "## 3. 読めたら日次ペース"
echo
echo '```'
if [ -d "$D" ]; then
  "$NODE_BIN" -e '
const fs=require("fs"), path=require("path");
const dir=process.argv[1];
const byDate=new Map();
const eat=(date,n)=>{ if(!date||!Number.isFinite(n)||n<=0) return;
  const d=String(date).slice(0,10);
  if(/^\d{4}-\d{2}-\d{2}$/.test(d)) byDate.set(d,n); };

for(const f of fs.readdirSync(dir)){
  const p=path.join(dir,f);
  let st; try{ st=fs.statSync(p); }catch(e){ continue; }
  if(!st.isFile()) continue;
  // **ファイル名に日付が入っていることが多い**ので、それも手がかりにする
  const fromName=(f.match(/(\d{4}-\d{2}-\d{2})/)||[])[1] || null;
  let raw; try{ raw=fs.readFileSync(p,"utf8"); }catch(e){ continue; }
  let done=false;
  try{
    const j=JSON.parse(raw);
    const n=Number(j.followers ?? j.follower_count ?? j.count);
    if(Number.isFinite(n)) { eat(j.date||j.captured_at||fromName, n); done=true; }
    else if(Array.isArray(j.snapshots)) {
      for(const r of j.snapshots) eat(r.date||r.captured_at, Number(r.followers));
      done=true;
    }
  }catch(e){ /* JSON でなければ次 */ }
  if(done) continue;
  for(const line of raw.split(/\r?\n/)){
    const t=line.trim(); if(!t.startsWith("{")) continue;
    try{ const r=JSON.parse(t); eat(r.date||r.captured_at||fromName,
      Number(r.followers ?? r.count)); }catch(e){}
  }
}

const d=[...byDate.entries()].sort((a,b)=>a[0].localeCompare(b[0]));
if(!d.length){ console.log("  日付つきの人数を 1 件も取れなかった"); process.exit(0); }
console.log("  取れた日数: "+d.length+"（"+d[0][0]+" 〜 "+d[d.length-1][0]+"）");
console.log("");
console.log("  日付        人数    前日比");
console.log("  "+"-".repeat(32));
let prev=null;
for(const [dt,n] of d.slice(-14)){
  const diff=prev===null?"":((n-prev>=0?"+":"")+(n-prev));
  console.log("  "+dt+"  "+String(n).padStart(5)+"  "+String(diff).padStart(6));
  prev=n;
}
console.log("");
const last=d[d.length-1];
const pick=(k)=>{ if(d.length<=k) return null; const a=d[d.length-1-k];
  const dd=(Date.parse(last[0])-Date.parse(a[0]))/86400000;
  return dd>0?{span:dd,pace:(last[1]-a[1])/dd}:null; };
for(const k of [3,5,7,12]){ const r=pick(k);
  if(r) console.log("  直近 "+String(r.span).padStart(2)+" 日: "+r.pace.toFixed(2)+" 人/日"); }
const need=300-last[1];
const left=Math.round((Date.parse("2026-09-30")-Date.parse(last[0]))/86400000);
console.log("");
console.log("  最新 "+last[0]+" = "+last[1]+" 人");
if(left>0){
  console.log("  9/30 まで "+left+" 日 / 残り "+need+" 人 → **"+(need/left).toFixed(2)+" 人/日 が必要**");
  for(const k of [3,5,7]){ const r=pick(k);
    if(r) console.log("    直近"+r.span+"日ペースのまま: "+Math.round(last[1]+r.pace*left)+" 人"); }
}
' "$D" 2>&1 | hide
else
  echo "  ディレクトリが無いので集計しない"
fi
echo '```'

echo
echo "## 4. 壊れた記録について"
echo
echo "**\`follower-history.json\` の最終行（2026-05-23・\`followers: 0\`）は誤読。**"
echo "**このタスクでは消さない。** 何が読んでいるかを確かめてから決める"
echo "（消してよいか判断する前に、参照元を洗う）。"

echo
echo "## 5. 費用"
echo
echo "**ファイルを読んで並べるだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "follower-snapshots を読む / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
