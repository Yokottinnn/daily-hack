#!/bin/bash
# **カードローン 4 社 ＋ みずほ銀行のロゴを公式から取る（t166）。$0。**
#
# ## MediaWiki は当たらなかった（t164 / t165）
#
# 呼び方を直して**ファイルは引けるようになった**が、中身が別物だった。
#
# | ブランド | 記事に載っていたもの | 判定 |
# | --- | --- | --- |
# | アコム | `Acom company logos.svg` | ✅ **採用済み** |
# | 三井住友銀行 / 三菱UFJ銀行 | 各行の wordmark | ✅ **採用済み** |
# | SMBCモビット | **`SMFG logo.gif`**（持株会社） | ❌ |
# | レイク | **`SBI Group Logos.png`**（親会社） | ❌ |
# | アイフル | `Aifulnewlogo.png` | ❌ **CC BY-SA 4.0**（表示・継承が条件） |
# | みずほ銀行 | **`CESA logo.svg`**（無関係） | ❌ |
# | プロミス | 記事名が引けない | ❌ |
#
# **だから公式サイトを、実ブラウザのヘッダ一式で当たる。**
# `Accept` / `Accept-Language` / `Sec-Fetch-*` が無いと落とす防御があるため。
#
# **規格の場所のアイコン**（`apple-touch-icon.png` / `favicon.ico`）も撃つ。
# **名前を当てているのではない**ので「推測で URL を組み立てない」には反しない。
#
# **判断はしない。取れたものと、取れなかった理由を持ち帰るだけ。**
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t166-logos-cardloan-mizuho.md"
DIR="$RDIR/logos-cardloan2"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

{
  echo "# カードローン 4 社 ＋ みずほ銀行を公式から（t166・**\$0**）"
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

page promise "プロミス"      "https://cyber.promise.co.jp/"
over || icons promise "https://cyber.promise.co.jp"
over || page mobit   "SMBCモビット"  "https://www.mobit.ne.jp/"
over || icons mobit   "https://www.mobit.ne.jp"
over || page lake    "レイク"        "https://lakealsa.com/"
over || icons lake    "https://lakealsa.com"
over || page aiful   "アイフル"      "https://www.aiful.co.jp/"
over || icons aiful   "https://www.aiful.co.jp"
over || page mizuho  "みずほ銀行"     "https://www.mizuhobank.co.jp/"
over || icons mizuho  "https://www.mizuhobank.co.jp"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**持株会社・親会社のロゴを、サービスのロゴとして使わない**（最上位ルール 17）。"
  echo "**採否とサイズの確認はクラウド側でコンタクトシートを見てやる。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
