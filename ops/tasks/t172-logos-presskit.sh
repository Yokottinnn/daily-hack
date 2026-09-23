#!/bin/bash
# **まだ通していない入口でロゴを取る（t172）。LLM 不使用・$0。**
#
# ## 通した入口と、その結果
#
# | 入口 | 結果 |
# | --- | --- |
# | 公式トップの `<img ... logo>` | 当たることもあるが**別サービス・親会社が混ざる** |
# | `apple-touch-icon` / `favicon` | **403 が多い**。取れても BMP の 16〜32px で使えない |
# | フルヘッダ（`Sec-Fetch-*` ほか） | JAL・さとふる・みずほ・レイクは**それでも弾かれた** |
# | MediaWiki API | 引けるようになったが、**Olympics のロゴや持株会社が返る** |
#
# **最上位ルール 17 が挙げている入口のうち、まだ通していないのがこの 2 つ。**
#
#   ① **公式のメディアキット・広報ページ**（`/press/` `/newsroom/` `/company/` `/brand/`）
#   ② **PR TIMES の企業ページ**（プレスリリースにロゴが載る）
#
# ## 対象（記事に名前が出ていて、まだ取れていないもの）
#
#   JAL / さとふる / プロミス / SMBCモビット / レイク
#
# **アイフルは公式トップから `logo.svg` が取れている**ので対象外。
#
# ## 気をつけること
#
# - **持株会社・親会社のロゴを使わない。** SMFG は SMBCモビットのロゴではないし、
#   SBI Group はレイクのロゴではない（最上位ルール 17）
# - **PR TIMES の「企業ロゴ」は本物のことが多いが、記事のサムネが混ざる。**
#   採否はクラウド側でコンタクトシートを見て決める
#
# **判断はしない。候補と、取れなかった理由を持ち帰るだけ。**
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t172-logos-presskit.md"
DIR="$RDIR/logos-presskit"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

{
  echo "# メディアキット・PR TIMES から取る（t172・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**トップと規格アイコンと MediaWiki は全部 通した。** 残る入口はこの 2 つ。"
  echo "**持株会社・親会社のロゴを使わない**（最上位ルール 17）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 240 ]; }

hdrs=(
  -A "$UA"
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
  -H 'Accept-Language: ja,en-US;q=0.9,en;q=0.8'
  -H 'Sec-Fetch-Dest: document'
  -H 'Sec-Fetch-Mode: navigate'
  -H 'Sec-Fetch-Site: none'
  -H 'Upgrade-Insecure-Requests: 1'
)

grab() {  # $1=保存名 $2=URL
  local name="$1" url="$2" ext="png" n code ctype res
  case "$url" in *.jpg|*.jpeg) ext="jpg" ;; *.svg) ext="svg" ;; *.webp) ext="webp" ;; esac
  res="$(curl -sS -L --max-time 12 "${hdrs[@]}" -H 'Sec-Fetch-Dest: image' \
         -o "$DIR/$name.$ext" -w '%{http_code}\t%{content_type}' "$url" 2>/dev/null)" || res=$'000\t-'
  code="$(printf '%s' "$res" | cut -f1)"
  ctype="$(printf '%s' "$res" | cut -f2 | cut -d';' -f1)"
  n=$(wc -c < "$DIR/$name.$ext" 2>/dev/null | head -1 | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  case "$ctype" in image/*) ;; *) rm -f "$DIR/$name.$ext"
       echo "  - ❌ \`$(printf '%s' "$url" | head -c 70)\` → **$code** / $ctype" >> "$OUT"; return 1 ;; esac
  if [ "$n" -le 400 ]; then rm -f "$DIR/$name.$ext"
    echo "  - ❌ \`$(printf '%s' "$url" | head -c 70)\` → **$code** / $n bytes（小さすぎる）" >> "$OUT"; return 1; fi
  echo "  - ⬇️ \`$name.$ext\`（**$n bytes** / $ctype）← \`$(printf '%s' "$url" | head -c 70)\`" >> "$OUT"
  return 0
}

page() {  # $1=キー $2=見出し $3=URL
  local key="$1" jp="$2" url="$3" html len base src u i=0
  { echo "### \`$url\`"; echo ""; } >> "$OUT"
  html="$(curl -sS -L --max-time 15 "${hdrs[@]}" "$url" 2>/dev/null)" || html=""
  len=$(printf '%s' "$html" | wc -c | head -1 | tr -d ' ')
  case "$len" in ''|*[!0-9]*) len=0 ;; esac
  echo "- HTML **$len bytes**" >> "$OUT"
  if [ "$len" -lt 2000 ]; then echo "- ⚠️ **開けない**" >> "$OUT"; echo "" >> "$OUT"; return; fi

  echo "" >> "$OUT"; echo '```html' >> "$OUT"
  printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' | head -6 >> "$OUT" || true
  printf '%s' "$html" | grep -oE '<a[^>]+href="[^"]*\.(zip|ai|eps)"[^>]*>' | head -3 >> "$OUT" || true
  echo '```' >> "$OUT"

  base="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')"
  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    over && break
    case "$src" in http*) u="$src" ;; //*) u="https:$src" ;; /*) u="$base$src" ;; *) continue ;; esac
    grab "$key-$i" "$u" && i=$((i + 1))
    [ "$i" -ge 3 ] && break
  done <<EOF
$(printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' \
  | grep -oE 'src="[^"]+"' | sed 's/^src="//; s/"$//' \
  | grep -viE 'sprite|banner|campaign|thumb' | head -5)
EOF
  echo "" >> "$OUT"
}

# --- ① 公式のメディアキット・広報ページ ---
echo "## JAL" >> "$OUT"; echo "" >> "$OUT"
page jal "JAL" "https://press.jal.co.jp/ja/plane/"
over || page jal "JAL" "https://www.jal.com/ja/outline/"

over || { echo "## さとふる" >> "$OUT"; echo "" >> "$OUT"; }
over || page satofull "さとふる" "https://www.satofull.jp/static/company.php"

over || { echo "## プロミス" >> "$OUT"; echo "" >> "$OUT"; }
over || page promise "プロミス" "https://www.smbc-cf.com/"

over || { echo "## SMBCモビット" >> "$OUT"; echo "" >> "$OUT"; }
over || page mobit "SMBCモビット" "https://www.mobit.ne.jp/company/"

over || { echo "## レイク" >> "$OUT"; echo "" >> "$OUT"; }
over || page lake "レイク" "https://www.shinseifinancial.co.jp/"

# --- ② PR TIMES の企業ページ（**企業ロゴが載る**） ---
if ! over; then
  { echo "## PR TIMES の企業ページ"; echo ""; } >> "$OUT"
  for q in "さとふる" "アイフル" "プロミス"; do
    over && break
    page "prtimes-$(printf '%s' "$q" | md5 -q 2>/dev/null | head -c 6 || echo x)" \
      "PR TIMES: $q" "https://prtimes.jp/main/action.php?run=html&page=searchkey&search_word=$(
        printf '%s' "$q" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read()))' 2>/dev/null
      )"
  done
fi

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**持株会社・親会社のロゴをサービスのロゴとして使わない**（最上位ルール 17）。"
  echo "**採否はクラウド側でコンタクトシートを見て決める。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
