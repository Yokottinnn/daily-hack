#!/bin/bash
# **動画配信 6 社のロゴを取る（t158）。LLM 不使用・$0。**
#
# `video-subscription-cost-per-view-2026` は**比較表に 6 社が名前だけで並んでいる。**
# 在庫は `amazon.png` しか無い（最上位ルール 17）。
#
#   Netflix / U-NEXT / Amazon Prime Video / Disney+ / Hulu / DAZN
#
# ## t155 / t156 で分かっていること
#
# - **周年装飾・タグライン付きは使えない。** 素の wordmark が要る
# - **`og:image` はバナーのことが多い**が、ロゴを置いている社もある
# - **`apple-touch-icon` はブランドマークであることが多い**
# - **alt ごと dump する。** ファイル名だけでは別サービスと見分けがつかない
#
# **海外サービスは日本語トップが別ドメインのことがある**ので、
# 開けなかったものは報告に残して次の周回で別ドメインを当たる。
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t158-logos-vod.md"
DIR="$RDIR/logos-vod"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"

{
  echo "# 動画配信 6 社のロゴ（t158・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**判断はしない。候補を持ち帰るだけ。**"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 240 ]; }

save() {
  local name="$1" url="$2" ext="png" n
  case "$url" in *.jpg*|*.jpeg*) ext="jpg" ;; *.gif*) ext="gif" ;; *.svg*) ext="svg" ;; *.webp*) ext="webp" ;; esac
  curl -sS -L --max-time 12 -A "$UA" -o "$DIR/$name.$ext" "$url" 2>/dev/null || return 1
  n=$(wc -c < "$DIR/$name.$ext" | head -1 | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -le 200 ]; then rm -f "$DIR/$name.$ext"; return 1; fi
  echo "  - ⬇️ \`$name.$ext\`（**$n bytes**）← \`$(printf '%s' "$url" | head -c 110)\`" >> "$OUT"
  return 0
}

visit() {  # $1=キー $2=ブランド名 $3=URL
  local key="$1" jp="$2" url="$3" html base i=0 src u len
  { echo "## $jp"; echo ""; echo "\`$url\`"; echo ""; } >> "$OUT"
  html="$(curl -sS -L --max-time 18 -A "$UA" -H 'Accept-Language: ja,en;q=0.8' "$url" 2>/dev/null)" || html=""
  len=$(printf '%s' "$html" | wc -c | head -1 | tr -d ' ')
  case "$len" in ''|*[!0-9]*) len=0 ;; esac
  echo "- HTML **$len bytes**" >> "$OUT"
  if [ "$len" -lt 1000 ]; then echo "- ⚠️ **弾かれたか、中身が無い**" >> "$OUT"; echo "" >> "$OUT"; return; fi

  echo "" >> "$OUT"; echo '```html' >> "$OUT"
  printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' | head -6 >> "$OUT" || true
  printf '%s' "$html" | grep -oE '<link[^>]+(apple-touch-icon|icon)[^>]*>' | head -3 >> "$OUT" || true
  echo '```' >> "$OUT"

  base="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')"
  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    over && break
    case "$src" in
      http*) u="$src" ;; //*) u="https:$src" ;; /*) u="$base$src" ;; *) continue ;;
    esac
    save "$key-$i" "$u" && i=$((i + 1))
    [ "$i" -ge 3 ] && break
  done <<EOF
$(printf '%s' "$html" \
  | grep -oE '<(img|link)[^>]+>' \
  | grep -iE 'logo|ロゴ|apple-touch-icon' \
  | grep -oE '(src|href)="[^"]+"' | sed -E 's/^(src|href)="//; s/"$//' \
  | grep -viE 'sprite|banner|campaign' | head -5)
EOF

  u="$(printf '%s' "$html" | grep -oE '<meta[^>]+og:image[^>]*>' | head -1 \
       | grep -oE 'content="[^"]+"' | sed 's/^content="//; s/"$//')"
  if [ -n "$u" ] && ! over; then
    case "$u" in /*) u="$base$u" ;; //*) u="https:$u" ;; esac
    save "$key-ogp" "$u" || true
  fi
  echo "" >> "$OUT"
}

visit "netflix" "Netflix"            "https://www.netflix.com/jp/"
over || visit "unext"   "U-NEXT"     "https://video.unext.jp/"
over || visit "primevideo" "Amazon Prime Video" "https://www.primevideo.com/"
over || visit "disneyplus" "Disney+"  "https://www.disneyplus.com/ja-jp"
over || visit "hulu"    "Hulu"        "https://www.hulu.jp/"
over || visit "dazn"    "DAZN"        "https://www.dazn.com/ja-JP/home"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**採否はクラウド側でコンタクトシートにして目で見て決める。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
