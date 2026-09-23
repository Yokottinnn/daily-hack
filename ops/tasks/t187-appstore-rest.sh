#!/bin/bash
# **取得元が残り 3 枚。そのうち 2 枚を取る（t187）。LLM 不使用・$0。**
#
# ## 残っているもの
#
# | key | 状態 |
# | --- | --- |
# | `paypay.png` | t185 の一覧に入れ忘れた。**id は分かっている**（1435783608） |
# | `rakuten-card.png` | 同上。**id は分からない**ので検索して上位 3 件を持ち帰る |
# | `powl.png` | **取りに行かない。** 現行アイコンが季節版（ハロウィン） |
#
# `paypay` の id は **t185 の「Vポイント」の検索結果の 3 件目**に写っていた。
# **推測ではない**（最上位ルール 11）。
#
# ## 気をつけること
#
# - **楽天カードは「楽天ペイ」「楽天ポイントクラブ」と紛らわしい。**
#   `trackName` / `sellerName` を出して、**クラウド側で弾けるようにする**
# - **`rc=0` を証拠にしない**（最上位ルール 13）。JSON を parse して確かめる
#
# **60 秒 で打ち切る**（最上位ルール 15）。2 件しか見ない。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t187-appstore-rest.md"
DIR="$RDIR/logos-appstore3"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

{
  echo "# 取得元が残っている 2 枚を取る（t187・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**\`powl.png\` は取りに行かない**（現行アイコンが季節版）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "**curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "**python3 が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
N_GOT=0

# **1 件目 は id で引く。** t185 の「Vポイント」の検索結果に写っていた id
{ echo "## PayPay（\`paypay\`）"; echo ""; echo "- \`id=1435783608\`（t185 の Vポイント検索の 3 件目に写っていた）"; } >> "$OUT"
J="$RDIR/.t187-paypay.json"
curl -sS -A "$UA" --max-time 12 "https://itunes.apple.com/lookup?id=1435783608&country=jp" -o "$J" 2>/dev/null || true
INFO="$(python3 - "$J" <<'PY' 2>/dev/null || true
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
rs = d.get("results") or []
if not rs: sys.exit(0)
r = rs[0]
print("{} / {}".format(r.get("trackName","?"), r.get("sellerName","?")))
print(r.get("artworkUrl512") or r.get("artworkUrl100") or "")
PY
)"
rm -f "$J"
NAME="$(printf '%s' "$INFO" | sed -n '1p')"
URL="$(printf '%s' "$INFO" | sed -n '2p')"
if [ -z "$NAME" ] || [ -z "$URL" ]; then
  { echo "- **lookup が空**"; echo ""; } >> "$OUT"
else
  echo "- 返ってきたもの: **$NAME**" >> "$OUT"
  code="$(curl -sS -A "$UA" --max-time 15 -o "$DIR/paypay.png" -w '%{http_code}' "$URL" 2>/dev/null || echo 000)"
  n=$(wc -c < "$DIR/paypay.png" 2>/dev/null | head -1 | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -le 1000 ]; then rm -f "$DIR/paypay.png"
    { echo "- **落とせない**: HTTP $code / $n bytes"; echo ""; } >> "$OUT"
  else
    N_GOT=$((N_GOT + 1))
    { echo "- OK \`paypay.png\`（**$n bytes** / HTTP $code）"; echo "  - 取得元: \`$URL\`"; echo ""; } >> "$OUT"
  fi
fi

# **2 件目 は id が分からないので検索。上位 3 件を全部 出す**
{ echo "## 楽天カード（\`rakuten-card\`）"; echo ""; echo "- 検索語 \`楽天カード\` / 期待する提供元 **Rakuten Card**"; } >> "$OUT"
J="$RDIR/.t187-rc.json"
curl -sS -A "$UA" --max-time 12 \
  "https://itunes.apple.com/search?country=jp&entity=software&limit=3&term=$(printf '楽天カード' | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read().strip()))')" \
  -o "$J" 2>/dev/null || true
ART="$(python3 - "$J" <<'PY' 2>/dev/null || true
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
rs = d.get("results") or []
for r in rs[:3]:
    print("  - {} / **{}** / id={}".format(r.get("trackName","?"), r.get("sellerName","?"), r.get("trackId","?")))
print("@@@")
print((rs[0].get("artworkUrl512") or rs[0].get("artworkUrl100") or "") if rs else "")
PY
)"
rm -f "$J"
ROWS="$(printf '%s' "$ART" | sed -n '1,/^@@@$/p' | sed '$d')"
URL="$(printf '%s' "$ART" | sed -n '/^@@@$/,$p' | sed '1d' | head -1)"
if [ -z "$ROWS" ]; then
  { echo "- **上位 3 件が取れない**"; echo ""; } >> "$OUT"
else
  { echo "- 上位 3 件:"; printf '%s\n' "$ROWS"; } >> "$OUT"
  if [ -z "$URL" ]; then
    { echo "- **アイコンの URL が無い**"; echo ""; } >> "$OUT"
  else
    code="$(curl -sS -A "$UA" --max-time 15 -o "$DIR/rakuten-card.png" -w '%{http_code}' "$URL" 2>/dev/null || echo 000)"
    n=$(wc -c < "$DIR/rakuten-card.png" 2>/dev/null | head -1 | tr -d ' ')
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    if [ "$n" -le 1000 ]; then rm -f "$DIR/rakuten-card.png"
      { echo "- **落とせない**: HTTP $code / $n bytes"; echo ""; } >> "$OUT"
    else
      N_GOT=$((N_GOT + 1))
      { echo "- OK \`rakuten-card.png\`（**$n bytes** / HTTP $code）"; echo "  - 取得元: \`$URL\`"; echo ""; } >> "$OUT"
    fi
  fi
fi

{
  echo "---"
  echo ""
  echo "**対象 2 件 / 落とせた $N_GOT 件。** 経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "**楽天カードは「楽天ペイ」「楽天ポイントクラブ」と紛らわしい。**"
  echo "**\`trackName\` を見て、違えば採らない。**"
} >> "$OUT"

cat "$OUT"
