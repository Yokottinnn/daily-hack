#!/bin/bash
# x436（2026-11-08・読むだけ・$0）: 大人のキッザニア（クリスマス版）の X 投稿の 1 投稿目に、公式の画像を 3 枚くらい付けたい（利用者のコメント 2026-11-08）。
# 手元には kv.png（キービジュアル）と sched.jpg（日程の表）しかない。プレスリリース（PR TIMES）と公式の大人のキッザニアのページから、
# 画像を集めてレポートの置き場に保存する（ops/heartbeat に push される）。**何も書き換えない・投稿しない。**
set -uo pipefail
OUTD="${OPS_REPORT_DIR:-/tmp}/x436-kidzania"; mkdir -p "$OUTD"; OUT="${OPS_REPORT_DIR:-/tmp}/x436-kidzania-official-images.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
{
echo "# 大人のキッザニアの公式の画像を集める（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo '```'
n=0
for page in "https://prtimes.jp/main/html/rd/p/000000428.000078157.html" "https://www.kidzania.jp/tokyo/over16"; do
  H="$OUTD/.page.html"; curl -sL -m 25 -A "$UA" "$page" -o "$H"; echo "--- $page  $(wc -c < "$H" | tr -d ' ') bytes"
  # og:image と、本文の画像（prtimes の release_image・kidzania の画像）
  grep -oE '(content|src|data-src)="[^"]+\.(jpg|jpeg|png|webp)[^"]*"' "$H" | sed -E 's/^[a-z-]+="//; s/"$//' \
   | grep -E 'release_image|prcdn|kidzania|og|/img/|/images/' | grep -viE 'logo|icon|sprite|banner_s|avatar|favicon' | sed 's/&amp;/\&/g' | awk '!s[$0]++' | head -14 > "$OUTD/.urls.txt"
  while IFS= read -r u || [ -n "$u" ]; do
    case "$u" in //*) u="https:$u";; /*) u="$(printf '%s' "$page" | sed -E 's#(https?://[^/]+).*#\1#')$u";; esac
    n=$((n+1)); ext="$(printf '%s' "$u" | sed -E 's/.*\.(jpg|jpeg|png|webp).*/\1/I')"; f="$OUTD/img-$(printf '%02d' $n).$ext"
    curl -sL -m 20 -A "$UA" "$u" -o "$f"; sz="$(wc -c < "$f" | tr -d ' ')"
    if [ "$sz" -lt 15000 ]; then rm -f "$f"; echo "小さいので捨てた $sz  $u"; else echo "img-$(printf '%02d' $n).$ext  $sz bytes  $(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixel/{printf "%s ",$2}')  $u"; fi
  done < "$OUTD/.urls.txt"
done
rm -f "$OUTD/.page.html" "$OUTD/.urls.txt"
echo '```'
echo "保存したもの: $(ls "$OUTD" 2>/dev/null | tr '\n' ' ')"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
