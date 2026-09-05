#!/bin/bash
# **候補を検知で取り直して、返信案を 10 件 出す。投稿しない。**
#
# ## t032 で分かった 2 つの問題
#
#   1. **キャッシュが 11 件しか無い。** 6 件が PR/アフィリで入口落ちし、出せたのは 4 件
#   2. **同じ実行の中で型が固まる。** 4 件中 2 件が「ふーん、」始まり、3 件が 😏 終わり
#
# 2 は私の作りの問題だった。重複検査が比べていたのは**キューに残る過去の返信だけ**で、
# **同じ実行の中で作った文どうしを見ていなかった。** 実運用も 1 回 2 件ずつ作るので同じ穴。
#
# ## 直した点
#
#   - `asuka-reply.cjs` … `OPS_EXTRA_RECENT`（JSON 配列）で**その実行で作った文**を渡せる
#   - 4-A-2 書き出しの相づち … 先頭 8 字の一致では「ふーん、京丹後」と「ふーん、dブック」が
#                              別物になった。**相づちそのものを数える**
#   - 4-A-3 末尾の絵文字     … 語尾は毎回ちがっても**顔だけ同じ**という固まり方をする
#
# 手元で t032 の 4 件を「1 回の実行」として流し直したところ、**4 件目を正しく弾いた。**
#
# ## 検知について
#
# `comment-orchestrator.sh:18` と同じ呼び方をする。
#
#   ensure-chrome.sh → node scripts/trend-detect.js → 最後の JSON 行の .candidates
#
# **Playwright の DOM 取得のみ。LLM を使わない＝ $0。**
# **投稿しない。フォローしない。enqueue しない。ジョブも戻さない。**
#
# 相手を弾く `ng-filter-candidates.cjs` は、**呼べたときだけ**通す。
# 呼び方を推測しない。通らなければ自前の語で弾く（売春・闇バイト系）。
#
# ## 費用（利用者の承認済み・2026-09-05）
#
#   推定 $0.003 / 件（Haiku 4.5・system 約 2,700 字・出力 ~150 tok）
#   **LLM を呼ぶのは 15 回まで = 約 $0.045**   ← 安全弁。実績ではない
#   入口で見送った分は **$0**
#
# **API キーは値を出さない。ハンドルと URL は伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/preview-ten-fresh.md"
DEST="$W/ops"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
SCRIPTS="$W/scripts"
MAX_LLM=15
WANT=10
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#https?://[^ 　]+#<URL>#g'; }

{
echo "# 返信案 10 件（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> **投稿していない。enqueue もしていない。フォローもしていない。**"
echo "> 候補の取得は Playwright の DOM 取得のみ（**LLM 不使用＝\$0**）。"
echo "> **LLM は 15 回まで**（約 \$0.045 で必ず止まる）。相手の投稿は**切らずに全文**。"

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

echo
echo "## 1. 候補を検知で取る（LLM 不使用・\$0）"
echo
if [ -x "$SCRIPTS/ensure-chrome.sh" ]; then
  if "$SCRIPTS/ensure-chrome.sh" >/dev/null 2>&1; then echo "- Chrome: OK"
  else echo "- **Chrome を用意できない。キャッシュに切り替える。**"; fi
else
  echo "- \`ensure-chrome.sh\` が無い。キャッシュに切り替える。"
fi

cd "$W" 2>/dev/null || true
DETECT_OUT="$("$NODE_BIN" "$SCRIPTS/trend-detect.js" 2>/dev/null || true)"
printf '%s' "$DETECT_OUT" | "$NODE_BIN" -e '
let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
  const line=d.split("\n").reverse().find(l=>l.trim().startsWith("{"));
  let arr=[];
  if(line){ try{ arr=(JSON.parse(line).candidates)||[]; }catch(e){} }
  require("fs").writeFileSync("/tmp/.t033raw.json", JSON.stringify(arr));
  console.log(arr.length);
});' > /tmp/.t033n 2>/dev/null || echo 0 > /tmp/.t033n
DN="$(cat /tmp/.t033n 2>/dev/null || echo 0)"
echo "- 検知で取れた候補: **${DN} 件**"

# **相手を弾くフィルタは、呼べたときだけ通す。** 呼び方を推測しない
if [ "${DN:-0}" != "0" ] && [ -f "$SCRIPTS/ng-filter-candidates.cjs" ]; then
  F="$("$NODE_BIN" "$SCRIPTS/ng-filter-candidates.cjs" < /tmp/.t033raw.json 2>/dev/null || true)"
  if printf '%s' "$F" | "$NODE_BIN" -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{const a=JSON.parse(d);if(Array.isArray(a)){require("fs").writeFileSync("/tmp/.t033raw.json",JSON.stringify(a));console.log(a.length);process.exit(0)}}catch(e){};process.exit(1)});' > /tmp/.t033f 2>/dev/null; then
    echo "- \`ng-filter-candidates.cjs\` を通した: **$(cat /tmp/.t033f) 件**"
  else
    echo "- \`ng-filter-candidates.cjs\` は**この呼び方では通らなかった。自前の語で弾く**"
  fi
fi

# 本文を取り出す（検知が空ならキャッシュへ）
"$NODE_BIN" -e '
const fs=require("fs");
let out=[];
const pull=(o)=>{
  const t=String((o&&(o.text||o.full_text||o.content))||"").trim();
  if(t.length>=20) out.push(t);
};
try{ JSON.parse(fs.readFileSync("/tmp/.t033raw.json","utf8")).forEach(pull); }catch(e){}
if(!out.length){
  try{
    const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
    const walk=(o,dep)=>{ if(dep>6||!o) return;
      if(Array.isArray(o)){ o.forEach(x=>{ if(x&&typeof x==="object") pull(x); walk(x,dep+1); }); return; }
      if(typeof o==="object") Object.values(o).forEach(v=>walk(v,dep+1)); };
    walk(d,0);
  }catch(e){}
}
// **自前の安全側フィルタ。** 公開リポジトリに載る報告なので、危ない相手は載せない
const bad=["パパ活","援助","円で会","ホテル代","裏バイト","闇バイト","即日現金","高収入 副業","出会い","エッチ"];
out=[...new Set(out)].filter(t=>!bad.some(w=>t.includes(w)));
fs.writeFileSync("/tmp/.t033c.json", JSON.stringify(out));
console.log(out.length);
' "$W/data/trend-cache.json" > /tmp/.t033m 2>/dev/null || echo 0 > /tmp/.t033m
N="$(cat /tmp/.t033m 2>/dev/null || echo 0)"
echo "- 使える候補: **${N} 件**（重複と危険語を除く・20 字以上）"
[ "${N:-0}" = "0" ] && { echo; echo "- **候補が取れない。生成に入らない（費用 \$0）。**"; exit 0; }
echo "- LLM を呼ぶ上限: **${MAX_LLM} 回**（約 \$0.045）"

echo
echo "## 2. 返信案"
export OPS_QUEUE_PATH="$W/data/post_queue.json"
export OPS_EXTRA_RECENT='[]'
CALLED=0; OKC=0; SKIP_IN=0; SKIP_GATE=0
i=0
while [ "$i" -lt "$N" ]; do
  [ "$CALLED" -ge "$MAX_LLM" ] && break
  [ "$OKC" -ge "$WANT" ] && break
  TARGET="$("$NODE_BIN" -e 'process.stdout.write(JSON.parse(require("fs").readFileSync("/tmp/.t033c.json","utf8"))[Number(process.argv[1])]||"")' "$i")"
  i=$((i+1))
  [ -z "$TARGET" ] && continue

  RES="$(printf '%s' "$TARGET" | "$NODE_BIN" -e '
let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
  console.log(JSON.stringify({trend:{text:d,author:"",tweet_url:""},kind:"comment"}));});' \
    | "$NODE_BIN" "$DEST/lib/asuka-reply.cjs" 2>&1 | tail -1)"

  case "$RES" in *"LLM を呼ばずに"*) SKIP_IN=$((SKIP_IN+1)); continue ;; esac
  CALLED=$((CALLED+1))

  STATUS="$("$NODE_BIN" -e 'let o={};try{o=JSON.parse(process.argv[1])}catch(e){};process.stdout.write(o.ok===true?"ok":"ng")' "$RES" 2>/dev/null)"
  if [ "$STATUS" = "ok" ]; then
    OKC=$((OKC+1))
    # **通った文をこの実行の「直近」に足す。** 次の生成とゲートが これを見る
    OPS_EXTRA_RECENT="$("$NODE_BIN" -e '
let a=[]; try{a=JSON.parse(process.argv[1])}catch(e){}
let o={}; try{o=JSON.parse(process.argv[2])}catch(e){}
if(o.text) a.push(String(o.text));
process.stdout.write(JSON.stringify(a.slice(-20)));' "$OPS_EXTRA_RECENT" "$RES" 2>/dev/null || printf '%s' "$OPS_EXTRA_RECENT")"
    export OPS_EXTRA_RECENT
  else
    SKIP_GATE=$((SKIP_GATE+1))
  fi

  echo
  echo "---"
  echo
  echo "### $( [ "$STATUS" = "ok" ] && echo "案 $OKC" || echo "弾いた $SKIP_GATE" )"
  echo
  echo "**相手の投稿**"
  echo
  echo '```text'
  printf '%s\n' "$TARGET" | hide | mask
  echo '```'
  echo
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
done

echo
echo "---"
echo
echo "## 3. 書き出しと締めの散らばり"
echo
echo "**同じ実行の中で型が固まっていないかを、数えて出す。**"
echo
echo '```'
"$NODE_BIN" -e '
let a=[]; try{a=JSON.parse(process.argv[1])}catch(e){}
if(!a.length){ console.log("（通った案が無い）"); }
else{
  const head={}, emo={};
  const le=s=>{const m=String(s).match(/(?:\p{Extended_Pictographic}(?:️)?)+\s*$/u);return m?m[0].trim():"（なし）";};
  a.forEach(t=>{ const h=String(t).slice(0,4); head[h]=(head[h]||0)+1; const e=le(t); emo[e]=(emo[e]||0)+1; });
  console.log("書き出し（先頭 4 字）:");
  Object.entries(head).sort((x,y)=>y[1]-x[1]).forEach(([k,v])=>console.log("  "+v+" 件  "+k));
  console.log("");
  console.log("末尾の絵文字:");
  Object.entries(emo).sort((x,y)=>y[1]-x[1]).forEach(([k,v])=>console.log("  "+v+" 件  "+k));
}' "$OPS_EXTRA_RECENT" 2>&1 | hide | mask
echo '```'

echo
echo "## 4. 内訳と費用"
echo
echo "| | 件数 | 金額 |"
echo "| --- | --- | --- |"
echo "| 候補 | ${N} | — |"
echo "| 入口で見送り（PR/アフィリ/拡散・**LLM 未使用**） | ${SKIP_IN} | \$0 |"
echo "| 生成してゲートで弾いた | ${SKIP_GATE} | 課金あり |"
echo "| **通った返信案** | **${OKC}** | 課金あり |"
echo "| LLM を呼んだ合計 | ${CALLED} | 約 \$$("$NODE_BIN" -e 'process.stdout.write((Number(process.argv[1])*0.003).toFixed(4))' "$CALLED" 2>/dev/null || echo "?")（**推定**） |"
echo
echo "推定の前提: Haiku 4.5（入力 \$1.00 / 出力 \$5.00 per MTok）、system 約 2,700 字、出力 ~150 tok。"
echo "**実測ではない。** 上限 ${MAX_LLM} 回（約 \$0.045）は安全弁であって実績ではない。"
echo
echo "**投稿していない。enqueue もしていない。フォローもしていない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
rm -f /tmp/.t033raw.json /tmp/.t033c.json /tmp/.t033n /tmp/.t033m /tmp/.t033f
n=$(grep -c '^### 案 ' "$OUT" 2>/dev/null || echo 0)
echo "**返信案 ${n} 件（投稿なし）** / $(basename "$OUT")"
