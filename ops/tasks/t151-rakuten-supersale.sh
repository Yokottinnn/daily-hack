#!/bin/bash
# **楽天スーパーSALE の「いま」を公式から取る（t151）。LLM 不使用・$0。**
#
# `check-stale-wording.py` が拾った。`amazon-prime-day-rakuten-ss-2026` にこうある。
#
#   楽天スーパーSALE（次回見込み） 2026年9月上旬見込み（例年3・6・9・12月開催）
#   ※…正式日程は楽天の告知待ち
#
# **いまは 9月21日。** 9月上旬はとっくに過ぎている。
# 実際に開催されたのか、次はいつなのか、**推測で書かない。公式を見る。**
#
# **要約しない。本文をそのまま持ち帰る。** 数字を丸めると裏取りにならない。
# **判断はクラウド側でやる。**
#
# **90 秒 で終わる**（数リクエスト）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t151-rakuten-supersale.md"
mkdir -p "$RDIR"
UA="daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"

{
  echo "# 楽天スーパーSALE の「いま」（t151・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**要約していない。公式の本文をそのまま持ち帰っている。**"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

dump() {  # $1=ラベル $2=URL
  local label="$1" url="$2" html
  { echo "## $label"; echo ""; echo "\`$url\`"; echo ""; } >> "$OUT"
  html="$(curl -sS -L --max-time 20 -A "$UA" "$url" 2>/dev/null)" || html=""
  if [ -z "$html" ]; then
    echo "- ⚠️ **開けない**" >> "$OUT"; echo "" >> "$OUT"; return
  fi
  echo "- HTML **$(printf '%s' "$html" | wc -c | tr -d ' ') bytes**" >> "$OUT"
  echo "" >> "$OUT"
  echo '```text' >> "$OUT"
  # タグを落として本文だけにする。**先頭 2500 字**
  printf '%s' "$html" \
    | sed -E 's#<(script|style)[^>]*>.*</\1>##g' \
    | sed -E 's#<br[^>]*>#\n#g; s#</(p|div|li|tr|h[1-6])>#\n#g' \
    | sed -E 's#<[^>]+># #g' \
    | tr -s ' \t' ' ' \
    | grep -v '^ *$' \
    | head -c 2500 >> "$OUT"
  { echo ""; echo '```'; echo ""; } >> "$OUT"

  # **日付らしきものを拾って別に出す。** 本文に埋もれると見落とす
  echo "**日付らしきもの**" >> "$OUT"
  echo "" >> "$OUT"
  printf '%s' "$html" | sed -E 's#<[^>]+># #g' \
    | grep -oE '20[0-9]{2}年[0-9]{1,2}月[0-9]{1,2}日|[0-9]{1,2}/[0-9]{1,2}\([月火水木金土日]\)|[0-9]{1,2}月[0-9]{1,2}日' \
    | sort -u | head -12 | sed 's/^/  - /' >> "$OUT" || echo "  - 見つからない" >> "$OUT"
  echo "" >> "$OUT"
}

dump "楽天スーパーSALE（公式）" "https://event.rakuten.co.jp/campaign/supersale/"
dump "楽天市場のイベント一覧" "https://event.rakuten.co.jp/"

{
  echo "---"
  echo ""
  echo "**開催中なら期間が、終わっていれば次回の告知が出ているはず。**"
  echo "**出ていなければ「出ていない」と書く。** 推測で日付を埋めない。"
} >> "$OUT"

cat "$OUT"
