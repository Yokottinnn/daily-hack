#!/bin/bash
# **t155 で取り切れなかった 4 ブランドを取り直す（t156）。LLM 不使用・$0。**
#
# ## t155 で何が起きたか（コンタクトシートで目視した結果）
#
# | ブランド | 取れたもの | 判定 |
# | --- | --- | --- |
# | ahamo / irumo / ANA / ふるなび / 楽天ふるさと納税 / 楽天モバイル | wordmark | **採用**（この t156 の対象外） |
# | **JAL** | HTML **384 bytes** | ❌ **弾かれた**。別ドメインで取り直す |
# | **さとふる** | 開けない | ❌ **弾かれた**。別ドメインで取り直す |
# | **LINEMO** | `logo.svg` に **「5th」の周年装飾**が入っていた | ❌ **キャンペーン版**。素の wordmark が要る |
# | **povo** | `logo.svg` に**タグライン**が乗っていた | ❌ ロゴ単体が要る |
#
# ## だから今回は「候補を dump する」ことに寄せる
#
# **推測で URL を組み立てない**（最上位ルール 17）。ページの
# `<img>` / `<link>` / `<meta>` / インライン `<svg>` の参照を**丸ごと出して**、
# 採否はクラウド側でコンタクトシートを見て決める。
#
# **1 ブランドにつき複数のドメインを当たる。** トップが弾かれても、
# 広報・コーポレート側は開くことがある。
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t156-logos-retry.md"
DIR="$RDIR/logos-retry2"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"

{
  echo "# 取り切れなかった 4 ブランドの取り直し（t156・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**判断はしない。候補を持ち帰るだけ。**"
  echo "**周年装飾・タグライン付き・認証バッジは使えない**ので、素の wordmark を探す。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 240 ]; }

save() {
  local name="$1" url="$2" ext="png" n
  case "$url" in *.jpg*|*.jpeg*) ext="jpg" ;; *.gif*) ext="gif" ;; *.svg*) ext="svg" ;; esac
  curl -sS -L --max-time 12 -A "$UA" -o "$DIR/$name.$ext" "$url" 2>/dev/null || return 1
  n=$(wc -c < "$DIR/$name.$ext" | head -1 | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -le 200 ]; then rm -f "$DIR/$name.$ext"; return 1; fi
  echo "  - ⬇️ \`$name.$ext\`（**$n bytes**）← \`$(printf '%s' "$url" | head -c 110)\`" >> "$OUT"
  return 0
}

dump() {  # $1=キー $2=ブランド名 $3=URL $4=開始番号
  local key="$1" jp="$2" url="$3" i="$4" html base src u
  { echo "### \`$url\`"; echo ""; } >> "$OUT"
  html="$(curl -sS -L --max-time 18 -A "$UA" -H 'Accept-Language: ja,en;q=0.8' "$url" 2>/dev/null)" || html=""
  local len; len=$(printf '%s' "$html" | wc -c | head -1 | tr -d ' ')
  case "$len" in ''|*[!0-9]*) len=0 ;; esac
  echo "- HTML **$len bytes**" >> "$OUT"
  if [ "$len" -lt 1000 ]; then
    echo "- ⚠️ **弾かれたか、中身が無い**" >> "$OUT"; echo "" >> "$OUT"; printf '%s' "$i"; return
  fi

  # **alt ごと出す。** ファイル名だけでは周年版と素の版が見分けられない
  echo "" >> "$OUT"
  echo '```html' >> "$OUT"
  printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' | head -8 >> "$OUT" || true
  printf '%s' "$html" | grep -oE '<link[^>]+(icon|logo)[^>]*>' | head -4 >> "$OUT" || true
  printf '%s' "$html" | grep -oE '<meta[^>]+og:image[^>]*>' | head -2 >> "$OUT" || true
  echo '```' >> "$OUT"

  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    over && break
    base="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')"
    case "$src" in
      http*) u="$src" ;; //*) u="https:$src" ;; /*) u="$base$src" ;; *) continue ;;
    esac
    save "$key-$i" "$u" && i=$((i + 1))
    [ "$i" -ge 8 ] && break
  done <<EOF
$(printf '%s' "$html" \
  | grep -oE '<(img|link)[^>]+>' \
  | grep -iE 'logo|ロゴ|apple-touch-icon' \
  | grep -oE '(src|href)="[^"]+"' | sed -E 's/^(src|href)="//; s/"$//' \
  | grep -viE 'sprite|banner|campaign' | head -6)
EOF
  echo "" >> "$OUT"
  printf '%s' "$i"
}

n=0
echo "## JAL" >> "$OUT"; echo "" >> "$OUT"
n="$(dump jal JAL "https://www.jal.com/ja/" 0)"
over || n="$(dump jal JAL "https://press.jal.co.jp/ja/" "$n")"

echo "## さとふる" >> "$OUT"; echo "" >> "$OUT"
n=0
over || n="$(dump satofull さとふる "https://www.satofull.jp/" 0)"
over || n="$(dump satofull さとふる "https://corp.satofull.jp/" "$n")"

echo "## LINEMO（**素の wordmark が要る**）" >> "$OUT"; echo "" >> "$OUT"
n=0
over || n="$(dump linemo LINEMO "https://www.linemo.jp/service/" 0)"
over || n="$(dump linemo LINEMO "https://www.linemo.jp/support/" "$n")"

echo "## povo（**タグライン無しが要る**）" >> "$OUT"; echo "" >> "$OUT"
n=0
over || n="$(dump povo povo "https://povo.jp/spec/" 0)"
over || n="$(dump povo povo "https://povo.jp/support/" "$n")"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**採否はクラウド側でコンタクトシートにして目で見て決める。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
