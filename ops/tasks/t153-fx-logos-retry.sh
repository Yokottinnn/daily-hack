#!/bin/bash
# **FX 3 社のロゴを取り直す（t153）。LLM 不使用・$0。**
#
# t150 で 7 社 中 **4 社は取れた**（外為どっとコム・みんなのFX・松井証券・SBI FXトレード）。
# **取れなかった 3 社は、理由がそれぞれ違う。**
#
# | ブランド | t150 で起きたこと | ここでの手当て |
# | --- | --- | --- |
# | DMM FX | ヘッダーは `FX` の 30×40 と **`TOSSY`（キャラ名）**。og:image は**タレントの広告写真** | **サービス紹介ページ**と**会社情報**を当たる |
# | GMOクリック証券 | 取れたのは **`GMO INTERNET GROUP`＝持株会社のロゴ** | **`/corp/` 配下**を当たる。**持株会社のロゴは使わない**（最上位ルール 17） |
# | マネックス証券 | **HTML が 372 bytes**（JS で飛ばしている） | **別ホスト**を当たる |
#
# **og:image はキャンペーンバナーだった。** GMO のバナーには社名ロゴが入っているが、
# **切り抜きは改変にあたるので不可**（最上位ルール 17）。
#
# **判断はしない。候補を持ち帰るだけ。**
# **150 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t153-fx-logos-retry.md"
DIR="$RDIR/logos-fx2"
mkdir -p "$DIR"
UA="daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"

{
  echo "# FX 3 社のロゴ、2 回目（t153・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**持株会社のロゴを、証券会社のロゴとして使わない**（最上位ルール 17）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 150 ]; }

save() {
  local name="$1" url="$2" ext="png" n
  case "$url" in *.jpg*|*.jpeg*) ext="jpg" ;; *.gif*) ext="gif" ;; *.svg*) ext="svg" ;; esac
  curl -sS -L --max-time 15 -A "$UA" -o "$DIR/$name.$ext" "$url" 2>/dev/null || return 1
  n=$(wc -c < "$DIR/$name.$ext" | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -le 200 ]; then rm -f "$DIR/$name.$ext"; return 1; fi
  echo "  - ⬇️ \`$name.$ext\`（**$n bytes**）← \`$(printf '%s' "$url" | head -c 100)\`" >> "$OUT"
  return 0
}

visit() {  # $1=キー $2=ラベル $3=URL
  local key="$1" jp="$2" url="$3" html base i=0 src u
  { echo "## $jp"; echo ""; echo "\`$url\`"; echo ""; } >> "$OUT"
  html="$(curl -sS -L --max-time 20 -A "$UA" "$url" 2>/dev/null)" || html=""
  if [ -z "$html" ]; then echo "- ⚠️ **開けない**" >> "$OUT"; echo "" >> "$OUT"; return; fi
  base="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')"
  echo "- HTML **$(printf '%s' "$html" | wc -c | tr -d ' ') bytes**" >> "$OUT"
  # **alt ごと出す**
  printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' | head -8 \
    | sed 's/^/  - /' >> "$OUT" || true
  # svg の参照も出す（近年のロゴはほぼ SVG）
  printf '%s' "$html" | grep -oE '[^"]+\.svg' | grep -iE 'logo' | sort -u | head -5 \
    | sed 's/^/  - svg: /' >> "$OUT" || true

  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    over && break
    case "$src" in
      http*) u="$src" ;; //*) u="https:$src" ;; /*) u="$base$src" ;; *) continue ;;
    esac
    save "$key-$i" "$u" && i=$((i + 1))
    [ "$i" -ge 3 ] && break
  done <<EOF
$(printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' \
  | grep -oE 'src="[^"]+"' | sed 's/^src="//; s/"$//' | head -5)
$(printf '%s' "$html" | grep -oE '"[^"]+logo[^"]*\.svg"' | tr -d '"' | sort -u | head -3)
EOF
  echo "" >> "$OUT"
}

visit "dmmfx1"   "DMM FX（サービス紹介）"     "https://fx.dmm.com/fx/about/"
over || visit "dmmfx2" "DMM.com 証券（会社情報）" "https://fx.dmm.com/company/"
over || visit "gmo1"   "GMOクリック証券（会社情報）" "https://www.click-sec.com/corp/guide/outline/"
over || visit "gmo2"   "GMOクリック証券（FX）"   "https://www.click-sec.com/corp/fx/"
over || visit "monex1" "マネックス証券"          "https://info.monex.co.jp/"
over || visit "monex2" "マネックス証券（FX）"    "https://mst.monex.co.jp/mst/servlet/ITS/fx/"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | tr -d ' ') 件 持ち帰った。**"
  echo "**採否はクラウド側で目で見て決める。**"
  echo "**これで取れなければ、取れないと書いてその社だけロゴ無しで出す。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
