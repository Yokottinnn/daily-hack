#!/bin/bash
# **返信案を 10 件 出す。キャッシュだけを使う。投稿しない。**
#
# ## 方針（利用者の選択・2026-09-05）
#
# **検知（Chrome）は呼ばない。手元の `trend-cache.json` だけ使う。**
#
# ただし従来の取り出し方は
#   - 走査の深さ 3 まで
#   - 配列ごとに先頭 5 件だけ辿る
#   - 最後に先頭 5 件へ切る
# としていたため、**キャッシュにある候補を取り切れていなかった。**
# ここでは**深さ 6・打ち切りなし**で掘る。掘るのは $0。
#
# ## 費用の上限（**必ずここで止まる**）
#
#   推定 $0.003 / 件（Haiku 4.5・system 約 2,700 字・出力 ~150 tok）
#   **LLM を呼ぶのは 10 回まで = 約 $0.030**   ← 安全弁。実績ではない
#   入口で見送った分（PR/アフィリ/拡散）は **$0**
#
# 候補が何件あっても 10 回で打ち切る。**利用者に示した上限を超えない。**
#
# ## 出すもの
#
#   - 通った返信案（相手の投稿つき・**切らずに全文**）
#   - ゲートで弾いたもの（**理由つき**）
#   - 入口で見送ったもの（**LLM 未使用・$0**）
#
# 相手の投稿を切らない。`t029` で 170 字に切っていたせいで
# 「旧NISA」が実在するか確かめられなかった。**裏取りできる形で出す。**
#
# ## やらないこと
#
# **enqueue しない。投稿しない。フォローしない。ジョブも戻さない。**
# **Chrome に触らない。** orchestrator も書き換えない。
#
# **API キーは値を出さない。ハンドルと URL は伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/preview-ten.md"
DEST="$W/ops"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
CACHE="$W/data/trend-cache.json"
MAX_LLM=10        # **硬い上限。** 約 $0.030 で必ず止まる
WANT=10           # これだけ通ったら早めに終わる
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#https?://[^ 　]+#<URL>#g'; }

{
echo "# 返信案（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> **投稿していない。enqueue もしていない。Chrome にも触っていない。**"
echo "> 手元のキャッシュだけを使い、**LLM は 10 回まで**（約 \$0.030 で必ず止まる）。"
echo "> 相手の投稿は**切らずに全文**出す（\`t029\` で切って裏取りできなかったため）。"

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
echo "## 1. 候補を掘り切る（無料）"
echo
"$NODE_BIN" -e '
const fs=require("fs");
let out=[];
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const pools=[];
  // **深さ 6・打ち切りなし。** 従来は深さ 3・先頭 5 件で、取り切れていなかった。
  const walk=(o,dep)=>{ if(dep>6||!o) return;
    if(Array.isArray(o)){ if(o.length&&typeof o[0]==="object") pools.push(o); o.forEach(x=>walk(x,dep+1)); return; }
    if(typeof o==="object") Object.values(o).forEach(v=>walk(v,dep+1)); };
  walk(d,0);
  for(const p of pools){
    for(const x of p){
      if(!x||typeof x!=="object") continue;
      const tk=Object.keys(x).find(k=>/^(text|full_text|content|tweet_text|body)$/i.test(k));
      if(!tk) continue;
      const t=String(x[tk]||"").trim();
      if(t.length>=20) out.push(t);
    }
  }
}catch(e){ console.log("- キャッシュが読めない: "+e.message); }
out=[...new Set(out)];
fs.writeFileSync("/tmp/.t032c.json", JSON.stringify(out));
console.log("- 掘り出した候補: **"+out.length+" 件**（重複を除く・20 字以上）");
' "$CACHE" 2>&1 | hide | mask
N="$("$NODE_BIN" -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync("/tmp/.t032c.json","utf8")).length))' 2>/dev/null || echo 0)"
[ "${N:-0}" = "0" ] && { echo; echo "- **候補が取れない。生成に入らない（費用 \$0）。**"; exit 0; }
echo "- LLM を呼ぶ上限: **${MAX_LLM} 回**（約 \$0.030）"

echo
echo "## 2. 返信案"
export OPS_QUEUE_PATH="$W/data/post_queue.json"
CALLED=0; OKC=0; SKIP_IN=0; SKIP_GATE=0
i=0
while [ "$i" -lt "$N" ]; do
  [ "$CALLED" -ge "$MAX_LLM" ] && break
  [ "$OKC" -ge "$WANT" ] && break
  TARGET="$("$NODE_BIN" -e 'process.stdout.write(JSON.parse(require("fs").readFileSync("/tmp/.t032c.json","utf8"))[Number(process.argv[1])]||"")' "$i")"
  i=$((i+1))
  [ -z "$TARGET" ] && continue

  RES="$(printf '%s' "$TARGET" | "$NODE_BIN" -e '
let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
  console.log(JSON.stringify({trend:{text:d,author:"",tweet_url:""},kind:"comment"}));});' \
    | "$NODE_BIN" "$DEST/lib/asuka-reply.cjs" 2>&1 | tail -1)"

  # 入口で落ちたものは LLM を呼んでいない＝費用ゼロ。件数だけ数えて本文は出さない
  case "$RES" in
    *"LLM を呼ばずに"*) SKIP_IN=$((SKIP_IN+1)); continue ;;
  esac
  CALLED=$((CALLED+1))

  STATUS="$("$NODE_BIN" -e 'let o={};try{o=JSON.parse(process.argv[1])}catch(e){};process.stdout.write(o.ok===true?"ok":"ng")' "$RES" 2>/dev/null)"
  if [ "$STATUS" = "ok" ]; then OKC=$((OKC+1)); else SKIP_GATE=$((SKIP_GATE+1)); fi

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
echo "## 3. 内訳と費用"
echo
echo "| | 件数 | 金額 |"
echo "| --- | --- | --- |"
echo "| 候補（キャッシュから掘り出した） | ${N} | — |"
echo "| 入口で見送り（PR/アフィリ/拡散・**LLM 未使用**） | ${SKIP_IN} | \$0 |"
echo "| 生成してゲートで弾いた | ${SKIP_GATE} | 課金あり |"
echo "| **通った返信案** | **${OKC}** | 課金あり |"
echo "| LLM を呼んだ合計 | ${CALLED} | 約 \$$("$NODE_BIN" -e 'process.stdout.write((Number(process.argv[1])*0.003).toFixed(4))' "$CALLED" 2>/dev/null || echo "?")（**推定**） |"
echo
echo "推定の前提: Haiku 4.5（入力 \$1.00 / 出力 \$5.00 per MTok）、system 約 2,700 字、出力 ~150 tok。"
echo "**実測ではない。** 上限 ${MAX_LLM} 回（約 \$0.030）は安全弁であって実績ではない。"
echo
echo "**投稿していない。enqueue もしていない。Chrome にも触っていない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
rm -f /tmp/.t032c.json
n=$(grep -c '^### 案 ' "$OUT" 2>/dev/null || echo 0)
echo "**返信案 ${n} 件（投稿なし）** / $(basename "$OUT")"
