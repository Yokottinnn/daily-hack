#!/bin/bash
# **テンプレ 37 件を丸ごと読む。キャラの声をそこから引くため。費用 $0。**
#
# ## なぜこれが要るのか
#
# 方式は**新しい方（毎回 書き下ろす全文生成）のまま**。変えるのは**キャラ設定の出どころ**だけ。
#
#   これまで: `reply-style-prompt.json` のキャラ定義は **私が想像で書いた**
#             （「アタシ」「〜わよ」…）。だから元の声にならなかった。
#   これから: **テンプレ 37 件から実際の声を引く。** 想像で書かない。
#
# 2026-09-04 の指摘「元々のキャラの口調がぜんぜん反映されていない」の原因はここ。
# 全文生成が悪いのではなく、**渡していたキャラ定義が本物ではなかった。**
#
# ## 出すもの（すべて無料・LLM を呼ばない）
#
#   1. **テンプレ 37 件の全文**（これが本命。ここに本物の声がある）
#   2. テンプレの選び方（型がどう決まっているか）
#   3. `asuka-fill.js` の穴埋め語彙（`{placeholder}` に入る候補）
#   4. 実際に X に出た返信（キューから。**テンプレが実物でどう見えたか**）
#   5. `comment-orchestrator.sh` の `asuka-fill` / `enqueue` 呼び出し箇所
#      （あとでゲートを挟む場所。**推測で書かないため**）
#
# ## やらないこと
#
# **書き換えない。生成しない。enqueue しない。投稿しない。ジョブも戻さない。**
# `comment-warmup` は `t017` から止めたまま。**LLM を 1 回も呼ばない。**
#
# **API キーは値を出さない。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/templates-voice.md"
AF="$W/scripts/asuka-fill.js"
CO="$W/scripts/comment-orchestrator.sh"
QUEUE="$W/data/post_queue.json"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

ctx() { # ctx <file> <regex> <before> <after>
  local f="$1" re="$2" b="$3" a="$4" ln s
  grep -nE "$re" "$f" 2>/dev/null | cut -d: -f1 | while read -r ln; do
    s=$((ln - b)); [ "$s" -lt 1 ] && s=1
    echo "  ── $(basename "$f"):$ln ──"
    sed -n "${s},$((ln + a))p" "$f" 2>/dev/null | cut -c1-190
    echo
  done
}

{
echo "# テンプレ 37 件の実物（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> 方式は**新しい方（全文生成）のまま**。引き継ぐのは**キャラ設定だけ**。"
echo "> これまでのキャラ定義は**私が想像で書いたもの**で、テンプレ由来ではなかった。"
echo "> **だから元の声にならなかった。** ここで本物を読む。"
echo "> **LLM を 1 回も呼ばない。書き換えない。投稿しない。**"

echo
echo "## 0. ファイル"
echo
[ -f "$AF" ] || { echo "- \`asuka-fill.js\` が**無い**（$AF）。中止。"; exit 1; }
echo "- \`asuka-fill.js\`: $(wc -l < "$AF" | tr -d ' ') 行 / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$AF" 2>/dev/null)"
echo
echo "テンプレが外部ファイルにあるかも見る:"
echo '```'
ls -1 "$W/data"/*.json 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -iE 'templ|reply|asuka|comment|tone' || echo "（該当なし＝テンプレは asuka-fill.js の中）"
echo '```'

echo
echo "## 1. テンプレ全文（**本命**）"
echo
echo "\`asuka-fill.js\` の中の文字列リテラルを、絵文字や語尾ごと**そのまま**出す。"
echo
echo '```javascript'
# テンプレは「日本語を含むクォート文字列」。行番号つきで全部出す。
grep -nE '["'"'"'`][^"'"'"'`]*[ぁ-んァ-ヴ一-龠][^"'"'"'`]*["'"'"'`]' "$AF" 2>/dev/null \
  | head -120 | cut -c1-200 | hide | mask
echo '```'

echo
echo "## 2. 型の選び方（どのテンプレが選ばれるか）"
echo
echo '```javascript'
grep -nE 'TEMPLATES|templates|T[0-9]{2}|pick|match|choose|score|weight|random|filter|kind|tag' "$AF" 2>/dev/null \
  | head -35 | cut -c1-190 | hide | mask
echo '```'

echo
echo "## 3. 穴埋めの語彙（\`{...}\` に入るもの）"
echo
echo '```javascript'
grep -nE '\{[a-zA-Z_]+\}|replace\(|placeholder|slot|fill' "$AF" 2>/dev/null \
  | head -30 | cut -c1-190 | hide | mask
echo '```'

echo
echo "## 4. 実際に X に出た返信（**テンプレが実物でどう見えたか**）"
echo
if [ -f "$QUEUE" ]; then
  echo '```'
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const c=(q.queue||[]).filter(e=>String(e.kind||"")==="comment"&&e.text).slice(-25);
  if(!c.length){ console.log("（comment が 1 件も無い）"); }
  c.forEach((e,i)=>console.log(String(i+1).padStart(2)+". "+String(e.text).replace(/\n/g," ")));
}catch(e){ console.log("キューが読めない: "+e.message); }
' "$QUEUE" 2>&1 | cut -c1-190 | hide | mask
  echo '```'
else
  echo "- キューが無い（$QUEUE）"
fi

echo
echo "## 5. ゲートを挟む場所（**あとで使う。推測で書かないため**）"
echo
echo "### \`asuka-fill\` の呼び出し"
echo '```bash'
ctx "$CO" 'asuka-fill' 10 20 | hide | mask
echo '```'
echo
echo "### \`enqueue\` の呼び出し"
echo '```bash'
ctx "$CO" 'enqueue' 8 10 | hide | mask
echo '```'

echo
echo "## 6. 返信ジョブが止まったままであることの確認"
echo
echo '```'
launchctl list 2>/dev/null | grep -E 'comment-warmup|reply|follow' | cut -c1-120 || echo "（該当なし）"
echo '```'

echo
echo "---"
echo
echo "**何も書き換えていない。LLM も呼んでいない（\$0）。**"
echo "次は 1 章の実物から声を抜き出して \`reply-style-prompt.json\` に入れ直す。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'テンプレ全文' "$OUT" 2>/dev/null; then echo "**テンプレを読めた（変更なし・\$0）** / $(basename "$OUT")"
else echo "読み出せなかった / $(basename "$OUT")"; fi
