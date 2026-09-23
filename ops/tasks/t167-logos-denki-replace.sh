#!/bin/bash
# **新電力 3 社 ＋ 差し替えたい 2 つのロゴを取る（t167）。$0。**
#
# ## 新電力（`fixed-cost-reduction-guide-2026` の見出しに並ぶ）
#
#   楽天でんき / auでんき / ドコモでんき
#
# **t165 では 3 社とも「記事名が無い」で空振り**した。Wikipedia に記事が無い。
# **親会社のロゴで代用しない。**「楽天でんき」は楽天のロゴではない。
#
# ## 差し替えたい 2 つ（いま入っているものが弱い）
#
# | 記事 | いま | なぜ差し替えたいか |
# | --- | --- | --- |
# | ふるさと納税 初心者ガイド | **赤い「C」の favicon** | wordmark ではない。公式のロゴは白抜き＋タグライン付きで使えなかった |
# | 動画配信の単価比較 | **U-NEXT の黒い盾アイコン** | `apple-touch-icon`。wordmark があるならそちらがよい |
#
# **下層ページのほうが素のロゴを置いていることが多い**（LINEMO で実証済み）。
# だからトップではなく `/company/` `/about/` を当たる。
#
# **判断はしない。候補を持ち帰るだけ。**
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t167-logos-denki-replace.md"
DIR="$RDIR/logos-denki"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

{
  echo "# 新電力 3 社 ＋ 差し替えたい 2 つ（t167・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**実ブラウザが送るヘッダを揃えて取りに行く**（UA だけでは弾かれる先がある）。"
  echo "**取れなかったときは理由を出す**（最上位ルール 17）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 240 ]; }

# **実ブラウザが送るヘッダ一式。** UA だけの GET とはここが違う
hdrs=(
  -A "$UA"
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
  -H 'Accept-Language: ja,en-US;q=0.9,en;q=0.8'
  -H 'Cache-Control: no-cache'
  -H 'Sec-Fetch-Dest: document'
  -H 'Sec-Fetch-Mode: navigate'
  -H 'Sec-Fetch-Site: none'
  -H 'Sec-Fetch-User: ?1'
  -H 'Upgrade-Insecure-Requests: 1'
)

grab() {  # $1=保存名 $2=URL
  local name="$1" url="$2" ext="png" n code ctype res
  case "$url" in *.jpg|*.jpeg) ext="jpg" ;; *.svg) ext="svg" ;; *.ico) ext="ico" ;; *.webp) ext="webp" ;; esac
  res="$(curl -sS -L --max-time 12 "${hdrs[@]}" -H 'Sec-Fetch-Dest: image' \
         -o "$DIR/$name.$ext" -w '%{http_code}\t%{content_type}' "$url" 2>/dev/null)" || res=$'000\t-'
  code="$(printf '%s' "$res" | cut -f1)"
  ctype="$(printf '%s' "$res" | cut -f2 | cut -d';' -f1)"
  n=$(wc -c < "$DIR/$name.$ext" 2>/dev/null | head -1 | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$code" != "200" ] || [ "$n" -le 200 ]; then
    rm -f "$DIR/$name.$ext"
    echo "  - ❌ \`$(printf '%s' "$url" | head -c 76)\` → **$code** / $ctype / $n bytes" >> "$OUT"
    return 1
  fi
  echo "  - ⬇️ \`$name.$ext\`（**$n bytes** / $ctype）← \`$(printf '%s' "$url" | head -c 76)\`" >> "$OUT"
  return 0
}

page() {  # $1=キー $2=見出し $3=URL
  local key="$1" jp="$2" url="$3" html len base src u i=0
  { echo "## $jp"; echo ""; echo "\`$url\`"; echo ""; } >> "$OUT"
  html="$(curl -sS -L --max-time 18 "${hdrs[@]}" "$url" 2>/dev/null)" || html=""
  len=$(printf '%s' "$html" | wc -c | head -1 | tr -d ' ')
  case "$len" in ''|*[!0-9]*) len=0 ;; esac
  echo "- HTML **$len bytes**（UA だけのときは t155/t156 の表を参照）" >> "$OUT"

  if [ "$len" -ge 2000 ]; then
    echo "" >> "$OUT"; echo '```html' >> "$OUT"
    printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' | head -6 >> "$OUT" || true
    printf '%s' "$html" | grep -oE '<link[^>]+(apple-touch-icon|icon)[^>]*>' | head -4 >> "$OUT" || true
    printf '%s' "$html" | grep -oE '<meta[^>]+og:image[^>]*>' | head -2 >> "$OUT" || true
    echo '```' >> "$OUT"
    base="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')"
    while IFS= read -r src || [ -n "$src" ]; do
      [ -n "$src" ] || continue
      over && break
      case "$src" in http*) u="$src" ;; //*) u="https:$src" ;; /*) u="$base$src" ;; *) continue ;; esac
      grab "$key-html$i" "$u" && i=$((i + 1))
      [ "$i" -ge 3 ] && break
    done <<EOF
$(printf '%s' "$html" | grep -oE '<(img|link)[^>]+>' | grep -iE 'logo|ロゴ|apple-touch-icon' \
  | grep -oE '(src|href)="[^"]+"' | sed -E 's/^(src|href)="//; s/"$//' | head -5)
EOF
  else
    echo "- ⚠️ **フルヘッダでも開けない。** 次は規格の場所を直接叩く" >> "$OUT"
  fi
  echo "" >> "$OUT"
}

icons() {  # $1=キー $2=オリジン
  local key="$1" origin="$2" i=0
  echo "### 規格の場所を直接（\`$origin\`）" >> "$OUT"
  for path in /apple-touch-icon.png /apple-touch-icon-precomposed.png /favicon.ico /favicon.png; do
    over && break
    grab "$key-icon$i" "$origin$path" && i=$((i + 1))
  done
  [ "$i" -eq 0 ] && echo "  - ⚠️ **1 つも取れなかった**" >> "$OUT"
  echo "" >> "$OUT"
}

page rakutendenki "楽天でんき"   "https://energy.rakuten.co.jp/"
over || icons rakutendenki "https://energy.rakuten.co.jp"
over || page audenki      "auでんき"     "https://www.au.com/electricity/"
over || page docomodenki  "ドコモでんき" "https://www.docomo.ne.jp/denki/"
over || page choice       "ふるさとチョイス（差し替え用）" "https://www.furusato-tax.jp/about"
over || page unext        "U-NEXT（差し替え用）"          "https://www.unext.co.jp/"
over || icons unext       "https://www.unext.co.jp"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**親会社のロゴで代用しない。**「楽天でんき」は楽天のロゴではない。"
  echo "**採否とサイズの確認はクラウド側でコンタクトシートを見てやる。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
