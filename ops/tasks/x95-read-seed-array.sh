#!/bin/bash
# **種アカウントの配列そのものを読む。直さない。費用 $0。**
#
# ## x94 で場所が確定した
#
#   一覧は **`scripts/competitor-follower-follow.js` に直書き**されている
#   回し方は **`day-of-week mod len(competitors)`**（1 日 1 種・7 種で週 1 巡）
#
# つまり **1 つの種が全体の 1/7 を占める。** 返り率の悪い種を 1 つ 残すと、
# **週に 1 日ぶんのフォロー枠がそこに消える。**
#
# ## 何を読むか
#
# **配列の実物を 1 文字も変えずに出す。** 置き換えを当てるには、
# 置き換える文字列が**完全一致で 1 箇所だけ**であることを先に確かめる必要がある
# （x89 で使った作法）。**推測で書き換えない**（最上位ルール 14）。
#
# 併せて、**除外リストがあるか**（whitelist / skip）も見る。
# 配列から消すより、除外の仕組みがあるならそちらのほうが安全なことがある。
#
# ## やらないこと
#
# **書き換えない。消さない。フォローしない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
F="$S/competitor-follower-follow.js"
OUT="${OPS_REPORT_DIR:-/tmp}/seed-array.md"

secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }

{
echo "# 種アカウントの配列"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x94 で確定: 一覧は **\`competitor-follower-follow.js\` に直書き**、"
echo "> 回し方は **\`day-of-week mod len(competitors)\`**（1 日 1 種・7 種で週 1 巡）。"
echo ">"
echo "> **1 つの種が全体の 1/7。** 返り率 4.2% の種を残すと、週 1 日ぶんがそこに消える。"
echo
echo "**読むだけ。1 文字も変えない。**"

echo
echo "## 1. ファイルの基本情報"
echo
echo '```'
if [ ! -f "$F" ]; then
  echo "  **$F が無い。**"
  ls -1 "$S" 2>/dev/null | grep -i competitor | sed 's/^/    候補: /'
else
  echo "  $(wc -l < "$F" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$F" 2>/dev/null)"
fi
echo '```'

echo
echo "## 2. **配列の実物**（行番号つき・そのまま）"
echo
echo '```javascript'
if [ -f "$F" ]; then
  # 種の名前が出てくる行の前後を広めに出す
  LN="$(grep -n -F 'ukk_hx' "$F" 2>/dev/null | head -1 | cut -d: -f1)"
  if [ -n "$LN" ]; then
    A=$(( LN > 12 ? LN - 12 : 1 )); B=$(( LN + 14 ))
    awk -v a="$A" -v b="$B" 'NR>=a && NR<=b {printf("%4d| %s\n", NR, $0)}' "$F" | cut -c1-200 | secrets
  else
    echo "  **ukk_hx がこのファイルに無い。** 種を持っていそうな行:"
    grep -n -E 'COMPETITOR|competitors|const .*= *\[' "$F" 2>/dev/null | head -10 \
      | cut -c1-190 | sed 's/^/  /' | secrets
  fi
fi
echo '```'

echo
echo "## 3. 回し方の実物（**day-rotation の箇所**）"
echo
echo '```javascript'
if [ -f "$F" ]; then
  grep -n -E 'dayIndex|day-of-week|getDay|% *COMPETITOR|% *competitors' "$F" 2>/dev/null \
    | head -8 | cut -c1-190 | sed 's/^/  /' | secrets
fi
echo '```'
echo
echo "**1 日 1 種なので、配列から外すだけで枠が良い種に回る。** 量は変わらない。"

echo
echo "## 4. 除外の仕組みがあるか（配列を触らずに済むか）"
echo
echo '```'
if [ -f "$F" ]; then
  grep -n -E 'skip|exclude|whitelist|blocklist|disabled|SKIP_' "$F" 2>/dev/null \
    | head -10 | cut -c1-190 | sed 's/^/  /' | secrets
  echo
  echo "  --- 環境変数で上書きできるか ---"
  grep -n -E 'process\.env\.[A-Z_]+' "$F" 2>/dev/null | head -12 | cut -c1-190 | sed 's/^/  /'
fi
echo '```'
echo
echo "**環境変数で種を渡せるなら、plist を書き換えるだけで済む。**"
echo "その場合、スクリプト本体を触らなくてよい（元に戻すのも簡単）。"

echo
echo "## 5. 費用"
echo
echo "**ソースを読むだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**種を入れ替える場合も \$0。** このジョブは DOM 操作のみで LLM を呼ばないため、"
echo "**フォロー数を変えても API 費用は動かない。**"
echo "返信ループの実測は 1 回 \$0.003 ／ 1 日 \$0.021 ／ 1 か月 約 \$0.63。"
} > "$OUT" 2>&1

echo "種の配列 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
