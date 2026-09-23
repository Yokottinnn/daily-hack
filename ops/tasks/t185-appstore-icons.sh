#!/bin/bash
# **App Store の公式アイコンで、取得元の記録を付ける（t185）。LLM 不使用・$0。**
#
# ## t183 / t184 だけでは足りない
#
# あの 2 本は**公式サイトのヘッダのロゴ**を取る。**横長のワードマーク**になる。
# ところが `point-service-complete-guide-2026` のロゴは
# **`scripts/render-chaosmap.mjs` が正方形の枠に `object-fit: cover` で描いている。**
#
#   .chip-logo { width:38px; height:38px; object-fit: cover; }
#   .pin img   { width:58px; height:58px; object-fit: cover; }
#
# **横長のワードマークを入れると、真ん中の帯だけが切り出されて読めなくなる。**
# 実際、いま入っている 28 枚は**アプリのアイコン（正方形）**で統一されている。
#
# ## だから App Store から取る
#
# **iTunes Search API は出所が言える。** 返ってくる `artworkUrl512` が実体の URL で、
# `trackName` / `sellerName` で**取り違えていないことも確かめられる。**
# `walk-poikatsu-2026` の `rakutensenior.png` が既にこの出所で記録されている。
#
#   https://itunes.apple.com/search?country=jp&entity=software&limit=3&term=<名前>
#
# **curl だけで足りる。** ブラウザも CDP も要らない（この API は WAF で弾かれない）。
#
# ## 何を持ち帰るか
#
# **判断はしない。** 各ブランドについて
#
#   ① 上位 3 件の `trackName` / `sellerName`（**取り違えを人が見て弾くため**）
#   ② 1 件目の `artworkUrl512` を実際に落としたもの
#
# **採否はクラウド側でコンタクトシートを見て決める。**
# 同名の別アプリ・非公式アプリを掴んでいたら、そこで弾く。
#
# ## 気をつけること
#
# - **`sellerName` が運営会社と合っているかを必ず出す**（最上位ルール 17）
# - **`base64 <file>` を使わない**（macOS は引数のファイル名を受け付けない・最上位ルール 14）。
#   ここでは `curl -o` で直接 書くので、そもそも base64 を通さない
# - **`grep -c ... || echo 0` を書かない**（数字が 2 つ出る・最上位ルール 13）
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t185-appstore-icons.md"
DIR="$RDIR/logos-appstore"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

{
  echo "# App Store の公式アイコンで取得元を付ける（t185・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**\`point-service-complete-guide-2026\` のロゴは正方形のアプリアイコンで統一されている。**"
  echo "\`render-chaosmap.mjs\` が \`object-fit: cover\` の正方形枠で描くため、"
  echo "**横長のワードマークを入れると読めなくなる。**"
  echo ""
  echo "**\`sellerName\` が運営会社と合っているかを必ず見ること**（最上位ルール 17）。"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "**curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "**python3 が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
over() { [ $(( $(date +%s) - START )) -ge 240 ]; }

# key<TAB>表示名<TAB>検索語<TAB>期待する提供元
LIST="$RDIR/.t185-list.tsv"
cat > "$LIST" <<'TSV'
moppy	モッピー	モッピー	セレス
hapitas	ハピタス	ハピタス ポイ活	オズビジョン
pointincome	ポイントインカム	ポイントインカム	ファイブゲート
chobirich	ちょびリッチ	ちょびリッチ	ちょびリッチ
ecnavi	ECナビ	ECナビ	CARTA
macromill	マクロミル	マクロミル アンケート	マクロミル
cuemonitor	キューモニター	キューモニター	インテージ
powl	Powl	Powl アンケート	テスティー
rakuteninsight	楽天インサイト	楽天インサイト	楽天インサイト
anapocket	ANA Pocket	ANA Pocket	ANA
jalwellness	JAL Wellness & Travel	JAL Wellness Travel	JAL
dhealth	dヘルスケア	dヘルスケア	NTTドコモ
rakutenhealth	楽天ヘルスケア	楽天ヘルスケア	Rakuten
torima	トリマ	トリマ 移動	ジオテクノロジーズ
dpoint	dポイント	dポイントクラブ	NTTドコモ
ponta	Pontaポイント	Ponta	ロイヤリティマーケティング
vpoint	Vポイント	Vポイント	CCCMKまたは三井住友
rakuten	楽天ポイント	楽天ポイントカード	Rakuten
waon	WAON POINT	WAON	イオン
nanaco	nanaco	nanaco	セブン
jrepoint	JRE POINT	JRE POINT	JR東日本
olive	Olive	Olive 三井住友	三井住友
aeon	イオン	イオンお買物	イオン
marunouchi	丸の内ポイント	丸の内ポイントアプリ	三菱地所
mitsuisp	三井ショッピングパークポイント	三井ショッピングパーク	三井不動産
TSV

# **末尾に改行が無くても最後の 1 行を読む**（最上位ルール 14）
N_TARGET=0
N_TRIED=0
while IFS=$'\t' read -r key jp term seller || [ -n "${key:-}" ]; do
  [ -n "${key:-}" ] || continue
  N_TARGET=$((N_TARGET + 1))
done < "$LIST"

while IFS=$'\t' read -r key jp term seller || [ -n "${key:-}" ]; do
  [ -n "${key:-}" ] || continue
  over && { echo "## $jp" >> "$OUT"; echo "" >> "$OUT"; echo "- 時間切れ。見ていない" >> "$OUT"; echo "" >> "$OUT"; continue; }
  N_TRIED=$((N_TRIED + 1))

  { echo "## $jp（\`$key\`）"; echo ""; echo "- 検索語 \`$term\` / 期待する提供元 **$seller**"; } >> "$OUT"

  Q="$(printf '%s' "$term" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read().strip()))')"
  JSON="$RDIR/.t185-$key.json"
  curl -sS -A "$UA" --max-time 12 \
    "https://itunes.apple.com/search?country=jp&entity=software&limit=3&term=$Q" \
    -o "$JSON" 2>/dev/null || true

  # **`rc=0` を証拠にしない**（最上位ルール 13）。中身を parse して確かめる
  ART="$(python3 - "$JSON" <<'PY' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print(""); sys.exit(0)
rs = d.get("results") or []
lines = []
for r in rs[:3]:
    lines.append("  - {} / **{}** / id={}".format(
        r.get("trackName", "?"), r.get("sellerName", "?"), r.get("trackId", "?")))
print("\n".join(lines))
print("@@@")
print((rs[0].get("artworkUrl512") or rs[0].get("artworkUrl100") or "") if rs else "")
PY
)"
  ROWS="$(printf '%s' "$ART" | sed -n '1,/^@@@$/p' | sed '$d')"
  URL="$(printf '%s' "$ART" | sed -n '/^@@@$/,$p' | sed '1d' | head -1)"
  rm -f "$JSON"

  if [ -z "$ROWS" ]; then
    { echo "- **上位 3 件が取れない**（API が空か、応答が JSON でない）"; echo ""; } >> "$OUT"
    continue
  fi
  { echo "- 上位 3 件:"; printf '%s\n' "$ROWS"; } >> "$OUT"

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
    { echo "- OK \`$key.png\`（**$n bytes** / HTTP $code）"; echo "  - 取得元: \`$URL\`"; echo ""; } >> "$OUT"
  fi
done < "$LIST"
rm -f "$LIST"

# **「対象 N 件 / 打った M 件」を必ず両方 出す**（最上位ルール 14）
N_GOT=$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ')
case "$N_GOT" in ''|*[!0-9]*) N_GOT=0 ;; esac
{
  echo "---"
  echo ""
  echo "**対象 $N_TARGET 件 / 打った $N_TRIED 件 / 落とせた $N_GOT 件。**"
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "**採否はクラウド側でコンタクトシートを見て決める。**"
  echo "**\`sellerName\` が期待する提供元と違うものは弾く**（同名の別アプリ・非公式アプリ）。"
} >> "$OUT"

cat "$OUT"
