#!/bin/bash
# **銀行・鉄道系 4 ブランドのロゴを取る（t152）。LLM 不使用・$0。**
#
# `jre-bank-campaign-2026` は**ロゴが 1 つも無い**（最上位ルール 17）。
# 本文で名前が並ぶのは次の 4 つ。**リポジトリに在庫は無い**（`logo-inventory.py` で確認）。
#
#   JRE BANK ／ 楽天銀行 ／ Olive（三井住友銀行）／ 住信SBIネット銀行
#
# **`jrepoint.png` は JRE POINT であって JRE BANK ではない。** 流用しない。
#
# ## 取り方（t146〜t150 の反省を入れてある）
#
#   `<img ... logo>` ＋ `og:image` ＋ `apple-touch-icon` を**一度に取る。**
#   **alt も必ず出す**（ファイル名では別サービスと見分けがつかない）。
#
# **判断はしない。採否はクラウド側でコンタクトシートにして決める。**
# **180 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t152-bank-logos.md"
DIR="$RDIR/logos-bank"
mkdir -p "$DIR"
UA="daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"

{
  echo "# 銀行・鉄道系 4 ブランドのロゴ（t152・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**判断はしない。候補を持ち帰るだけ。**"
  echo "**JRE POINT のロゴを JRE BANK のロゴとして使わない**（最上位ルール 17）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 180 ]; }

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
  local key="$1" jp="$2" url="$3" html base i=0 src u
  { echo "## $jp"; echo ""; echo "\`$url\`"; echo ""; } >> "$OUT"
  html="$(curl -sS -L --max-time 20 -A "$UA" "$url" 2>/dev/null)" || html=""
  if [ -z "$html" ]; then
    echo "- ⚠️ **開けない**" >> "$OUT"; echo "" >> "$OUT"; return
  fi
  base="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')"
  echo "- HTML **$(printf '%s' "$html" | wc -c | tr -d ' ') bytes**" >> "$OUT"
  printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' | head -6 \
    | sed 's/^/  - /' >> "$OUT" || true

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

visit "jrebank"  "JRE BANK"            "https://www.jrebank.jp/"
over || visit "rakutenbank" "楽天銀行" "https://www.rakuten-bank.co.jp/"
over || visit "olive"       "Olive（三井住友銀行）" "https://www.smbc.co.jp/kojin/olive/"
over || visit "netbk"       "住信SBIネット銀行"     "https://www.netbk.co.jp/"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | tr -d ' ') 件 持ち帰った。**"
  echo "**採否はクラウド側で目で見て決める。**"
  echo "**運営会社・別サービスのロゴが混ざる**ので、そのまま入れない。"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
