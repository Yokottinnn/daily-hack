#!/bin/bash
# **ふるさと納税ポータル 4 つと UQ / Y!mobile のロゴを取る（t157）。LLM 不使用・$0。**
#
# ## なぜ t156 と別にするか
#
# **1 タスク 5 分 以内**（最上位ルール 15）。t156 は 4 ブランドを 8 ページ 当たるので、
# ここに 6 ブランドを足すと確実にはみ出す。**分ける。**
#
# ## 対象（記事の見出し・比較カードに名前が出ているのに在庫が無いもの）
#
# | ブランド | 出てくる記事 |
# | --- | --- |
# | ふるさとチョイス / ふるさとプレミアム / au PAY ふるさと納税 / ANAのふるさと納税 | `furusato-tax-beginner-guide-2026`（主要 7 サイト比較） |
# | UQ mobile / Y!mobile | `cheap-sim-comparison-2026`（店頭サポート枠） |
#
# **URL は記事の CTA リンクから取っている。推測で組み立てていない**（最上位ルール 17）。
#
# **採否はクラウド側でコンタクトシートを見て決める。**
# **周年装飾・キャンペーンバナー・認証バッジは使えない。**
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t157-logos-furusato.md"
DIR="$RDIR/logos-furusato"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"

{
  echo "# ふるさと納税ポータル 4 つ ＋ UQ / Y!mobile（t157・**\$0**）"
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

  # **alt ごと出す。** ファイル名では別サービスと見分けがつかない
  echo "" >> "$OUT"; echo '```html' >> "$OUT"
  printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' | head -6 >> "$OUT" || true
  printf '%s' "$html" | grep -oE '<link[^>]+apple-touch-icon[^>]*>' | head -2 >> "$OUT" || true
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

# ふるさと納税ポータル（URL は記事の CTA リンクから）
visit "furusato-choice"  "ふるさとチョイス"      "https://www.furusato-tax.jp/"
over || visit "furusato-premium" "ふるさとプレミアム"    "https://26p.jp/"
over || visit "aupay-furusato"   "au PAY ふるさと納税"   "https://furusato.wowma.jp/"
over || visit "ana-furusato"     "ANAのふるさと納税"     "https://furusato.ana.co.jp/"
# 格安 SIM（店頭サポート枠）
over || visit "uqmobile" "UQ mobile"  "https://www.uqwimax.jp/mobile/"
over || visit "ymobile"  "Y!mobile"   "https://www.ymobile.jp/"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**採否はクラウド側でコンタクトシートにして目で見て決める。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
