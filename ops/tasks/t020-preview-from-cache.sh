#!/bin/bash
# **候補の在り処を確かめて、実データがあれば 5 件 書かせる。投稿はしない。**
#
# ## t019 で分かったこと
#
# 候補は**ファイルではなく、実行時の検知結果**から来ていた。
#
#   38: CANDIDATES=$(echo "$DETECT_OUT" | node -e "... o.candidates ...")
#   46: CANDIDATES=$(echo "$CANDIDATES" | node scripts/ng-filter-candidates.cjs ...)
#
# だから `comment-candidates.json` のようなファイルは存在しない。**探し方が間違っていた。**
#
# ただし `data/trend-cache.json` がある。**検知結果が残っているなら、そこから取れる。**
#
# ## 手順（費用が出るのは 3 だけ）
#
#   1. `trend-cache.json` の中身を見る（**無料**）
#   2. orchestrator が `DETECT_OUT` をどう作っているか出す（**無料**）
#   3. **実データが取れたときだけ** 5 件 書かせる（約 $0.01・承認済み）
#
# **取れなければ 3 に入らない。** 作り話の投稿に返信させても検証にならないし、
# 費用だけ出る。`t019` と同じ判断をここでも守る。
#
# ## やらないこと
#
# **enqueue しない。投稿しない。ジョブも戻さない。orchestrator も書き換えない。**
# `comment-warmup` は止めたまま。ここで作った文はどこにも送られない。
#
# **ハンドルは伏せる。API キーは出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/preview-from-cache.md"
DEST="$W/ops"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
CO="$W/scripts/comment-orchestrator.sh"
CACHE="$W/data/trend-cache.json"
LIMIT=5
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]+#\1<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# 候補の在り処を確かめて、あれば 5 件 書かせる（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> **投稿しない。enqueue しない。ジョブも戻さない。**"
echo "> \`t019\` は候補ファイルを探して見つからず中止した。**探し方が間違っていた。**"
echo "> 候補は実行時の検知結果から来る。ここでは \`trend-cache.json\` を見る。"

echo
echo "## 1. \`trend-cache.json\`（無料）"
echo
if [ ! -f "$CACHE" ]; then
  echo "- **無い**"
else
  echo "- 更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$CACHE" 2>/dev/null) / $(wc -c < "$CACHE" | tr -d ' ') B"
  echo
  echo "### 構造"
  echo '```json'
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const top=Array.isArray(d)?{"(配列)":d.length}:Object.fromEntries(
    Object.entries(d).map(([k,v])=>[k, Array.isArray(v)?`配列 ${v.length} 件`:typeof v]));
  console.log(JSON.stringify(top,null,2).slice(0,900));
}catch(e){ console.log("読めない: "+e.message); }
' "$CACHE" 2>&1 | mask
  echo '```'
  echo
  echo "### 投稿の本文らしきものが入っているか"
  echo '```'
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const pools=[];
  const walk=(o,depth)=>{
    if(depth>3||!o) return;
    if(Array.isArray(o)){ if(o.length&&typeof o[0]==="object") pools.push(o); o.slice(0,3).forEach(x=>walk(x,depth+1)); return; }
    if(typeof o==="object") Object.values(o).forEach(v=>walk(v,depth+1));
  };
  walk(d,0);
  let found=0;
  for(const p of pools){
    const k=Object.keys(p[0]||{});
    const tk=k.find(x=>/^(text|full_text|content|tweet_text|body)$/i.test(x));
    if(tk){ console.log(`配列 ${p.length} 件 / 本文フィールド: ${tk}`);
      p.slice(0,3).forEach((x,i)=>console.log(`  [${i}] ${String(x[tk]).replace(/\n/g," ").slice(0,80)}`));
      found++; }
  }
  if(!found) console.log("本文フィールドを持つ配列が見つからない");
}catch(e){ console.log("読めない: "+e.message); }
' "$CACHE" 2>&1 | hide | mask
  echo '```'
fi

echo
echo "## 2. \`DETECT_OUT\` の作り方（無料）"
echo
echo '```bash'
sed -n '20,45p' "$CO" 2>/dev/null | cat -n | sed 's/^/  /' | cut -c1-170 | hide | mask
echo '```'
echo
echo "**上の \`DETECT_OUT=\` の行が、候補の出どころ。** ここを単独で呼べれば実データが取れる。"
echo "検知は Playwright の DOM 取得で、**LLM は使わない（\$0）。**"

echo
echo "## 3. 実データがあれば書かせる"
echo
# キャッシュから本文を取り出す
"$NODE_BIN" -e '
const fs=require("fs");
let out=[];
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const pools=[];
  const walk=(o,depth)=>{
    if(depth>3||!o) return;
    if(Array.isArray(o)){ if(o.length&&typeof o[0]==="object") pools.push(o); o.slice(0,5).forEach(x=>walk(x,depth+1)); return; }
    if(typeof o==="object") Object.values(o).forEach(v=>walk(v,depth+1));
  };
  walk(d,0);
  for(const p of pools){
    const k=Object.keys(p[0]||{});
    const tk=k.find(x=>/^(text|full_text|content|tweet_text|body)$/i.test(x));
    if(!tk) continue;
    for(const x of p){ const t=String(x[tk]||"").trim(); if(t.length>=15) out.push(t); }
  }
}catch(e){}
out=[...new Set(out)].slice(0,Number(process.argv[2]));
fs.writeFileSync("/tmp/.t020cand.json", JSON.stringify(out));
console.log(out.length);
' "$CACHE" "$LIMIT" > /tmp/.t020n 2>/dev/null || echo 0 > /tmp/.t020n
N="$(cat /tmp/.t020n 2>/dev/null || echo 0)"
echo "- 使える候補: **${N} 件**"

if [ "${N:-0}" = "0" ]; then
  echo
  echo "- **実データが取れない。生成に入らない（費用 \$0）。**"
  echo
  echo "> 作り話の投稿に返信させても、噛み合っているかの検証にならない。"
  echo "> 次は 2 章の \`DETECT_OUT=\` の行を単独で呼んで候補を取る（検知自体は \$0）。"
  rm -f /tmp/.t020cand.json /tmp/.t020n
  exit 0
fi

echo
echo "### 部品を置く（**origin/main から**。作業ツリーは古い）"
echo
mkdir -p "$DEST/lib" "$DEST/data"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
NG=0
for f in lib/asuka-reply.cjs lib/reply-relevance-check.cjs lib/reply-tone-check.cjs \
         data/reply-relevance-rules.json data/reply-style-prompt.json data/reply-tone-rules.json; do
  if git -C "$REPO" show "origin/main:ops/$f" > "$DEST/$f" 2>/dev/null && [ -s "$DEST/$f" ]; then
    :
  else rm -f "$DEST/$f"; echo "- \`$f\`: **取り出せない**"; NG=1; fi
done
[ "$NG" = "1" ] && { echo "- **部品がそろわない。中止（費用 \$0）。**"; exit 1; }
"$NODE_BIN" --check "$DEST/lib/asuka-reply.cjs" 2>/dev/null || { echo "- **構文が壊れている。中止。**"; exit 1; }
echo "- 部品 6 個・構文 OK"

export OPS_QUEUE_PATH="$W/data/post_queue.json"
i=0
while [ "$i" -lt "$N" ]; do
  TARGET="$("$NODE_BIN" -e 'process.stdout.write(JSON.parse(require("fs").readFileSync("/tmp/.t020cand.json","utf8"))[Number(process.argv[1])])' "$i")"
  RES="$("$NODE_BIN" -e '
let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
  console.log(JSON.stringify({trend:{text:d},kind:"comment"}));});' <<<"$TARGET" \
    | "$NODE_BIN" "$DEST/lib/asuka-reply.cjs" 2>&1 | tail -1)"
  echo
  echo "---"
  echo
  echo "**相手の投稿**"
  echo
  echo "> $(printf '%s' "$TARGET" | tr '\n' ' ' | cut -c1-180 | hide)"
  echo
  "$NODE_BIN" -e '
let o={}; try{ o=JSON.parse(process.argv[1]); }catch(e){ console.log("**出力が読めない**: "+String(process.argv[1]).slice(0,160)); process.exit(0); }
if(o.skip){ console.log("**返信しない** — "+(o.reason||"")); }
else if(o.text){
  console.log("**返信案**"); console.log(""); console.log("> "+o.text); console.log("");
  console.log("- 共有した語: `"+((o.shared||[]).join(", ")||"（なし）")+"`");
} else console.log("**空の出力**");
' "$RES" 2>&1 | hide | mask
  i=$((i+1))
done

echo
echo "---"
echo
echo "## 4. 見どころ"
echo
echo "- 相手の投稿の**具体語に触れているか**"
echo "- **締めが毎回ちがうか**（実物 15 件は 4 型を 2 回ずつ使い回し）"
echo "- **絵文字が毎回付いていないか**（実物は全 15 件に 1 つ）"
echo "- **命令形になっていないか**（実物は 15 件中 5 件）"
echo "- **「返信しない」が出ているか**（穴埋め方式では不可能だった判断）"
echo
echo "**投稿していない。** 直すなら \`ops/data/reply-style-prompt.json\` だけでよい。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
rm -f /tmp/.t020cand.json /tmp/.t020n
if grep -q '返信案' "$OUT" 2>/dev/null; then echo "**生成した（投稿なし）** / $(basename "$OUT")"
elif grep -q '実データが取れない' "$OUT" 2>/dev/null; then echo "実データ無しで中止（費用 \$0）/ $(basename "$OUT")"
else echo "生成できていない / $(basename "$OUT")"; fi
