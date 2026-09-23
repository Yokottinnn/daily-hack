#!/bin/bash
# **MediaWiki のロゴ取得をやり直す（t164）。LLM 不使用・$0。**
#
# ## t159 / t160 / t161 が 13 件 すべて空だった原因（t162 で特定）
#
# **日本語版は `"title":"ファイル:..."` を返す。`"File:"` ではない。**
# しかも `format=json` は**非 ASCII をエスケープする**ので、生の応答には
# `"title":"ファイル:..."` と出ていた。
#
#   `grep '"title":"File:'` → **1 件も当たらない。** だから 13 件 全滅した。
#
# API は **status 200 / 4163 bytes** を返していた。**壊れていたのはこちら側。**
#
# ## 直したこと
#
# | | 前 | 後 |
# | --- | --- | --- |
# | 文字コード | エスケープされたまま | **`utf8=1`** を付けて生の日本語で受ける |
# | 接頭辞 | `File:` だけ | **`File:` と `ファイル:` の両方** |
# | 記事名 | 決め打ち | **`redirects=1`** でリダイレクトを追う |
#
# ## ライセンス（最上位ルール 17）
#
# **ロゴは商標であって自由ライセンスではない。** 企業ロゴは
# `PD-textlogo`（単純図形で著作権が発生しない）か `Non-free logo` のどちらか。
# **`Non-free` なら使わない。** だから `extmetadata` を必ず出す。
#
# **判断はしない。候補とライセンスを持ち帰るだけ。**
#
# **270 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t164-logos-mediawiki.md"
DIR="$RDIR/logos-mw"
mkdir -p "$DIR"
UA="daily-hack-ops/1.0 (https://daily-hack.fieldbeside.com; contact via GitHub)"

{
  echo "# MediaWiki からロゴを取る・修正版（t164・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**t159〜t161 が全滅したのは \`\"title\":\"File:\"\` で grep していたから。**"
  echo "日本語版は **\`ファイル:\`** を返す。\`utf8=1\` を付けて両方を見るようにした。"
  echo ""
  echo "**\`Non-free logo\` なら使わない**（最上位ルール 17）。判断はクラウド側でやる。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 270 ]; }

api() {  # $1=ウィキ $2...=クエリ
  local wiki="$1"; shift
  curl -sS --max-time 15 -A "$UA" -G "$@" "https://$wiki/w/api.php" 2>/dev/null
}

probe() {  # $1=キー $2=見出し $3=記事名 $4=ウィキ
  local key="$1" jp="$2" art="$3" wiki="${4:-ja.wikipedia.org}" json names n=0
  { echo "## $jp"; echo ""; echo "\`$wiki\` / 記事 \`$art\`"; echo ""; } >> "$OUT"
  json="$(api "$wiki" \
    --data-urlencode "action=query" --data-urlencode "format=json" \
    --data-urlencode "utf8=1" --data-urlencode "redirects=1" \
    --data-urlencode "prop=images" --data-urlencode "imlimit=80" \
    --data-urlencode "titles=$art")"
  if [ -z "$json" ]; then echo "- ⚠️ **API が開けない**" >> "$OUT"; echo "" >> "$OUT"; return; fi
  case "$json" in *'"missing"'*) echo "- ⚠️ **その記事名が無い**（リダイレクトでも届かない）" >> "$OUT"; echo "" >> "$OUT"; return ;; esac

  # **`File:` と `ファイル:` の両方を見る**（t162 で判明）
  names="$(printf '%s' "$json" | tr ',' '\n' \
           | grep -oE '"title":"(File|ファイル):[^"]+"' | sed 's/"title":"//; s/"$//' \
           | grep -iE 'logo|ロゴ|wordmark|ワードマーク' | head -5)"
  if [ -z "$names" ]; then
    echo "- ⚠️ **ロゴらしいファイルが記事に無い。** 記事の画像一覧をそのまま出す" >> "$OUT"
    echo "" >> "$OUT"; echo '```' >> "$OUT"
    printf '%s' "$json" | tr ',' '\n' | grep -oE '"title":"(File|ファイル):[^"]+"' \
      | sed 's/"title":"//; s/"$//' | head -14 >> "$OUT" || true
    echo '```' >> "$OUT"; echo "" >> "$OUT"; return
  fi

  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    over && break
    local info url lic ext sz
    info="$(api "$wiki" \
      --data-urlencode "action=query" --data-urlencode "format=json" \
      --data-urlencode "utf8=1" --data-urlencode "prop=imageinfo" \
      --data-urlencode "iiprop=url|extmetadata|size|mime" \
      --data-urlencode "titles=$f")"
    url="$(printf '%s' "$info" | grep -oE '"url":"[^"]+"' | head -1 | sed 's/"url":"//; s/"$//; s#\\/#/#g')"
    lic="$(printf '%s' "$info" | grep -oE '"LicenseShortName":\{"value":"[^"]*"' | head -1 | sed 's/.*"value":"//; s/"$//')"
    echo "- \`$f\`" >> "$OUT"
    echo "  - ライセンス: **${lic:-不明}**" >> "$OUT"
    [ -n "$url" ] || { echo "  - ⚠️ **実体 URL が取れない**" >> "$OUT"; continue; }
    echo "  - \`$(printf '%s' "$url" | head -c 110)\`" >> "$OUT"
    case "$url" in *.svg) ext=svg ;; *.jpg|*.jpeg) ext=jpg ;; *) ext=png ;; esac
    if curl -sS -L --max-time 15 -A "$UA" -o "$DIR/$key-$n.$ext" "$url" 2>/dev/null; then
      sz=$(wc -c < "$DIR/$key-$n.$ext" | head -1 | tr -d ' ')
      case "$sz" in ''|*[!0-9]*) sz=0 ;; esac
      if [ "$sz" -le 200 ]; then rm -f "$DIR/$key-$n.$ext"; echo "  - ⚠️ **中身が無い**" >> "$OUT"
      else echo "  - ⬇️ \`$key-$n.$ext\`（**$sz bytes**）" >> "$OUT"; n=$((n + 1)); fi
    fi
    [ "$n" -ge 2 ] && break
  done <<EOF
$names
EOF
  echo "" >> "$OUT"
}

probe jal      "JAL（日本航空）"  "日本航空"
over || probe satofull "さとふる"        "さとふる"
over || probe promise  "プロミス"        "プロミス (消費者金融)"
over || probe acom     "アコム"          "アコム"
over || probe mobit    "SMBCモビット"    "SMBCモビット"
over || probe lake     "レイク"          "レイク (消費者金融)"
over || probe aiful    "アイフル"        "アイフル"

{
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**\`Non-free logo\` は使わない。\`PD-textlogo\` / \`PD-simple\` なら識別目的で使える。**"
  echo "**採否はクラウド側でコンタクトシートを見て決める。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
