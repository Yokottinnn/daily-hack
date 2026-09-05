#!/bin/bash
# **実物から引いた声で書き下ろさせる。投稿しない。**
#
# ## 何が変わったか
#
# 方式は**全文生成のまま**。変えたのは**キャラ定義の出どころ**だけ。
#
#   これまで: 私が想像で書いた（「アタシ」は偶然 一致、語尾は不一致）
#   これから: `comment-templates.json`（35 件）と `asuka-fill.js` の SYSTEM から**実際に引いた**
#
# `t027` で分かって、推測していたら壊していた点:
#
#   - キャラは v3「**ハッカー子**」。**「アスカ」「エヴァ」への参照は C&D リスクで禁止**
#     （ファイル名が `asuka-*` なので、由来を推測して書いていたら踏んでいた）
#   - 出力の契約に **`ok` が要る**。無いと orchestrator が全件 無言で捨てる
#   - 文の重さ **280 weight 上限・15 字下限**
#   - 禁止 3 型（T12 ボケ / T13 突っ込み / T14 煽り＝ X 側の違反判定リスク）
#   - 低反応で回避 1 型（T18「アタシの周り系」）
#
# ## 見どころ
#
#   1. **ハッカー子の声になっているか**（実物 25 件と並べて見比べられるようにする）
#   2. **相手の投稿の固有名詞をそのまま使っているか**
#      （2026-09-04 は「サーモンゆず塩」→「塩辛いサーモン」とずらした）
#   3. **締めが毎回ちがうか**
#   4. **「返信しない」が出ているか**（穴埋め方式では不可能だった判断）
#
# ## 費用（利用者の承認済み・2026-09-05／上限 5 件）
#
#   推定 $0.003 / 件（Haiku 4.5・system 約 2,700 字 ＋ 相手の投稿・出力 ~150 tok）
#   上限 5 件 = **約 $0.015**   ← 安全弁。実績ではない
#   想定 2 件 = 約 $0.006      ← PR/アフィリが入口で落ちる想定（推定）
#
# 参考: 穴埋め方式の**実測**は $0.00417 / 件。テンプレ 35 件を毎回 送っていたため。
#
# ## やらないこと
#
# **enqueue しない。投稿しない。ジョブも戻さない。orchestrator も書き換えない。**
# `comment-warmup` は `t017` から止めたまま。ここで作った文はどこにも送られない。
#
# **API キーは値を出さない。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/preview-real-voice.md"
DEST="$W/ops"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
CACHE="$W/data/trend-cache.json"
LIMIT=5   # **硬い上限。** 承認は 5 件ぶん
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# 実物から引いた声で書き下ろす（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> **投稿していない。enqueue もしていない。ジョブも止めたまま。**"
echo "> 方式は全文生成のまま。**キャラ定義の出どころだけ**を、私の想像から"
echo "> \`comment-templates.json\`（35 件）＋ \`asuka-fill.js\` の SYSTEM に替えた。"

echo
echo "## 0. 部品"
echo
mkdir -p "$DEST/lib" "$DEST/data"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
NG=0
for f in lib/asuka-reply.cjs lib/reply-relevance-check.cjs lib/reply-tone-check.cjs \
         data/reply-relevance-rules.json data/reply-style-prompt.json data/reply-tone-rules.json; do
  git -C "$REPO" show "origin/main:ops/$f" > "$DEST/$f" 2>/dev/null && [ -s "$DEST/$f" ] \
    || { rm -f "$DEST/$f"; echo "- \`$f\`: **取り出せない**"; NG=1; }
done
[ "$NG" = "1" ] && { echo "- **部品がそろわない。中止（費用 \$0）。**"; exit 1; }
"$NODE_BIN" --check "$DEST/lib/asuka-reply.cjs" 2>/dev/null \
  || { echo "- **構文が壊れている。中止（費用 \$0）。**"; exit 1; }
echo "- 部品 6 個・構文 OK"
echo "- プロンプト: $("$NODE_BIN" -e 'const c=require(process.argv[1]);process.stdout.write(c.system.join("\n").length+" 字 / model "+c.model+" / temp "+c.temperature)' "$DEST/data/reply-style-prompt.json" 2>/dev/null || echo "読めない")"

echo
echo "## 1. 見比べる用: 穴埋め方式で実際に出ていた文"
echo
echo "**この声に戻っているかを見る。**"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const c=(q.queue||[]).filter(e=>String(e.kind||"")==="comment"&&e.text).slice(-6);
  c.forEach((e,i)=>console.log((i+1)+". "+String(e.text).replace(/\n/g," ")));
}catch(e){ console.log("キューが読めない"); }
' "$W/data/post_queue.json" 2>&1 | cut -c1-180 | hide | mask
echo '```'

echo
echo "## 2. 相手の投稿を取る（無料）"
echo
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
fs.writeFileSync("/tmp/.t028c.json", JSON.stringify(out));
console.log(out.length);
' "$CACHE" "$LIMIT" > /tmp/.t028n 2>/dev/null || echo 0 > /tmp/.t028n
N="$(cat /tmp/.t028n 2>/dev/null || echo 0)"
echo "- 候補: **${N} 件**（上限 $LIMIT）"
[ "${N:-0}" = "0" ] && { echo; echo "- **候補が取れない。生成に入らない（費用 \$0）。**"; exit 0; }

echo
echo "## 3. 書き下ろし"
export OPS_QUEUE_PATH="$W/data/post_queue.json"
CALLED=0
i=0
while [ "$i" -lt "$N" ]; do
  TARGET="$("$NODE_BIN" -e 'process.stdout.write(JSON.parse(require("fs").readFileSync("/tmp/.t028c.json","utf8"))[Number(process.argv[1])])' "$i")"
  RES="$(printf '%s' "$TARGET" | "$NODE_BIN" -e '
let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
  console.log(JSON.stringify({trend:{text:d,author:"",tweet_url:""},kind:"comment"}));});' \
    | "$NODE_BIN" "$DEST/lib/asuka-reply.cjs" 2>&1 | tail -1)"

  echo
  echo "---"
  echo
  echo "**相手の投稿**"
  echo
  echo "> $(printf '%s' "$TARGET" | tr '\n' ' ' | cut -c1-170 | hide)"
  echo
  # LLM を呼んだかどうかは skip の理由で分かる（入口フィルタは「LLM を呼ばずに」と書く）
  case "$RES" in *"LLM を呼ばずに"*) ;; *) CALLED=$((CALLED+1)) ;; esac
  "$NODE_BIN" -e '
let o={}; try{ o=JSON.parse(process.argv[1]); }catch(e){
  console.log("**出力が読めない**"); console.log(""); console.log("```");
  console.log(String(process.argv[1]).slice(0,600)); console.log("```"); process.exit(0); }
if(o.ok===true && o.text){
  console.log("**返信案**"); console.log("");
  console.log("> "+o.text); console.log("");
  console.log("- "+o.text.length+" 字 / "+(o.weight||"?")+" weight（上限 280）");
  console.log("- 共有した語: `"+((o.shared||[]).join(", ")||"（なし）")+"`");
  if((o.warns||[]).length) console.log("- 注意: "+o.warns.join(" / "));
} else {
  console.log("**返信しない**"); console.log(""); console.log("```");
  console.log(String(o.error||o.reason||"理由なし").slice(0,600)); console.log("```");
}
' "$RES" 2>&1 | hide | mask
  i=$((i+1))
done

echo
echo "---"
echo
echo "## 4. かかった費用"
echo
echo "| | 件数 | 金額 |"
echo "| --- | --- | --- |"
echo "| 入口で見送り（LLM 未使用） | $((N - CALLED)) | \$0 |"
echo "| 実際に呼んだ | ${CALLED} | 約 \$$("$NODE_BIN" -e 'process.stdout.write((Number(process.argv[1])*0.003).toFixed(4))' "$CALLED" 2>/dev/null || echo "?")（**推定**） |"
echo
echo "推定の前提: Haiku 4.5（入力 \$1.00 / 出力 \$5.00 per MTok）、system 約 2,700 字、出力 ~150 tok。"
echo "**実測ではない。** 穴埋め方式の実測は \$0.00417 / 件だった（テンプレ 35 件を毎回 送っていたため）。"
echo
echo "**投稿していない。enqueue もしていない。** 返信ジョブは止めたまま。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
rm -f /tmp/.t028c.json /tmp/.t028n
if grep -q '返信案' "$OUT" 2>/dev/null; then echo "**返信案が出た（投稿なし）** / $(basename "$OUT")"
else echo "生成に至らなかった / $(basename "$OUT")"; fi
