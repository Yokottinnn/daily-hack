#!/bin/bash
# **記事が外部から読んでいる画像 85 件が、いま生きているかを確かめる（t154）。$0。**
#
# ## なぜ
#
# **他所のサイトの画像は、こちらの都合と関係なく消える。**
# クレカ比較の記事には `20250228_02_image01_sp.jpg` のような**キャンペーン画像**が
# 貼ってある。キャンペーンが終われば消えるが、**消えてもビルドも検査も通る。**
# だから誰も気づけない。
#
# **クラウドセッションからは確かめられない**（外部 HTTPS が塞がれていて、
# 全部 `ERR_TUNNEL_CONNECTION_FAILED` になる）。Mac から見に行く。
#
# ## 出すもの
#
#   slug / HTTP ステータス / Content-Type / バイト数
#
# **`rc` ではなくステータスと中身の大きさで判断する**（最上位ルール 13）。
# 200 でも **0 バイト**や `text/html`（＝エラーページ）のことがある。
#
# **判断はしない。** 差し替えるかどうかはクラウド側で決める。
# **一覧は `ops/data/external-images.txt`。** 推測で URL を組み立てない。
#
# **240 秒 で打ち切る**（最上位ルール 15）。残りは「見ていない」と書く。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t154-external-images.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"

{
  echo "# 外部から読んでいる画像は生きているか（t154・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**判断はしない。状態を出すだけ。**"
  echo "**200 でも 0 バイトや \`text/html\` なら死んでいる**（最上位ルール 13）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

# **一覧は origin/main から取り出す。** 作業ツリーは追従していない（最上位ルール 14）
LIST="${TMPDIR:-/tmp}/t154-list.txt"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
if ! git -C "$REPO" show origin/main:ops/data/external-images.txt > "$LIST" 2>/dev/null; then
  echo "⚠️ **一覧が取り出せない**（\`ops/data/external-images.txt\`）" >> "$OUT"
  cat "$OUT"; exit 0
fi

START=$(date +%s)
N=0; DEAD=0; OK=0; SKIPPED=0

{
  echo "| 記事 | 状態 | 種類 | 大きさ | URL |"
  echo "| --- | --- | --- | ---: | --- |"
} >> "$OUT"

# **末尾に改行が無くても最後の 1 行を読む**（最上位ルール 14）
while IFS=$'\t' read -r slug url || [ -n "$slug" ]; do
  case "$slug" in ''|\#*) continue ;; esac
  [ -n "$url" ] || continue
  if [ $(( $(date +%s) - START )) -ge 240 ]; then
    SKIPPED=$((SKIPPED + 1)); continue
  fi
  N=$((N + 1))
  # **-L で追う。** リダイレクト先で消えていることがある
  res="$(curl -sS -L --max-time 12 -A "$UA" -o /dev/null \
         -w '%{http_code}\t%{content_type}\t%{size_download}' "$url" 2>/dev/null)" || res=$'000\t-\t0'
  code="$(printf '%s' "$res" | cut -f1)"
  ctype="$(printf '%s' "$res" | cut -f2 | cut -d';' -f1)"
  size="$(printf '%s' "$res" | cut -f3)"
  case "$size" in ''|*[!0-9]*) size=0 ;; esac
  is_img=0
  case "$ctype" in image/*) is_img=1 ;; esac
  mark="✅"
  if [ "$code" != "200" ]; then
    mark="❌"; DEAD=$((DEAD + 1))
  elif [ "$size" -lt 500 ]; then
    mark="❌ **中身が無い**"; DEAD=$((DEAD + 1))
  elif [ "$is_img" -eq 0 ]; then
    mark="❌ **画像ではない**"; DEAD=$((DEAD + 1))
  else
    OK=$((OK + 1))
  fi
  echo "| \`$slug\` | $mark $code | $ctype | $size | \`$(printf '%s' "$url" | head -c 64)\` |" >> "$OUT"
done < "$LIST"

{
  echo ""
  echo "---"
  echo ""
  echo "**見た $N 件 / 生きている $OK 件 / 死んでいる $DEAD 件**"
  [ "$SKIPPED" -gt 0 ] && echo "**⏱️ 時間切れで見ていない $SKIPPED 件**（次の周回で見る）"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
