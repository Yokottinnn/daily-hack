#!/bin/bash
# **言い換えと相場の予測を弾いてから、もう一度 書かせる。投稿しない。**
#
# ## t029 / t030 で分かったこと
#
# `t030` で相手の投稿を**切らずに**読んだ結果:
#
#   - **「旧NISA」は実在した。** 捏造ではない（投稿の箇条書きに「・旧NISAからの資産がある」）
#   - **だが「資産」を「貯金」と言い換えていた。** 投資資産と貯金は別物
#   - **「回復」は投稿に無い。** こちらが足した相場の見通し
#   - 😌 の出どころは**相手の投稿の末尾**。モデルが真似ていた（4-F が正しく止めた）
#   - 京丹後のブロックは正しい判定（「アタシも見直した」が直近 20 件に 1 件）
#
# **裏取りできない報告を作っていたのが最大の問題だった。** 170 字で切っていた。
#
# ## 足した検査（`reply-relevance-check.cjs`）
#
#   4-G 相場の予測      … 回復/反発/戻る/上がる 等が**投稿に無いのに出たら**弾く。
#                         4-E は「大丈夫よ」を弾いたが「思うわ」で緩めれば通った。
#                         **語尾ではなく中身で弾く**
#   4-H 金融語の言い換え … 資産↔貯金・ポイント↔現金・還元↔割引。**混同すると意味が変わる組**だけ
#
# あわせて噛み合い判定の誤検知も 1 つ直した。包含判定が 3 文字以上だったため
# **「外貨」と「外貨建」が別語**になり、明らかに同じ話題を「読んでいない返信」と
# 誤判定していた。2 文字から見るようにした。
#
# 手元の検証: **7 件すべて期待どおり**（弾くべき 1 件を弾き、通すべき 6 件を通した）。
#
# ## 費用（推定）
#
#   推定 $0.003 / 件（Haiku 4.5・system 約 2,700 字・出力 ~150 tok）
#   上限 5 件 = 約 $0.015   ← 安全弁。実績ではない
#   想定 2 件 = 約 $0.006   ← t028/t029 とも 5 件中 3 件が入口落ち（実績）
#
# ## やらないこと
#
# **enqueue しない。投稿しない。ジョブも戻さない。orchestrator も書き換えない。**
#
# **API キーは値を出さない。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/preview-real-voice-v3.md"
DEST="$W/ops"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
CACHE="$W/data/trend-cache.json"
LIMIT=5   # **硬い上限。** 承認は 5 件ぶん
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# 言い換えと相場の予測を弾いて書き直させる（$(date '+%Y-%m-%d %H:%M:%S') JST）"
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
fs.writeFileSync("/tmp/.t031c.json", JSON.stringify(out));
console.log(out.length);
' "$CACHE" "$LIMIT" > /tmp/.t031n 2>/dev/null || echo 0 > /tmp/.t031n
N="$(cat /tmp/.t031n 2>/dev/null || echo 0)"
echo "- 候補: **${N} 件**（上限 $LIMIT）"
[ "${N:-0}" = "0" ] && { echo; echo "- **候補が取れない。生成に入らない（費用 \$0）。**"; exit 0; }

echo
echo "## 3. 書き下ろし"
export OPS_QUEUE_PATH="$W/data/post_queue.json"
CALLED=0
i=0
while [ "$i" -lt "$N" ]; do
  TARGET="$("$NODE_BIN" -e 'process.stdout.write(JSON.parse(require("fs").readFileSync("/tmp/.t031c.json","utf8"))[Number(process.argv[1])])' "$i")"
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
rm -f /tmp/.t031c.json /tmp/.t031n
if grep -q '返信案' "$OUT" 2>/dev/null; then echo "**返信案が出た（投稿なし）** / $(basename "$OUT")"
else echo "生成に至らなかった / $(basename "$OUT")"; fi
