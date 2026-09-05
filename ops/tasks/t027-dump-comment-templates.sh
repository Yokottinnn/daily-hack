#!/bin/bash
# **テンプレ本体 37 件を取る。t026 で場所を間違えたのでやり直し。費用 $0。**
#
# ## t026 で分かったこと・外したこと
#
# 分かった:
#   - キャラは v3 ブランド「**ハッカー子**」。一人称「アタシ」は**実装で固定**されている
#     （私が想像で書いたものと偶然 一致していただけで、根拠は無かった）
#   - 出力の契約は `{ok, text, template_id, weight, attempts}`。**`ok` が要る。**
#     私の `asuka-reply.cjs` は `{text}` しか返しておらず、orchestrator の
#     `GEN_OK != "true"` で**全件 無言で落ちるところだった**
#   - ゲートの挿し込み位置: `asuka-fill.js` → `tone-gate.cjs` → **ここ** → `enqueue`
#
# 外した:
#   - **テンプレは `asuka-fill.js` の中に無い。** `data/comment-templates.json` にある。
#     私が出したのは選定プロンプトで、テンプレ本体ではなかった。
#
# ## 出すもの（すべて無料・LLM を呼ばない）
#
#   1. **`comment-templates.json` の 37 件を全文**（id / category / scenario / template）
#   2. `asuka-fill.js` のブランド定義（**キャラの規則が書いてある本文**）
#   3. `tone-gate.cjs` の入出力の形（**同じ形でゲートを足すため**）
#   4. `weightOf` と MAX_WEIGHT（**文の重さの制約**。これも声の一部）
#
# ## やらないこと
#
# **書き換えない。生成しない。enqueue しない。投稿しない。ジョブも戻さない。**
#
# **API キーは値を出さない。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/comment-templates.md"
TPL="$W/data/comment-templates.json"
AF="$W/scripts/asuka-fill.js"
TG="$W/scripts/tone-gate.cjs"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# テンプレ本体 37 件（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> \`t026\` は場所を間違えた。テンプレは \`asuka-fill.js\` の中ではなく"
echo "> **\`data/comment-templates.json\`** にある。ここで本体を取る。"
echo "> **LLM を 1 回も呼ばない。書き換えない。投稿しない。**"

echo
echo "## 1. テンプレ 37 件（**本体**）"
echo
if [ ! -f "$TPL" ]; then
  echo "- **無い**（$TPL）"
else
  echo "- $(wc -c < "$TPL" | tr -d ' ') B / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$TPL" 2>/dev/null)"
  echo
  echo '```text'
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const arr=Array.isArray(d)?d:(d.templates||d.list||Object.values(d).find(v=>Array.isArray(v))||[]);
  console.log("件数: "+arr.length);
  console.log("");
  for(const t of arr){
    const id=t.id||t.template_id||"?";
    const cat=t.category||t.family||"";
    const sc=t.scenario||t.when||"";
    const tp=t.template||t.text||t.body||"";
    console.log(`[${id}] ${cat}${sc?" / "+sc:""}`);
    console.log(`    ${String(tp).replace(/\n/g," ")}`);
  }
}catch(e){ console.log("読めない: "+e.message); }
' "$TPL" 2>&1 | hide | mask
  echo '```'
fi

echo
echo "## 2. ブランド定義（\`asuka-fill.js\` の規則本文）"
echo
echo "**キャラの規則がここに文章で書いてある。想像で書き直さないため、そのまま出す。**"
echo
echo '```text'
sed -n '28,84p' "$AF" 2>/dev/null | cut -c1-200 | hide | mask
echo '```'

echo
echo "## 3. \`tone-gate.cjs\` の入出力（**同じ形でゲートを足すため**）"
echo
if [ -f "$TG" ]; then
  echo "- $(wc -l < "$TG" | tr -d ' ') 行"
  echo
  echo '```javascript'
  grep -nE 'stdin|stdout|JSON\.parse|JSON\.stringify|ok *:|\.ok|process\.exit|module\.exports|function ' "$TG" 2>/dev/null \
    | head -30 | cut -c1-190 | hide | mask
  echo '```'
else
  echo "- **無い**（$TG）"
fi

echo
echo "## 4. 文の重さの制約（\`weightOf\` / MAX_WEIGHT）"
echo
echo "**これも声の一部。** 長さや漢字の量に上限があるなら、書き下ろし側にも同じ制約が要る。"
echo
echo '```javascript'
grep -nE 'MAX_WEIGHT|weightOf|function weight|weight *=|length' "$AF" 2>/dev/null \
  | head -20 | cut -c1-190 | mask
echo '```'
echo
echo "### 実装の中身"
echo '```javascript'
sed -n '16,26p' "$AF" 2>/dev/null | cut -c1-190 | mask
echo '```'

echo
echo "---"
echo
echo "**何も書き換えていない。LLM も呼んでいない（\$0）。**"
echo "次はこの 37 件から声を抜き出して \`reply-style-prompt.json\` に入れ直す。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '件数: ' "$OUT" 2>/dev/null; then echo "**テンプレ本体を取れた（変更なし・\$0）** / $(basename "$OUT")"
else echo "テンプレ本体を取れなかった / $(basename "$OUT")"; fi
