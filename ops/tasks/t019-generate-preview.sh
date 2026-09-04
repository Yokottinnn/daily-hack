#!/bin/bash
# **新しい生成器で 5 件 書かせて、文面だけ見せる。投稿はしない。**
#
# 利用者の判断（2026-09-02）: 「生成だけして見せる」。
#
# ## やること
#
#   1. 新しい部品を **origin/main から** workspace へ置く
#      （**作業ツリーからコピーしない。** Mac の checkout は古い。
#        2026-08-30 に `t008` がこれで動かなかった）
#   2. 実際の候補を 5 件 取る
#   3. `asuka-reply.cjs` に書かせる
#   4. **相手の投稿と、生成された返信を並べてレポートに出す**
#
# ## やらないこと
#
# **enqueue しない。投稿しない。ジョブも戻さない。**
# `comment-warmup` は `t017` で止めたまま。orchestrator も書き換えない。
# ここで作った文は**どこにも送られない。**
#
# ## 費用（利用者に提示して承認済み）
#
#   5 件 × 推定 $0.0019 = **約 $0.01**（1 回きり）
#   前提: Haiku 4.5（$1.00/$5.00 per MTok）／入力 約1,400 tok ／出力 約100 tok
#
# **これは Console 課金。** 承認済みだが、5 件を超えて呼ばない（`LIMIT` で固定）。
#
# **ハンドルは伏せる。API キーは出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/generate-preview.md"
DEST="$W/ops"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
CO="$W/scripts/comment-orchestrator.sh"
LIMIT=5
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]+#\1<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# 新しい生成器に 5 件 書かせる（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> **投稿しない。enqueue しない。ジョブも戻さない。**"
echo "> ここで作った文はどこにも送られない。読むためだけに作る。"
echo
echo "> 費用: 5 件 × 推定 \$0.0019 = **約 \$0.01**（1 回きり・承認済み）"

echo
echo "## 1. 部品を置く（**origin/main から。作業ツリーからは取らない**）"
echo
mkdir -p "$DEST/lib" "$DEST/data"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
NG=0
for f in lib/asuka-reply.cjs lib/reply-relevance-check.cjs lib/reply-tone-check.cjs \
         data/reply-relevance-rules.json data/reply-style-prompt.json data/reply-tone-rules.json; do
  if git -C "$REPO" show "origin/main:ops/$f" > "$DEST/$f" 2>/dev/null && [ -s "$DEST/$f" ]; then
    echo "- \`$f\`: $(wc -c < "$DEST/$f" | tr -d ' ') B"
  else
    rm -f "$DEST/$f"; echo "- \`$f\`: **取り出せない**"; NG=1
  fi
done
if [ "$NG" = "1" ]; then
  echo
  echo "**部品がそろわない。中止。**"
  exit 1
fi
if ! "$NODE_BIN" --check "$DEST/lib/asuka-reply.cjs" 2>/dev/null; then
  echo "- **構文が壊れている。中止。**"; exit 1
fi
echo "- 構文: **OK**"

echo
echo "## 2. 候補を取る"
echo
echo "### orchestrator が候補をどう取っているか"
echo '```bash'
grep -nE 'candidate|CAND|fetch|timeline|search|jq|TWEET' "$CO" 2>/dev/null \
  | head -12 | cut -c1-160 | hide | mask
echo '```'

CANDJSON=""
for p in "$W/data/comment-candidates.json" "$W/data/candidates.json" \
         "$W/tmp/comment-candidates.json" "$W/data/trend-candidates.json"; do
  [ -f "$p" ] && CANDJSON="$p" && break
done

if [ -n "$CANDJSON" ]; then
  echo
  echo "- 候補ファイル: \`$(basename "$CANDJSON")\`（更新 $(stat -f '%Sm' -t '%m-%d %H:%M' "$CANDJSON" 2>/dev/null)）"
else
  echo
  echo "- **候補ファイルが見つからない。** 過去に返信した相手の投稿も記録されていないため、"
  echo "  **実データが用意できない。** ここで中止する。"
  echo
  echo "> 作り話の投稿に返信させても、噛み合っているかの検証にならない。"
  echo "> 候補の取り方が分かるまで、生成は走らせない（費用も発生させない）。"
  echo
  echo "### workspace/data にあるそれらしいファイル"
  echo '```'
  ls -1t "$W/data" 2>/dev/null | grep -iE 'cand|trend|comment|target' | head -12
  echo '```'
  exit 1
fi

echo
echo "## 3. 書かせる（**$LIMIT 件だけ**）"
echo
export OPS_QUEUE_PATH="$W/data/post_queue.json"
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1], n=Number(process.argv[2]);
try{
  const raw=JSON.parse(fs.readFileSync(p,"utf8"));
  const arr=Array.isArray(raw)?raw:(raw.candidates||raw.items||raw.list||[]);
  const out=arr.slice(0,n).map(c=>({text:String(c.text||c.full_text||c.content||"")}))
                .filter(c=>c.text.trim());
  console.log(JSON.stringify(out));
}catch(e){ console.log("[]"); }
' "$CANDJSON" "$LIMIT" > /tmp/.cand.json 2>/dev/null

N="$("$NODE_BIN" -e 'console.log(JSON.parse(require("fs").readFileSync("/tmp/.cand.json","utf8")).length)' 2>/dev/null || echo 0)"
echo "- 使う候補: **${N} 件**"
if [ "${N:-0}" = "0" ]; then
  echo "- **候補の本文が取り出せない。中止。**（費用は発生させていない）"
  exit 1
fi

i=0
while [ "$i" -lt "$N" ]; do
  TARGET="$("$NODE_BIN" -e '
const a=JSON.parse(require("fs").readFileSync("/tmp/.cand.json","utf8"));
process.stdout.write(a[Number(process.argv[1])].text);
' "$i")"
  RES="$(printf '%s' "$TARGET" | "$NODE_BIN" -e '
let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
  console.log(JSON.stringify({trend:{text:d},kind:"comment"}));
});' | "$NODE_BIN" "$DEST/lib/asuka-reply.cjs" 2>&1 | tail -1)"

  echo
  echo "---"
  echo
  echo "**相手の投稿**"
  echo
  echo '> '"$(printf '%s' "$TARGET" | tr '\n' ' ' | cut -c1-180 | hide)"
  echo
  "$NODE_BIN" -e '
let o={}; try{ o=JSON.parse(process.argv[1]); }catch(e){ console.log("**生成器の出力が読めない**: "+String(process.argv[1]).slice(0,160)); process.exit(0); }
if(o.skip){ console.log("**返信しない** — "+(o.reason||"")); }
else if(o.text){
  console.log("**返信案**");
  console.log("");
  console.log("> "+o.text);
  console.log("");
  console.log("- 共有した語: `"+((o.shared||[]).join(", ")||"（なし）")+"`");
  if((o.warns||[]).length) console.log("- warn: "+o.warns.join(" / "));
} else { console.log("**空の出力**"); }
' "$RES" 2>&1 | hide | mask
  i=$((i+1))
done

echo
echo "---"
echo
echo "## 4. 読むときの見どころ"
echo
echo "- **相手の投稿の具体語に触れているか**（触れていなければ、どの投稿にも貼れる文）"
echo "- **締めが毎回ちがうか**（実物 15 件は 4 型を 2 回ずつ使い回していた）"
echo "- **絵文字が毎回付いていないか**（実物は全 15 件に 1 つ付いていた）"
echo "- **命令形になっていないか**（実物は 15 件中 5 件）"
echo "- **「返信しない」が出ているか**（無理に返さない判断ができている証拠）"
echo
echo "**投稿はしていない。** 気に入らなければ \`ops/data/reply-style-prompt.json\` を直す。"
echo "コードは触らなくてよい。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
rm -f /tmp/.cand.json
if grep -q '返信案' "$OUT" 2>/dev/null; then echo "**生成した（投稿なし）** / $(basename "$OUT")"
elif grep -q '候補ファイルが見つからない' "$OUT" 2>/dev/null; then echo "候補が用意できず中止（費用0）/ $(basename "$OUT")"
else echo "生成できていない / $(basename "$OUT")"; fi
