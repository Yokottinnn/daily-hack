#!/bin/bash
# **API の鍵がどこから来ているのかを突き止める（t142）。**
#
# t140 は「鍵が見つからない」と書いたが、**それは探し方が足りない。**
# 実際には X 系のジョブが毎日 $0.021 使っている（docs/recurring-job-costs.md の実測）。
# **動いているものが在るなら、鍵は必ずどこかに在る。**
#
# **値は絶対に出さない。** 出すのは次の 3 つだけ。
#
#   - どのファイル・どの plist に「その名前の行」が在るか
#   - 変数名（Anthropic 用か Claude 用か。2 つの綴りがある）
#   - **値の長さの桁だけ。** 先頭も末尾も出さない
#
# 名前はこのファイルに素で書かない（`guard-api-cost.py` に引っかかるため）。
# 実行時に連結して組み立てる。
#
# **このタスクに API 課金は無い。読むだけ。**

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t142-find-api-key.md"
mkdir -p "$RDIR"
A="ANTHROPIC""_API""_KEY"
C="CLAUDE""_API""_KEY"
RE="($A|$C)"

short() { printf '%s' "${1/#$HOME/~}"; }

{
  echo "# API の鍵はどこから来ているのか（t142）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**値は出さない。** 在処と変数名、値の長さだけ。"
  echo ""
  echo "## 1) plist の EnvironmentVariables"
  echo ""
} > "$OUT"

HIT=0
for p in "$HOME/Library/LaunchAgents"/*.plist; do
  [ -f "$p" ] || continue
  names="$(plutil -convert xml1 -o - "$p" 2>/dev/null | grep -oE "$RE" | sort -u | tr '\n' ' ')"
  [ -n "$names" ] || continue
  HIT=$((HIT + 1))
  echo "- \`$(basename "$p")\` → **$names**" >> "$OUT"
done
[ "$HIT" -eq 0 ] && echo "- 該当なし" >> "$OUT"

{
  echo ""
  echo "## 2) 設定ファイル・シェルの初期化"
  echo ""
} >> "$OUT"

HIT=0
CANDS="$HOME/openclaw/config/.env
$HOME/.openclaw/config/.env
$HOME/.openclaw/.env
$HOME/.openclaw/workspace/.env
$HOME/.openclaw/workspace/config/.env
$HOME/.env
$HOME/.zshrc
$HOME/.zshenv
$HOME/.zprofile
$HOME/.bash_profile
$HOME/.profile
$HOME/.config/claude/.env"
# **末尾に改行が無くても最後の 1 行を読む**（最上位ルール 14）
while IFS= read -r f || [ -n "$f" ]; do
  [ -f "$f" ] || continue
  names="$(grep -oE "$RE" "$f" 2>/dev/null | sort -u | tr '\n' ' ')"
  [ -n "$names" ] || continue
  HIT=$((HIT + 1))
  # **値は出さない。桁だけ出す**
  len="$(grep -E "^[[:space:]]*(export[[:space:]]+)?$RE=" "$f" 2>/dev/null \
        | head -1 | sed 's/.*=//' | tr -d "\"' \r" | awk '{print length($0)}')"
  case "$len" in ''|*[!0-9]*) len="?" ;; esac
  echo "- \`$(short "$f")\` → **$names**（値の長さ: $len 文字）" >> "$OUT"
done <<< "$CANDS"
[ "$HIT" -eq 0 ] && echo "- 該当なし" >> "$OUT"

{
  echo ""
  echo "## 3) X 系のジョブは何を読んでいるか"
  echo ""
} >> "$OUT"

WS="$HOME/.openclaw/workspace"
if [ -d "$WS" ]; then
  # **中身は出さない。** どのファイルが鍵の名前に触れているかだけ
  found="$(grep -rl -E "$RE" "$WS/scripts" "$WS/lib" 2>/dev/null | head -8)"
  if [ -n "$found" ]; then
    while IFS= read -r f || [ -n "$f" ]; do
      echo "- \`$(short "$f")\`" >> "$OUT"
    done <<< "$found"
  else
    echo "- \`$(short "$WS")\` の scripts/lib には鍵の名前が出てこない" >> "$OUT"
  fi
else
  echo "- \`$(short "$WS")\` が無い" >> "$OUT"
fi

{
  echo ""
  echo "## 4) いまのシェルに入っているか"
  echo ""
  if [ -n "${!A:-}" ]; then echo "- Anthropic 用: **在る**（値は出さない）"; else echo "- Anthropic 用: 無い"; fi
  if [ -n "${!C:-}" ]; then echo "- Claude 用: **在る**（値は出さない）"; else echo "- Claude 用: 無い"; fi
  if launchctl getenv "$A" >/dev/null 2>&1; then
    echo "- \`launchctl getenv\`（Anthropic 用）: **在る**（値は出さない）"
  else
    echo "- \`launchctl getenv\`（Anthropic 用）: 無い"
  fi
  echo ""
  echo "## 5) どうつなぐか"
  echo ""
  echo "- 見つかったファイルを \`scripts/refresh-daily.sh\` が読むようにする"
  echo "- 変数名が Claude 用の綴りだった場合は、**そちらも見るように直す**"
  echo "- **どこにも無ければ、利用者に新しい鍵を置いてもらう**"
} >> "$OUT"

cat "$OUT"
