#!/bin/bash
# **相手の投稿を切らずに出す。裏取りのため。費用 $0。**
#
# ## なぜこれが要るのか
#
# `t029` で通った文にこう書いてあった。
#
#   > 外貨建てで減ってるのか、それは辛いわね。でもインデックス軸なら、
#   > ここからの回復も早いと思うわ。**旧NISAの貯金があるのが強いわよ**😏
#
# **「旧NISA」が相手の投稿にあるのか、私は確認できていない。**
# 報告に載せる相手の投稿を **170 字で切っていた**ため、末尾が読めなかった。
#
#   > 円建てより外貨建ての資産比率が高いからかNISAの資産がこのところ減っている🥲
#   > ​とはいえ先月比で見れば数％減にとどま█
#
# 2026-09-04 に「サーモンゆず塩」→「塩辛いサーモン」、投稿に無い「クーポン」を
# 足した事故と**同じ型**。それを検証するための報告が、検証できない形になっていた。
# **裏取りできない報告を作っていたのは私の落ち度。**
#
# ## 出すもの（無料・LLM を呼ばない）
#
#   1. キャッシュにある候補 5 件の**全文**（切らない）
#   2. 各投稿に「旧NISA」「クーポン」等の語が**実在するか**の突き合わせ
#   3. 直近のキューにある「アタシも見直した」の件数
#      （`t029` で京丹後が弾かれた理由。検査が正しく効いたことの確認）
#
# ## やらないこと
#
# **生成しない。enqueue しない。投稿しない。ジョブも戻さない。**
#
# **URL は伏せる。ハンドルは伏せる。API キーは値を出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/full-targets.md"
CACHE="$W/data/trend-cache.json"
QUEUE="$W/data/post_queue.json"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LIMIT=5
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#https?://[^ 　]+#<URL>#g'; }

{
echo "# 相手の投稿の全文（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> \`t029\` の返信に「**旧NISA**」が出たが、**相手の投稿にあるか確認できていない。**"
echo "> 報告が相手の投稿を 170 字で切っていたため。**裏取りできない報告を作っていた。**"
echo "> **LLM を 1 回も呼ばない。生成しない。投稿しない。**"

echo
echo "## 1. 候補 5 件の全文（切らない）"
"$NODE_BIN" -e '
const fs=require("fs");
let out=[];
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const pools=[];
  const walk=(o,dep)=>{ if(dep>3||!o) return;
    if(Array.isArray(o)){ if(o.length&&typeof o[0]==="object") pools.push(o); o.slice(0,5).forEach(x=>walk(x,dep+1)); return; }
    if(typeof o==="object") Object.values(o).forEach(v=>walk(v,dep+1)); };
  walk(d,0);
  for(const p of pools){
    const k=Object.keys(p[0]||{}); const tk=k.find(x=>/^(text|full_text|content)$/i.test(x));
    if(!tk) continue;
    for(const x of p){ const t=String(x[tk]||"").trim(); if(t.length>=15) out.push(t); }
  }
}catch(e){ console.log("キャッシュが読めない: "+e.message); }
out=[...new Set(out)].slice(0,Number(process.argv[2]));
// **語の実在チェック。t029 が使った語が本当に投稿にあるか。**
const probe=["旧NISA","新NISA","NISA","クーポン","インデックス","外貨建","ドル","積立","貯金","回復"];
out.forEach((t,i)=>{
  console.log("");
  console.log("### 候補 "+(i+1)+"（"+t.length+" 字）");
  console.log("");
  console.log("```text");
  console.log(t);
  console.log("```");
  const has=probe.filter(w=>t.includes(w));
  const no=probe.filter(w=>!t.includes(w));
  console.log("");
  console.log("- **ある語**: "+(has.join(" / ")||"（なし）"));
  console.log("- **無い語**: "+(no.join(" / ")||"（なし）"));
});
if(!out.length) console.log("\n（候補が取れない）");
' "$CACHE" "$LIMIT" 2>&1 | hide | mask

echo
echo "## 2. 「アタシも見直した」がキューに何件あるか"
echo
echo "\`t029\` で京丹後が弾かれた理由の確認。**検査が正しく効いたのかを見る。**"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const c=(q.queue||[]).filter(e=>String(e.kind||"")==="comment"&&e.text).slice(-20).map(e=>String(e.text));
  const hit=c.filter(t=>t.includes("アタシも見直した"));
  console.log("直近 20 件のうち「アタシも見直した」を含む: "+hit.length+" 件");
  hit.forEach((t,i)=>console.log("  "+(i+1)+". "+t.replace(/\n/g," ")));
  console.log("");
  console.log("直近 20 件の締め（末尾 7 字）の内訳:");
  const tails={};
  for(const t of c){ const k=t.slice(-7); tails[k]=(tails[k]||0)+1; }
  Object.entries(tails).sort((a,b)=>b[1]-a[1]).slice(0,8)
    .forEach(([k,v])=>console.log("  "+v+" 件  ..."+k));
}catch(e){ console.log("キューが読めない: "+e.message); }
' "$QUEUE" 2>&1 | cut -c1-180 | hide | mask
echo '```'

echo
echo "---"
echo
echo "**生成していない。投稿していない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '候補 1' "$OUT" 2>/dev/null; then echo "**全文を出した（生成なし・\$0）** / $(basename "$OUT")"
else echo "候補が取れなかった / $(basename "$OUT")"; fi
