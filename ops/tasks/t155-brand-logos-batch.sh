#!/bin/bash
# **在庫に無いブランドのロゴを、まとめて取る（t155）。LLM 不使用・$0。**
#
# **1 往復 30 分の経路**なので、1 社ずつ取りに行かない。まとめて取って、
# 採否はクラウド側でコンタクトシートを見て決める。
#
# ## 対象の選び方
#
# 見出しに出るブランド名から、**在庫に無いもの**を機械で拾ったうえで、
# **ブランドでないものを手で外した。**
#
#   外したもの: 「ライト層」「今日やることリスト」（見出しの語）
#               「グランドシティタワー月島」ほかタワマン名（**物件名。ブランドではない**）
#               「9棟・延べ約126万㎡」（数字）
#
# ## t146〜t153 で分かっていること
#
# | やり方 | 結果 |
# | --- | --- |
# | コモンズを名前で検索 | **全滅**（バラの品種・NASA の試験片が返った） |
# | 公式の `<img ... logo>` | 当たることもあるが**別サービスが混ざる** |
# | `og:image` | バナーのことが多い。**ただしカード会社は wordmark を置いていた** |
# | `apple-touch-icon` | **ブランドマークであることが多い** |
#
# **だから 3 つを一度に取る。alt も必ず出す。**
#
# **運営会社のロゴを、サービスのロゴとして使わない**（最上位ルール 17）。
# SMBC のロゴは Olive のロゴではない。**判断はクラウド側でやる。**
#
# **270 秒 で打ち切る**（最上位ルール 15）。残りは次の周回。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t155-brand-logos.md"
DIR="$RDIR/logos-batch"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"

{
  echo "# 在庫に無いブランドのロゴ（t155・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**判断はしない。候補を持ち帰るだけ。**"
  echo "**運営会社のロゴをサービスのロゴとして使わない**（最上位ルール 17）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 270 ]; }

save() {
  local name="$1" url="$2" ext="png" n
  case "$url" in *.jpg*|*.jpeg*) ext="jpg" ;; *.gif*) ext="gif" ;; *.svg*) ext="svg" ;; esac
  curl -sS -L --max-time 12 -A "$UA" -o "$DIR/$name.$ext" "$url" 2>/dev/null || return 1
  n=$(wc -c < "$DIR/$name.$ext" | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -le 200 ]; then rm -f "$DIR/$name.$ext"; return 1; fi
  echo "  - ⬇️ \`$name.$ext\`（**$n bytes**）← \`$(printf '%s' "$url" | head -c 96)\`" >> "$OUT"
  return 0
}

visit() {  # $1=キー $2=ブランド名 $3=URL
  local key="$1" jp="$2" url="$3" html base i=0 src u
  { echo "## $jp"; echo ""; echo "\`$url\`"; echo ""; } >> "$OUT"
  html="$(curl -sS -L --max-time 18 -A "$UA" "$url" 2>/dev/null)" || html=""
  if [ -z "$html" ]; then echo "- ⚠️ **開けない**" >> "$OUT"; echo "" >> "$OUT"; return; fi
  base="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')"
  echo "- HTML **$(printf '%s' "$html" | wc -c | tr -d ' ') bytes**" >> "$OUT"
  # **alt ごと出す。** ファイル名では別サービスと見分けがつかない
  printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' | head -5 \
    | sed 's/^/  - /' >> "$OUT" || true

  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    over && break
    case "$src" in
      http*) u="$src" ;; //*) u="https:$src" ;; /*) u="$base$src" ;; *) continue ;;
    esac
    save "$key-img$i" "$u" && i=$((i + 1))
    [ "$i" -ge 2 ] && break
  done <<EOF
$(printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' \
  | grep -oE 'src="[^"]+"' | sed 's/^src="//; s/"$//' | head -4)
EOF

  u="$(printf '%s' "$html" | grep -oE '<meta[^>]+og:image[^>]*>' | head -1 \
       | grep -oE 'content="[^"]+"' | sed 's/^content="//; s/"$//')"
  if [ -n "$u" ] && ! over; then
    case "$u" in /*) u="$base$u" ;; //*) u="https:$u" ;; esac
    save "$key-ogp" "$u" || true
  fi
  u="$(printf '%s' "$html" | grep -oE '<link[^>]+apple-touch-icon[^>]*>' | head -1 \
       | grep -oE 'href="[^"]+"' | sed 's/^href="//; s/"$//')"
  if [ -n "$u" ] && ! over; then
    case "$u" in /*) u="$base$u" ;; //*) u="https:$u" ;; esac
    save "$key-icon" "$u" || true
  fi
  echo "" >> "$OUT"
}

# 格安 SIM（cheap-sim-comparison-2026）
visit "rakutenmobile" "楽天モバイル" "https://network.mobile.rakuten.co.jp/"
over || visit "ahamo"  "ahamo"       "https://ahamo.com/"
over || visit "povo"   "povo 2.0"    "https://povo.jp/"
over || visit "linemo" "LINEMO"      "https://www.linemo.jp/"
over || visit "irumo"  "irumo"       "https://irumo.docomo.ne.jp/"
# 航空（narita-haneda-overseas-direct-2026）
over || visit "ana"    "ANA"         "https://www.ana.co.jp/ja/jp/"
over || visit "jal"    "JAL"         "https://www.jal.co.jp/jp/ja/"
# ふるさと納税（furusato-tax-*）
over || visit "rakuten-furusato" "楽天ふるさと納税" "https://event.rakuten.co.jp/furusato/"
over || visit "satofull" "さとふる" "https://www.satofull.jp/"
over || visit "furunavi" "ふるなび" "https://furunavi.jp/"

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
