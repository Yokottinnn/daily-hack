#!/bin/bash
# **chaosmap に要る素材がどこに在るかを探す（t190）。測るだけ。LLM 不使用・$0。**
#
# ## t188 は「sns-templates が無い」で止まった
#
# | 探した場所 | 在るか |
# | --- | --- |
# | `/Users/ny/projects/anta-baka-x/blog` | ✅ **リポジトリはここ**（`ny_taxa` ではなかった） |
# | `/Users/ny/projects/anta-baka-x/sns-templates` | ❌ |
# | `/Users/ny_taxa/projects/anta-baka-x/sns-templates` | ❌ |
#
# **推測で次を撃たない**（最上位ルール 15）。**先に測る。**
#
# ## `render-chaosmap.mjs` が要るのは 3 つだけ
#
#   ① フォント    `rocknroll-one-japanese-400.woff2` / `zen-maru-gothic-japanese-{400,700}.woff2`
#   ② マスコット  `assets-transparent/expr-*.png`
#   ③ playwright  **これは在る**（`~/.openclaw/workspace/node_modules`・t188 で確認済み）
#
# **②はブログのリポジトリにも在るかもしれない**（`public/images/expr-*.png`）。
# だとすれば要るのは**フォントだけ**になる。そこまで含めて見る。
#
# ## 探し方
#
# **名前で探す。** `sns-templates` というディレクトリ名に賭けない。
# 名前が変わったのか、消えたのか、別の場所に移ったのかを区別する。
#
# **深さを切って暴走させない。** `find` に `-maxdepth` を必ず付ける。
#
# **60 秒 で打ち切る**（最上位ルール 15）。読むだけ。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t190-find-sns-assets.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"

{
  echo "# chaosmap の素材はどこに在るか（t190・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**測るだけ。直さない。** t188 が \`sns-templates\` 無しで止まったため、"
  echo "**推測で次を撃たない**（最上位ルール 15）。"
  echo ""
} > "$OUT"

START=$(date +%s)

# --- ① projects の下に何が在るか（**名前が変わった可能性**） ---
{
  echo "## ① \`~/projects\` の中身"
  echo ""
  echo '```'
} >> "$OUT"
ls -1 "$HOME/projects" 2>/dev/null | head -20 >> "$OUT" || echo "（~/projects が無い）" >> "$OUT"
echo '```' >> "$OUT"
{
  echo ""
  echo '```'
} >> "$OUT"
ls -1 "$HOME/projects/anta-baka-x" 2>/dev/null | head -20 >> "$OUT" || echo "（anta-baka-x が無い）" >> "$OUT"
echo '```' >> "$OUT"
echo "" >> "$OUT"

# --- ② フォントを名前で探す（**これが本命**） ---
{
  echo "## ② フォント（\`rocknroll\` / \`zen-maru\`）"
  echo ""
  echo '```'
} >> "$OUT"
find "$HOME" -maxdepth 6 \( -iname 'rocknroll*.woff2' -o -iname 'zen-maru*.woff2' \) \
  2>/dev/null | head -10 >> "$OUT" || true
echo '```' >> "$OUT"
echo "" >> "$OUT"

# --- ③ マスコット（**ブログのリポジトリにも在るかもしれない**） ---
{
  echo "## ③ マスコット（\`expr-*.png\`）"
  echo ""
  echo "- ブログのリポジトリ: \`$REPO/public/images/\`"
  echo ""
  echo '```'
} >> "$OUT"
ls -1 "$REPO/public/images/" 2>/dev/null | grep -E '^expr-' | head -12 >> "$OUT" || echo "（無い）" >> "$OUT"
echo '```' >> "$OUT"
{
  echo ""
  echo "- \`assets-transparent\` という名前のディレクトリ:"
  echo ""
  echo '```'
} >> "$OUT"
find "$HOME" -maxdepth 6 -type d -name 'assets-transparent' 2>/dev/null | head -5 >> "$OUT" || true
echo '```' >> "$OUT"
echo "" >> "$OUT"

# --- ④ sns-templates という名前そのもの ---
{
  echo "## ④ \`sns-templates\` という名前"
  echo ""
  echo '```'
} >> "$OUT"
find "$HOME" -maxdepth 6 -type d -name '*sns-template*' 2>/dev/null | head -5 >> "$OUT" || true
echo '```' >> "$OUT"
echo "" >> "$OUT"

# --- ⑤ 他の render-*.mjs が同じ場所を見ている。動いた形跡が在るか ---
{
  echo "## ⑤ 直近に作られた図が在るか（**過去に動いた証拠**）"
  echo ""
  echo '```'
} >> "$OUT"
ls -lT "$REPO/public/images/point-service-complete-guide-2026/" 2>/dev/null \
  | grep -E 'chaosmap|eyecatch' >> "$OUT" || echo "（見つからない）" >> "$OUT"
echo '```' >> "$OUT"

{
  echo ""
  echo "---"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "**読み方**"
  echo ""
  echo "- ②でフォントが見つかれば、**\`SNS_DIR\` ではなく個別のパスを渡せば動く**"
  echo "- ③でマスコットがリポジトリに在れば、**\`sns-templates\` は要らない**"
  echo "- ②③とも無ければ、**素材ごと消えている。** 図は作り直せないので、"
  echo "  そう報告して別の手（記事側で図を差し替える等）を考える"
} >> "$OUT"

cat "$OUT"
