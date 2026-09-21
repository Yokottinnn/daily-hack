#!/bin/bash
# **FX 7 社のロゴを取る（t150）。LLM 不使用・$0。**
#
# `fx-account-comparison-2026` は**見出しに 8 社 並んでいるのにロゴが 1 つも無い**
# （最上位ルール 17）。
#
# **取りに行く前にリポジトリを見た**（blog-article スキル）。
# **楽天証券だけ在った**（`nisa-investment-beginner-guide-2026/logos/rakutensec.png`・
# 目で見て確認済み）。**残り 7 社。**
#
# ## t146〜t149 で学んだこと
#
# | やったこと | 結果 |
# | --- | --- |
# | コモンズを名前で検索 | **全滅。** 別物ばかり返る（バラの品種・NASA の試験片） |
# | 公式の `<img ... logo>` | **当たることもあるが、別サービスのロゴが混ざる** |
# | `og:image` | **バナーのことが多い** |
# | `apple-touch-icon` | **ブランドマークであることが多い** |
#
# **だから 3 つを一度に取って、まとめて目で見る。** 1 社ずつ往復しない
# （1 往復 30 分かかる経路なので、**取りこぼすと次の周回まで待つ**）。
#
# **alt を必ず出す。** ファイル名では別サービスと見分けがつかない
# （`logo_pitzero.jpg` が別会場だった前例）。
#
# **判断はしない。採否はクラウド側でコンタクトシートにして決める。**
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t150-fx-logos.md"
DIR="$RDIR/logos-fx"
mkdir -p "$DIR"
UA="daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"

{
  echo "# FX 7 社のロゴ（t150・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**判断はしない。候補を持ち帰るだけ。**"
  echo "**楽天証券はリポジトリに在ったので対象外。**"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 240 ]; }

save() {  # $1=保存名 $2=URL
  local name="$1" url="$2" ext="png" n
  case "$url" in *.jpg*|*.jpeg*) ext="jpg" ;; *.gif*) ext="gif" ;; *.svg*) ext="svg" ;; esac
  curl -sS -L --max-time 15 -A "$UA" -o "$DIR/$name.$ext" "$url" 2>/dev/null || return 1
  n=$(wc -c < "$DIR/$name.$ext" | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -le 200 ]; then rm -f "$DIR/$name.$ext"; return 1; fi
  echo "  - ⬇️ \`$name.$ext\`（**$n bytes**）← \`$(printf '%s' "$url" | head -c 100)\`" >> "$OUT"
  return 0
}

visit() {  # $1=キー $2=ブランド名 $3=URL
  local key="$1" jp="$2" url="$3" html base i=0 src alt u
  { echo "## $jp"; echo ""; echo "\`$url\`"; echo ""; } >> "$OUT"
  html="$(curl -sS -L --max-time 20 -A "$UA" "$url" 2>/dev/null)" || html=""
  if [ -z "$html" ]; then
    echo "- ⚠️ **開けない**" >> "$OUT"; echo "" >> "$OUT"; return
  fi
  base="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')"
  echo "- HTML **$(printf '%s' "$html" | wc -c | tr -d ' ') bytes**" >> "$OUT"

  # **alt ごと出す。** ファイル名では別サービスと見分けがつかない
  printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' | head -6 \
    | sed 's/^/  - /' >> "$OUT" || true

  # 1) img[logo] の実体を 2 件まで
  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    over && break
    case "$src" in
      http*) u="$src" ;;
      //*)   u="https:$src" ;;
      /*)    u="$base$src" ;;
      *)     continue ;;
    esac
    save "$key-img$i" "$u" && i=$((i + 1))
    [ "$i" -ge 2 ] && break
  done <<EOF
$(printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' \
  | grep -oE 'src="[^"]+"' | sed 's/^src="//; s/"$//' | head -4)
EOF

  # 2) og:image
  u="$(printf '%s' "$html" | grep -oE '<meta[^>]+og:image[^>]*>' | head -1 \
       | grep -oE 'content="[^"]+"' | sed 's/^content="//; s/"$//')"
  if [ -n "$u" ] && ! over; then
    case "$u" in /*) u="$base$u" ;; //*) u="https:$u" ;; esac
    save "$key-ogp" "$u" || true
  fi

  # 3) apple-touch-icon（**ブランドマークであることが多い**）
  u="$(printf '%s' "$html" | grep -oE '<link[^>]+apple-touch-icon[^>]*>' | head -1 \
       | grep -oE 'href="[^"]+"' | sed 's/^href="//; s/"$//')"
  if [ -n "$u" ] && ! over; then
    case "$u" in /*) u="$base$u" ;; //*) u="https:$u" ;; esac
    save "$key-icon" "$u" || true
  fi
  echo "" >> "$OUT"
}

# （キー, ブランド名, 公式 URL）**楽天証券は在庫があるので入れない**
visit "dmmfx"     "DMM FX"                    "https://fx.dmm.com/"
over || visit "gaitame"   "外為どっとコム"     "https://www.gaitame.com/"
over || visit "gmoclick"  "GMOクリック証券"    "https://www.click-sec.com/"
over || visit "minnafx"   "みんなのFX（トレイダーズ証券）" "https://min-fx.jp/"
over || visit "matsui"    "松井証券"           "https://www.matsui.co.jp/"
over || visit "sbifx"     "SBI FXトレード"     "https://www.sbifxt.co.jp/"
over || visit "monexfx"   "マネックス証券"     "https://www.monex.co.jp/"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | tr -d ' ') 件 持ち帰った。**"
  echo "**採否はクラウド側でコンタクトシートにして目で見て決める。**"
  echo "**別サービス・認証マーク・キャンペーンバナーが混ざる**ので、そのまま入れない。"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
