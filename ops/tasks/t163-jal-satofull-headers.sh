#!/bin/bash
# **JAL と さとふる を「ブラウザらしいヘッダ」で取り直す（t163）。$0。**
#
# ## これまで
#
# | 回 | やり方 | 結果 |
# | --- | --- | --- |
# | t155 / t156 | UA だけ差し替えて GET | **371〜384 bytes** / **0 bytes** |
# | t159 | MediaWiki API | **空**（呼び方の問題。t162 で切り分け中） |
#
# **UA だけでは足りない。** 実ブラウザは `Accept` / `Accept-Language` /
# `Sec-Fetch-*` を必ず送る。**これが無いリクエストを落とす防御は珍しくない。**
#
# ## 2 つ試す
#
# ① **フルヘッダで HTML を取り直す。** 通れば `<img ... logo>` を拾える
# ② **標準の場所にあるアイコンを直接叩く。**
#    `apple-touch-icon.png` / `favicon.ico` は**規格で決まっている場所**であって、
#    こちらが名前を当てているわけではない（最上位ルール 17 の「推測で URL を
#    組み立てない」に反しない）。HTML が開けなくても単体で配信されることがある
#
# **判断はしない。取れたものと、取れなかった理由を持ち帰るだけ。**
#
# **180 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t163-jal-satofull.md"
DIR="$RDIR/logos-jal-satofull"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

{
  echo "# JAL と さとふる をフルヘッダで取り直す（t163・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**UA だけでは足りなかった**ので、実ブラウザが送るヘッダを揃えた。"
  echo "**取れなかったときは理由を出す**（最上位ルール 17）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 180 ]; }

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

page jal      "JAL（日本航空）" "https://www.jal.co.jp/jp/ja/"
over || icons jal "https://www.jal.co.jp"
over || page satofull "さとふる" "https://www.satofull.jp/"
over || icons satofull "https://www.satofull.jp"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**favicon は 16〜32px のことがある。** 小さすぎるものは記事には使えない。"
  echo "**採否とサイズの確認はクラウド側でコンタクトシートを見てやる。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
