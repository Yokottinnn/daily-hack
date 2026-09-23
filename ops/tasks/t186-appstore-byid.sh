#!/bin/bash
# **取り違えた 2 件を id 指定で取り直す（t186）。LLM 不使用・$0。**
#
# ## t185 で 3 件 弾いた。そのうち 2 件は正解の id が分かっている
#
# **検索の 1 件目を採る作りだったので、親ブランド・別サービスを掴んだ。**
# コンタクトシートで突き合わせて弾いたが、**上位 3 件の中に正解が写っていた。**
#
# | key | t185 の 1 件目 | 正しいもの |
# | --- | --- | --- |
# | `jalwellness` | **JAL**（Japan Airlines・親ブランド） | **id=1498726068** JAL Wellness & Travel |
# | `rakuten` | **楽天ペイ**（別サービス） | **id=641501350** 楽天ポイントクラブ |
#
# **`powl` は取り直さない。** 現行の App Store アイコンが**ハロウィンの季節版**で、
# id を指定しても季節版が返る。既存の通常版を残す（最上位ルール 17）。
#
# ## 検索ではなく lookup を使う
#
#   https://itunes.apple.com/lookup?id=<trackId>&country=jp
#
# **id で引くので取り違えようがない。** それでも `trackName` / `sellerName` は出す
# （**「合っていること」を人が見て確かめられる状態にする**・最上位ルール 11）。
#
# **60 秒 で打ち切る**（最上位ルール 15）。2 件しか見ない。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t186-appstore-byid.md"
DIR="$RDIR/logos-appstore2"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

{
  echo "# 取り違えた 2 件を id 指定で取り直す（t186・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**t185 は検索の 1 件目を採る作りだったので、親ブランドと別サービスを掴んだ。**"
  echo "id で引き直す。**\`powl\` は季節版しか返らないので取り直さない。**"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "**curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "**python3 が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
N_TARGET=0
N_GOT=0

# key<TAB>表示名<TAB>trackId<TAB>期待する trackName
LIST="$RDIR/.t186-list.tsv"
cat > "$LIST" <<'TSV'
jalwellness	JAL Wellness & Travel	1498726068	JAL Wellness
rakuten	楽天ポイント（楽天ポイントクラブ）	641501350	楽天ポイントクラブ
TSV

# **末尾に改行が無くても最後の 1 行を読む**（最上位ルール 14）
while IFS=$'\t' read -r key jp tid want || [ -n "${key:-}" ]; do
  [ -n "${key:-}" ] || continue
  N_TARGET=$((N_TARGET + 1))
  [ $(( $(date +%s) - START )) -ge 60 ] && { echo "## $jp" >> "$OUT"; echo "" >> "$OUT"; echo "- 時間切れ" >> "$OUT"; echo "" >> "$OUT"; continue; }

  { echo "## $jp（\`$key\`）"; echo ""; echo "- \`id=$tid\` / 期待する名前 **$want**"; } >> "$OUT"

  JSON="$RDIR/.t186-$key.json"
  curl -sS -A "$UA" --max-time 12 \
    "https://itunes.apple.com/lookup?id=$tid&country=jp" -o "$JSON" 2>/dev/null || true

  # **`rc=0` を証拠にしない**（最上位ルール 13）。parse して確かめる
  INFO="$(python3 - "$JSON" <<'PY' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
rs = d.get("results") or []
if not rs:
    sys.exit(0)
r = rs[0]
print("{} / {}".format(r.get("trackName", "?"), r.get("sellerName", "?")))
print(r.get("artworkUrl512") or r.get("artworkUrl100") or "")
PY
)"
  rm -f "$JSON"
  NAME="$(printf '%s' "$INFO" | sed -n '1p')"
  URL="$(printf '%s' "$INFO" | sed -n '2p')"

  if [ -z "$NAME" ]; then
    { echo "- **lookup が空**（応答が JSON でないか結果 0 件）"; echo ""; } >> "$OUT"; continue
  fi
  echo "- 返ってきたもの: **$NAME**" >> "$OUT"
  if [ -z "$URL" ]; then
    { echo "- **アイコンの URL が無い**"; echo ""; } >> "$OUT"; continue
  fi

  F="$DIR/$key.png"
  code="$(curl -sS -A "$UA" --max-time 15 -o "$F" -w '%{http_code}' "$URL" 2>/dev/null || echo 000)"
  n=$(wc -c < "$F" 2>/dev/null | head -1 | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -le 1000 ]; then
    rm -f "$F"
    { echo "- **落とせない**: HTTP $code / $n bytes"; echo "  - \`$URL\`"; echo ""; } >> "$OUT"
  else
    N_GOT=$((N_GOT + 1))
    { echo "- OK \`$key.png\`（**$n bytes** / HTTP $code）"; echo "  - 取得元: \`$URL\`"; echo ""; } >> "$OUT"
  fi
done < "$LIST"
rm -f "$LIST"

# **「対象 N 件 / 取れた M 件」を必ず両方 出す**（最上位ルール 14）
{
  echo "---"
  echo ""
  echo "**対象 $N_TARGET 件 / 落とせた $N_GOT 件。** 経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "**返ってきた名前が期待と違えば、採らない。**"
} >> "$OUT"

cat "$OUT"
