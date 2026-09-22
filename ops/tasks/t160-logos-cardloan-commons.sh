#!/bin/bash
# **カードローン 5 社のロゴを、MediaWiki API で取る（t160）。LLM 不使用・$0。**
#
# `cardloan-comparison-2026` は**各社詳細の見出しに 6 社が名前だけで並んでいる。**
# 在庫は `smbccard.png`（三井住友カード）だけ（最上位ルール 17）。
#
#   プロミス / アコム / SMBCモビット / レイク / アイフル
#
# ## なぜ公式サイトではなく MediaWiki なのか
#
# **記事に公式サイトへのリンクが 1 本も無い**（アフィリエイトリンクだけ）。
# **URL を推測で組み立てない**（最上位ルール 17）ので、**名前で引ける入口**を使う。
# MediaWiki なら**実体 URL とライセンス表記が一緒に取れる。**
#
# **`Non-free logo` なら使わない。** 判断はクラウド側でやる。
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t160-logos-cardloan.md"
DIR="$RDIR/logos-cardloan"
mkdir -p "$DIR"
UA="daily-hack-ops/1.0 (https://daily-hack.fieldbeside.com; contact via GitHub)"

{
  echo "# カードローン 5 社のロゴ（t160・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**記事に公式サイトへのリンクが無い**ので、名前で引ける MediaWiki API を使った。"
  echo "**ライセンスを必ず出す。\`Non-free\` なら使わない**（最上位ルール 17）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 240 ]; }

# --- 1) まず日本語版ウィキペディアの記事から、ページ内の画像名を引く ---
wiki_images() {  # $1=記事名
  curl -sS --max-time 15 -A "$UA" -G \
    --data-urlencode "action=query" \
    --data-urlencode "format=json" \
    --data-urlencode "prop=images" \
    --data-urlencode "imlimit=60" \
    --data-urlencode "titles=$1" \
    "https://ja.wikipedia.org/w/api.php" 2>/dev/null
}

# --- 2) ファイル名から実体 URL とライセンスを引く ---
file_info() {  # $1=File:xxx $2=どのウィキか
  curl -sS --max-time 15 -A "$UA" -G \
    --data-urlencode "action=query" \
    --data-urlencode "format=json" \
    --data-urlencode "prop=imageinfo" \
    --data-urlencode "iiprop=url|extmetadata|size|mime" \
    --data-urlencode "titles=$1" \
    "https://$2/w/api.php" 2>/dev/null
}

probe() {  # $1=キー $2=見出し $3=ウィキペディアの記事名
  local key="$1" jp="$2" art="$3" json names n=0
  { echo "## $jp"; echo ""; echo "ウィキペディア記事: \`$art\`"; echo ""; } >> "$OUT"
  json="$(wiki_images "$art")"
  if [ -z "$json" ]; then echo "- ⚠️ **API が開けない**" >> "$OUT"; echo "" >> "$OUT"; return; fi

  # **ロゴらしいファイル名だけに絞る。** 機体写真・人物写真は要らない
  names="$(printf '%s' "$json" | tr ',' '\n' | grep -oE '"title":"File:[^"]+"' \
           | sed 's/"title":"//; s/"$//' \
           | grep -iE 'logo|ロゴ|logotype|wordmark' | head -6)"
  if [ -z "$names" ]; then
    echo "- ⚠️ **ロゴらしいファイルが記事に無い**" >> "$OUT"
    echo "" >> "$OUT"
    echo '```' >> "$OUT"
    printf '%s' "$json" | tr ',' '\n' | grep -oE '"title":"File:[^"]+"' | head -12 >> "$OUT" || true
    echo '```' >> "$OUT"
    echo "" >> "$OUT"; return
  fi

  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    over && break
    local info url lic ext
    info="$(file_info "$f" "ja.wikipedia.org")"
    url="$(printf '%s' "$info" | grep -oE '"url":"[^"]+"' | head -1 | sed 's/"url":"//; s/"$//; s#\\/#/#g')"
    # **ライセンスは extmetadata の LicenseShortName。** 無ければ空で出す
    lic="$(printf '%s' "$info" | grep -oE '"LicenseShortName":\{"value":"[^"]*"' | head -1 \
           | sed 's/.*"value":"//; s/"$//')"
    echo "- \`$f\`" >> "$OUT"
    echo "  - ライセンス: **${lic:-不明}**" >> "$OUT"
    if [ -z "$url" ]; then echo "  - ⚠️ **実体 URL が取れない**" >> "$OUT"; continue; fi
    echo "  - \`$(printf '%s' "$url" | head -c 110)\`" >> "$OUT"
    case "$url" in *.svg) ext=svg ;; *.png) ext=png ;; *.jpg|*.jpeg) ext=jpg ;; *) ext=png ;; esac
    if curl -sS -L --max-time 15 -A "$UA" -o "$DIR/$key-$n.$ext" "$url" 2>/dev/null; then
      local sz; sz=$(wc -c < "$DIR/$key-$n.$ext" | head -1 | tr -d ' ')
      case "$sz" in ''|*[!0-9]*) sz=0 ;; esac
      if [ "$sz" -le 200 ]; then rm -f "$DIR/$key-$n.$ext"; echo "  - ⚠️ **中身が無い**" >> "$OUT";
      else echo "  - ⬇️ \`$key-$n.$ext\`（**$sz bytes**）" >> "$OUT"; n=$((n + 1)); fi
    fi
    [ "$n" -ge 3 ] && break
  done <<EOF
$names
EOF
  echo "" >> "$OUT"
}

probe promise "プロミス"      "プロミス_(消費者金融)"
over || probe acom     "アコム"        "アコム"
over || probe mobit    "SMBCモビット"  "SMBCモビット"
over || probe lake     "レイク"        "レイク_(消費者金融)"
over || probe aiful    "アイフル"      "アイフル"


{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**\`Non-free logo\` と書いてあるものは使わない。**"
  echo "**\`PD-textlogo\` / \`PD-simple\` なら、商標として識別目的で使える。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
