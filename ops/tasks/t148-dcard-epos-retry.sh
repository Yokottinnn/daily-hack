#!/bin/bash
# **dカードとエポスカードのロゴを取り直す（t148）。LLM 不使用・$0。**
#
# t146 で取れなかった理由は**両方 分かっている。**
#
# | ブランド | t146 で起きたこと | ここでの手当て |
# | --- | --- | --- |
# | dカード | `SSL: UNSAFE_LEGACY_RENEGOTIATION_DISABLED` で**公式が開けない** | **`curl` に切り替える**（OpenSSL の設定が Python と別） |
# | エポスカード | 取れたのは `EPOS Net`＝**会員サイト名。カードのロゴではない** | **カードの案内ページ**と**丸井グループ**を当たる |
#
# **当て推量でファイル名を組み立てない。** 開いた HTML の img / meta / link を
# 丸ごと出して、実体は候補として持ち帰るだけにする。採否はクラウド側で目で見て決める。
#
# **SVG は変換せずそのまま置く**（Mac に変換器が無い・`docs/mac-environment.md`）。
# **120 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t148-dcard-epos-retry.md"
DIR="$RDIR/logos-card2"
mkdir -p "$DIR"
UA="daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"

{
  echo "# dカード / エポスカードの取り直し（t148・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**判断はしない。候補を持ち帰るだけ。**"
  echo ""
} > "$OUT"

# **curl は在るか**（最上位ルール 14: 推測で使わない）
if ! command -v curl >/dev/null 2>&1; then
  echo "⚠️ **curl が無い。** ここで止まる" >> "$OUT"; cat "$OUT"; exit 0
fi

START=$(date +%s)
budget_over() { [ $(( $(date +%s) - START )) -ge 120 ]; }

# 1 ページ見て、logo を含む img と og:image / apple-touch-icon を出す
dump_page() {  # $1=ラベル $2=URL $3=保存名の接頭辞
  local label="$1" url="$2" key="$3" html rc
  {
    echo "## $label"
    echo ""
    echo "\`$url\`"
    echo ""
  } >> "$OUT"
  html="$(curl -sS -L --max-time 20 -A "$UA" "$url" 2>&1)"; rc=$?
  if [ $rc -ne 0 ] || [ -z "$html" ]; then
    echo "- ⚠️ **開けない**（curl rc=$rc）: \`$(printf '%s' "$html" | head -c 160)\`" >> "$OUT"
    echo "" >> "$OUT"
    return
  fi
  echo "- HTML **$(printf '%s' "$html" | wc -c | tr -d ' ') bytes**" >> "$OUT"

  # **img / meta / link を丸ごと出す。** 推測でやり直さないため
  printf '%s' "$html" \
    | grep -oE '<img[^>]+>' \
    | grep -iE 'logo|ロゴ' \
    | head -10 \
    | sed 's/^/  - /' >> "$OUT" || true
  printf '%s' "$html" | grep -oE '<meta[^>]+og:image[^>]*>' | head -2 | sed 's/^/  - /' >> "$OUT" || true
  printf '%s' "$html" | grep -oE '<link[^>]+apple-touch-icon[^>]*>' | head -2 | sed 's/^/  - /' >> "$OUT" || true
  echo "" >> "$OUT"

  # 候補の実体を 3 件まで持ち帰る
  local i=0 src u ext
  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    budget_over && { echo "  - ⏱️ **時間切れ**" >> "$OUT"; break; }
    case "$src" in
      http*) u="$src" ;;
      //*)   u="https:$src" ;;
      /*)    u="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')$src" ;;
      *)     continue ;;
    esac
    ext="png"
    case "$u" in *.svg*) ext="svg" ;; *.jpg*|*.jpeg*) ext="jpg" ;; *.gif*) ext="gif" ;; esac
    if curl -sS -L --max-time 15 -A "$UA" -o "$DIR/$key-$i.$ext" "$u" 2>/dev/null; then
      echo "  - ⬇️ \`$key-$i.$ext\`（$(wc -c < "$DIR/$key-$i.$ext" | tr -d ' ') bytes）← \`$(printf '%s' "$u" | head -c 110)\`" >> "$OUT"
      i=$((i + 1))
    fi
    [ "$i" -ge 3 ] && break
  done <<EOF
$(printf '%s' "$html" | grep -oE '<img[^>]+>' | grep -iE 'logo|ロゴ' \
  | grep -oE 'src="[^"]+"' | sed 's/^src="//; s/"$//' | head -6)
EOF
  echo "" >> "$OUT"
}

dump_page "dカード（公式トップ）" "https://dcard.docomo.ne.jp/" "dcard-top"
budget_over || dump_page "dカード（カードの案内）" "https://dcard.docomo.ne.jp/std/about/index.html" "dcard-about"
budget_over || dump_page "エポスカード（カードの案内）" "https://www.eposcard.co.jp/card/index.html" "epos-card"
budget_over || dump_page "丸井グループ（広報）" "https://www.0101maruigroup.co.jp/" "marui"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | tr -d ' ') 件 持ち帰った。**"
  echo "**採否はクラウド側でコンタクトシートにして目で見て決める。**"
  echo "**運営会社のロゴをカードのロゴとして使わない**（最上位ルール 17）。"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
