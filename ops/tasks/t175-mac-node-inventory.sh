#!/bin/bash
# **Mac の node まわりを棚卸しする（t175）。測るだけ。直さない。LLM 不使用・$0。**
#
# ## なぜ測るタスクを分けるか
#
# **2 回 続けて「無い」で止まった。**
#
# | 回 | 止まった理由 | 分かったこと |
# | --- | --- | --- |
# | t173 | `@anthropic-ai/sdk` を**入れられなかった** | **理由が出ていない**（出力を捨てていた） |
# | t174 | **`playwright-core` が無い** | CDP は生きている（Chrome 140） |
#
# **推測で 3 回目を撃たない。** 最上位ルール 15 の
# 「測るものと直すものを同じタスクに入れない」に従って、**先に測る。**
#
# ## 何を測るか
#
#   ① node / npm が**どこに在るか**（launchd 由来の PATH も出す）
#   ② `playwright-core` が**どこかに在るか**（X のループは動いているので在るはず）
#   ③ `@anthropic-ai/sdk` が**どこかに在るか**
#   ④ ブログの `node_modules` は**そもそも在るか**
#
# **秘密は出さない。** パスとバージョンだけ。
#
# **60 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t175-mac-node-inventory.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"

{
  echo "# Mac の node まわりの棚卸し（t175・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**測るだけ。直さない。** t173 / t174 が 2 回 続けて「無い」で止まったため、"
  echo "**推測で 3 回目を撃たない**（最上位ルール 15）。"
  echo ""
} > "$OUT"

# --- ① node / npm はどこに在るか ---
{
  echo "## ① node / npm"
  echo ""
  echo "| | 場所 | 版 |"
  echo "| --- | --- | --- |"
} >> "$OUT"

row() {  # $1=名前 $2=パス
  local name="$1" p="$2" v="—"
  if [ -n "$p" ] && [ -x "$p" ]; then
    v="$("$p" -v 2>/dev/null | head -1)"
    echo "| $name | \`$p\` | ${v:-（版が出ない）} |" >> "$OUT"
  else
    echo "| $name | ❌ **無い** | — |" >> "$OUT"
  fi
}

NODE_P="$(command -v node || true)"
row "node（PATH）" "$NODE_P"
row "node（Homebrew）" "/opt/homebrew/bin/node"
row "npm（PATH）" "$(command -v npm || true)"
[ -n "$NODE_P" ] && row "npm（node の隣）" "$(dirname "$NODE_P")/npm"
row "npm（Homebrew）" "/opt/homebrew/bin/npm"

{
  echo ""
  echo "**この周回の \`PATH\`**（launchd 由来かどうかがここで分かる）"
  echo ""
  echo '```'
  printf '%s\n' "$PATH" | tr ':' '\n'
  echo '```'
  echo ""
} >> "$OUT"

# --- ② playwright-core はどこかに在るか ---
{
  echo "## ② \`playwright-core\` の在りか"
  echo ""
  echo "**X のループは Playwright で動いている**ので、どこかには在るはず。"
  echo ""
  echo '```'
} >> "$OUT"
for d in "$REPO" "$HOME/.openclaw/workspace" "$HOME/openclaw/workspace" "$HOME"; do
  [ -d "$d/node_modules/playwright-core" ] && echo "$d/node_modules/playwright-core" >> "$OUT"
done
# **見つからなければ探す。** 深さを切って暴走させない
find "$HOME/.openclaw" "$HOME/openclaw" -maxdepth 4 -type d -name playwright-core 2>/dev/null | head -5 >> "$OUT" || true
echo '```' >> "$OUT"
echo "" >> "$OUT"

# --- ③ @anthropic-ai/sdk はどこかに在るか ---
{
  echo "## ③ \`@anthropic-ai/sdk\` の在りか"
  echo ""
  echo '```'
} >> "$OUT"
for d in "$REPO" "$HOME/.openclaw/workspace" "$HOME/openclaw/workspace"; do
  [ -d "$d/node_modules/@anthropic-ai/sdk" ] && echo "$d/node_modules/@anthropic-ai/sdk" >> "$OUT"
done
find "$HOME/.openclaw" "$HOME/openclaw" -maxdepth 5 -type d -path '*@anthropic-ai/sdk' 2>/dev/null | head -5 >> "$OUT" || true
echo '```' >> "$OUT"
echo "" >> "$OUT"

# --- ④ ブログの node_modules はそもそも在るか ---
{
  echo "## ④ ブログの \`node_modules\`"
  echo ""
} >> "$OUT"
if [ -d "$REPO/node_modules" ]; then
  N=$(ls -1 "$REPO/node_modules" 2>/dev/null | wc -l | head -1 | tr -d ' ')
  case "$N" in ''|*[!0-9]*) N=0 ;; esac
  echo "- \`$REPO/node_modules\` は **在る**（直下 **$N 項目**）" >> "$OUT"
  echo "- \`astro\` は $( [ -d "$REPO/node_modules/astro" ] && echo '**在る**' || echo '❌ 無い' )" >> "$OUT"
  # **書き込めるか。** 権限で失敗している可能性を潰す
  if touch "$REPO/node_modules/.t175-write-test" 2>/dev/null; then
    rm -f "$REPO/node_modules/.t175-write-test"
    echo "- 書き込み **できる**" >> "$OUT"
  else
    echo "- ⚠️ **書き込めない**（権限）" >> "$OUT"
  fi
else
  echo "- ❌ **`node_modules` が無い。** ブログのビルドはどこで走っている？" >> "$OUT"
fi

# --- おまけ: npm が本当に動くか（**入れはしない**） ---
{
  echo ""
  echo "## ⑤ npm は動くか（**何も入れない**）"
  echo ""
  echo '```'
} >> "$OUT"
NPM_TRY="$( [ -n "$NODE_P" ] && echo "$(dirname "$NODE_P")/npm" || echo "" )"
[ -x "$NPM_TRY" ] || NPM_TRY="$(command -v npm || true)"
if [ -n "$NPM_TRY" ] && [ -x "$NPM_TRY" ]; then
  ( cd "$REPO" 2>/dev/null && "$NPM_TRY" ls --depth=0 2>&1 | head -12 ) >> "$OUT" || true
else
  echo "npm が見つからないので試していない" >> "$OUT"
fi
echo '```' >> "$OUT"

{
  echo ""
  echo "---"
  echo ""
  echo "**読み方**"
  echo ""
  echo "- **npm が PATH に無く、node の隣にも無い**なら、launchd の PATH を疑う"
  echo "- **\`playwright-core\` が別の場所に在る**なら、入れ直さずに \`NODE_PATH\` で通す"
  echo "- **\`node_modules\` に書き込めない**なら、入れる話ではなく権限の話"
  echo ""
  echo "**次に何を直すかは、この結果を見てから決める。**"
} >> "$OUT"

cat "$OUT"
