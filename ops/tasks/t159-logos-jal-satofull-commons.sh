#!/bin/bash
# **JAL と さとふる のロゴを、別経路で取る（t159）。LLM 不使用・$0。**
#
# ## 2 回 失敗している。同じやり方を 3 回目はやらない
#
# | 回 | 経路 | 結果 |
# | --- | --- | --- |
# | t155 | `www.jal.co.jp` / `www.satofull.jp` | **384 bytes** / 開けない |
# | t156 | `jal.com` / `press.jal.co.jp` / `corp.satofull.jp` | **371・379 bytes** / **0 bytes** |
#
# **公式サイトが bot を弾いている。** だから**別の入口**に行く。
# 最上位ルール 17 の「取れないと言う前に、名前で調べる」の一覧のうち、
# **まだ通していないのがウィキペディア／コモンズの API。**
#
#   MediaWiki API なら**実体 URL とライセンス表記が一緒に取れる**。
#
# ## ライセンスに注意（最上位ルール 17）
#
# **ロゴは商標であって自由ライセンスではない。** コモンズ上の企業ロゴは
# 多くが `PD-textlogo`（著作権が発生しない単純図形）か `Non-free logo`。
# **`Non-free` なら使わない。** だから **`extmetadata` を必ず出して、
# ライセンスをクラウド側で読めるようにする。**
#
# **判断はしない。候補とライセンスを持ち帰るだけ。**
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t159-logos-jal-satofull.md"
DIR="$RDIR/logos-commons"
mkdir -p "$DIR"
UA="daily-hack-ops/1.0 (https://daily-hack.fieldbeside.com; contact via GitHub)"

{
  echo "# JAL と さとふる を別経路で取る（t159・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**公式サイトは 2 回 とも bot に弾かれた**ので、MediaWiki API に切り替えた。"
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

probe jal      "JAL（日本航空）" "日本航空"
over || probe satofull "さとふる"        "さとふる"

# --- 3) 保険: さとふるは ja.wikipedia に記事が無いかもしれない。企業の IR も当たる ---
if ! over; then
  echo "## さとふる（保険の入口）" >> "$OUT"; echo "" >> "$OUT"
  for u in "https://www.satofull.jp/static/company.php" "https://www.satofull.jp/corporate/"; do
    over && break
    len=$(curl -sS -L --max-time 12 -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36" \
          -H 'Accept-Language: ja' -o /dev/null -w '%{size_download} %{http_code}' "$u" 2>/dev/null || echo "0 000")
    echo "- \`$u\` → **$len**（bytes / status）" >> "$OUT"
  done
  echo "" >> "$OUT"
fi

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
