#!/bin/bash
# **全文生成に切り替える前に、いまの生成器の契約を読む。読むだけ。**
#
# 利用者の判断（2026-09-02）: 「テンプレをやめて全文生成」。
#
# ## 先に読む理由
#
# **推測で書くと外す。** 2026-08-30 に 3 回やった
# （`docs/x-post-latency-postmortem.md`）。今回も同じ轍を踏まない。
#
# 全文生成に替えるには、次が分かっていないと書けない。
#
#   1. `asuka-fill.js` の**入出力の形**（何を受けて何を返すか）
#   2. **SYSTEM プロンプトの全文**（テンプレ 37 件をどう渡しているか）
#   3. **相手の投稿の本文が、生成時に手元にあるか**
#      → あるなら記録もゲートもすぐ効く。無いなら取得から直す
#   4. `comment-orchestrator.sh` の呼び出し口（どこに差し込むか）
#   5. モデルと `max_tokens`（コスト見積もりの前提）
#
# **3 がいちばん重要。** 相手の投稿が手元に無いまま「全文生成」にしても、
# 噛み合う文は書けない。**そこが無ければ、全文生成より先に取得を直す。**
#
# ## 何も変えない
#
# 返信は `t017` で停止済み。このタスクは**読むだけ**で、停止も解除しない。
#
# **API キーは値を出さない。ハンドルは伏せる。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/generator-contract.md"
AF="$W/scripts/asuka-fill.js"
CO="$W/scripts/comment-orchestrator.sh"
TPL="$W/data/comment-templates.json"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{30,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# 生成器の契約を読む（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> 「テンプレをやめて全文生成」に替える前に、**実物を読む。**"
echo "> 推測で書くと外す（2026-08-30 に 3 回）。"

echo
echo "## 0. ファイルの所在"
echo
for f in "$AF" "$CO" "$TPL"; do
  if [ -f "$f" ]; then
    echo "- \`$(basename "$f")\`: **ある**（$(wc -l < "$f" | tr -d ' ') 行 / $(wc -c < "$f" | tr -d ' ') B）"
  else
    echo "- \`$(basename "$f")\`: **無い** ← 場所が違う"
  fi
done
echo
echo "### workspace/scripts にある返信まわりのファイル"
echo '```'
ls -1 "$W/scripts" 2>/dev/null | grep -iE 'asuka|comment|reply|tone|ng-filter' | head -20
echo '```'

echo
echo "## 1. \`asuka-fill.js\` の入出力"
echo
echo "### 引数・標準入力の受け方"
echo '```javascript'
grep -nE 'process\.argv|process\.stdin|JSON\.parse|require\(' "$AF" 2>/dev/null | head -20 | cut -c1-170 | mask
echo '```'
echo
echo "### 出力の形"
echo '```javascript'
grep -nE 'console\.log|JSON\.stringify|process\.stdout' "$AF" 2>/dev/null | head -15 | cut -c1-170 | mask
echo '```'

echo
echo "## 2. **相手の投稿は手元にあるか**（いちばん重要）"
echo
echo '```javascript'
grep -nE 'tweet|post|target|text|content|candidate|author' "$AF" 2>/dev/null \
  | grep -viE 'max_tokens|template' | head -25 | cut -c1-170 | hide | mask
echo '```'
echo
echo "**上に「相手の投稿の本文」を受け取っている行があるか**を見ること。"
echo "無ければ、全文生成より先に**取得から直す**。"

echo
echo "## 3. SYSTEM プロンプト（全文）"
echo
echo "> テンプレ 37 件をどう渡しているかが、そのまま**削れる入力トークン**になる。"
echo
echo '```'
"$(command -v node || echo node)" -e '
const fs=require("fs");
const s=fs.readFileSync(process.argv[1],"utf8");
// SYSTEM らしき長い文字列リテラルを丸ごと出す
const m=s.match(/(?:const|let|var)\s+\w*(SYSTEM|SYS|PROMPT)\w*\s*=\s*([`"\x27])([\s\S]*?)\2/i);
if(m){ console.log(m[3].slice(0,3000)); }
else {
  const i=s.search(/system\s*:/i);
  console.log(i>=0 ? s.slice(i, i+2000) : "(SYSTEM らしき箇所が見つからない)");
}
' "$AF" 2>&1 | mask
echo '```'

echo
echo "## 4. モデルと max_tokens（コスト見積もりの前提）"
echo
echo '```javascript'
grep -nE 'model|max_tokens|temperature|claude-|haiku|sonnet' "$AF" 2>/dev/null | head -12 | cut -c1-170 | mask
echo '```'

echo
echo "## 5. テンプレの渡し方（**削れる量**）"
echo
if [ -f "$TPL" ]; then
  echo "- \`comment-templates.json\`: $(wc -c < "$TPL" | tr -d ' ') B"
  echo "- 概算トークン（日本語は 1 文字 ≒ 1 トークンとして）: **約 $(( $(wc -m < "$TPL" | tr -d ' ') )) tok**"
fi
echo '```javascript'
grep -nE 'comment-templates|templates|readFileSync.*template' "$AF" 2>/dev/null | head -10 | cut -c1-170 | mask
echo '```'

echo
echo "## 6. \`comment-orchestrator.sh\` の呼び出し口"
echo
echo '```bash'
grep -nE 'asuka-fill|tone-gate|enqueue|ng-filter|TWEET|TEXT=|CAND' "$CO" 2>/dev/null \
  | head -25 | cut -c1-170 | hide | mask
echo '```'
echo
echo "### enqueue に渡している中身"
echo '```bash'
grep -nB3 -A8 'enqueue' "$CO" 2>/dev/null | head -30 | cut -c1-170 | hide | mask
echo '```'

echo
echo "## 7. 判断"
echo
echo "**結論は書かない。** 上を読んで次を決める。"
echo
echo "- 相手の投稿が生成時に**手元にある** → 全文生成に替えられる。記録もすぐ入る"
echo "- **手元に無い** → 先に取得を直す。全文生成はその後"
echo "- テンプレの渡し方が分かれば、**削れる入力トークン＝下がる月額**が確定する"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "生成器の契約を出した（変更なし）/ $(basename "$OUT")"
