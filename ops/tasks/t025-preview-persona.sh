#!/bin/bash
# **呼び出しの形を実物に合わせた。今度こそ書かせる。投稿はしない。**
#
# ## 原因が確定した（t023 が出した全文）
#
#   messages.0.content: Field required
#
# `asuka-fill.js` の実際の呼び出しはこうだった。
#
#   const resp = await ant.call({
#     model: MODEL, system: SYSTEM, user: userMsg,
#     max_tokens: 500, temperature: 0.7,
#   });
#
# **`messages` 配列ではなく `user` に文字列**を渡すクライアントだった。
# クライアントが `user` から messages を組み立てるので、`user` が undefined の
# まま送られて 400 になっていた。**エラーを 80 字で切っていた間は見えなかった。**
#
# 偽クライアント（user 文字列を要求する形）で検証済み。
#
# ## ここまでの経緯
#
#   t020: 候補は取れた（trend-cache.json / 13 件）。生成は `ant.create is not a function`
#   t022: 呼べる関数は見つかった。だが **400 invalid_request_error**
#         しかも私が**エラーを 80 字で切っていて中身が読めなかった**
#
# **どちらも「推測で書いた」ことが原因。** API は課金前に弾かれているので費用は $0。
#
# ## 今回やること
#
# **動いている `asuka-fill.js` の呼び出し部分を、そのまま丸ごと出す。**
# 最初からこうすべきだった。あわせて `anthropic-client.js` の実装も出す。
#
#   1. `asuka-fill.js` の 95〜140 行（**実際に通っている呼び出し**）
#   2. `anthropic-client.js` の export と関数の中身
#   3. そのうえで生成を再実行（エラーは 600 字まで出す）
#
# **1 と 2 は無料。** 3 で 400 が出ても課金されない。
#
# ## やらないこと
#
# **enqueue しない。投稿しない。ジョブも戻さない。orchestrator も書き換えない。**
#
# **API キーは値を出さない。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/preview-v5.md"
DEST="$W/ops"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
AF="$W/scripts/asuka-fill.js"
AC="$W/scripts/anthropic-client.js"
CACHE="$W/data/trend-cache.json"
LIMIT=12
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# 動いている呼び出し方を読んでから書かせる（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> t020: \`ant.create is not a function\` ／ t022: **400 invalid_request_error**"
echo "> どちらも**推測で書いた**のが原因。**最初から動いているものを読むべきだった。**"
echo "> API は課金前に弾かれているので**費用は \$0**。"

echo
echo "## 1. \`asuka-fill.js\` の呼び出し部分（**実際に通っているもの**）"
echo
echo '```javascript'
sed -n '95,140p' "$AF" 2>/dev/null | cat -n | sed 's/^ */  /' | cut -c1-190 | mask
echo '```'

echo
echo "## 2. \`anthropic-client.js\` の中身"
echo
echo "### export しているもの"
echo '```javascript'
grep -nE 'module\.exports|^exports\.|^(async )?function |^const .* = (async )?\(|=>' "$AC" 2>/dev/null \
  | head -20 | cut -c1-170 | mask
echo '```'
echo
echo "### リクエストの組み立て方"
echo '```javascript'
grep -nE 'messages|system|max_tokens|model|body|JSON\.stringify|fetch|https\.request|anthropic-version' "$AC" 2>/dev/null \
  | head -22 | cut -c1-170 | mask
echo '```'

echo
echo "## 3. もう一度 書かせる"
echo
mkdir -p "$DEST/lib" "$DEST/data"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
NG=0
for f in lib/asuka-reply.cjs lib/reply-relevance-check.cjs lib/reply-tone-check.cjs \
         data/reply-relevance-rules.json data/reply-style-prompt.json data/reply-tone-rules.json; do
  git -C "$REPO" show "origin/main:ops/$f" > "$DEST/$f" 2>/dev/null && [ -s "$DEST/$f" ] || { rm -f "$DEST/$f"; echo "- \`$f\`: **取り出せない**"; NG=1; }
done
[ "$NG" = "1" ] && { echo "- **部品がそろわない。中止。**"; exit 1; }
"$NODE_BIN" --check "$DEST/lib/asuka-reply.cjs" 2>/dev/null || { echo "- **構文が壊れている。中止。**"; exit 1; }
echo "- 部品 6 個・構文 OK"

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
}catch(e){}
out=[...new Set(out)].slice(0,Number(process.argv[2]));
fs.writeFileSync("/tmp/.t025c.json", JSON.stringify(out));
console.log(out.length);
' "$CACHE" "$LIMIT" > /tmp/.t025n 2>/dev/null || echo 0 > /tmp/.t025n
N="$(cat /tmp/.t025n 2>/dev/null || echo 0)"
echo "- 候補: **${N} 件**"
[ "${N:-0}" = "0" ] && { echo "- **候補が取れない。中止（費用 \$0）。**"; exit 0; }

export OPS_QUEUE_PATH="$W/data/post_queue.json"
i=0
CALLS=0
MAXCALLS=6
while [ "$i" -lt "$N" ] && [ "$CALLS" -lt "$MAXCALLS" ]; do
  TARGET="$("$NODE_BIN" -e 'process.stdout.write(JSON.parse(require("fs").readFileSync("/tmp/.t025c.json","utf8"))[Number(process.argv[1])])' "$i")"
  RES="$(printf '%s' "$TARGET" | "$NODE_BIN" -e '
let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
  console.log(JSON.stringify({trend:{text:d},kind:"comment"}));});' \
    | "$NODE_BIN" "$DEST/lib/asuka-reply.cjs" 2>&1 | tail -1)"
  echo
  echo "---"
  echo
  echo "**相手の投稿**"
  echo
  echo "> $(printf '%s' "$TARGET" | tr '\n' ' ' | cut -c1-160 | hide)"
  echo
  "$NODE_BIN" -e '
let o={}; try{ o=JSON.parse(process.argv[1]); }catch(e){ console.log("**出力が読めない**"); console.log("```"); console.log(String(process.argv[1]).slice(0,600)); console.log("```"); process.exit(0); }
if(o.skip){ console.log("**返信しない**"); console.log(""); console.log("```"); console.log(String(o.reason||"").slice(0,600)); console.log("```"); }
else if(o.text){
  console.log("**返信案**"); console.log(""); console.log("> "+o.text); console.log("");
  console.log("- 共有した語: `"+((o.shared||[]).join(", ")||"（なし）")+"`");
} else console.log("**空の出力**");
' "$RES" 2>&1 | hide | mask
  case "$RES" in
    *"LLM を呼ばずに見送る"*) : ;;   # 入口で落ちた＝呼んでいない
    *) CALLS=$((CALLS+1)) ;;
  esac
  i=$((i+1))
done
echo
echo "**LLM を呼んだ回数: ${CALLS} 回**（PR/アフィリは入口で落ちるので候補数より少ない）"

echo
echo "---"
echo
echo "**投稿していない。** 直すなら \`ops/data/reply-style-prompt.json\` だけでよい。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
rm -f /tmp/.t025c.json /tmp/.t025n
if grep -q '返信案' "$OUT" 2>/dev/null; then echo "**返信案が出た（投稿なし）** / $(basename "$OUT")"
else echo "まだ生成できていない。呼び出し方を報告に出した / $(basename "$OUT")"; fi
