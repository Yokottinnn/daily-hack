#!/bin/bash
# **dカード / エポスカードのロゴ、3 回目（t149）。LLM 不使用・$0。**
#
# ## ここまでで分かっていること
#
# | 回 | 取れたもの | 判定 |
# | --- | --- | --- |
# | t146 | コモンズ検索 | **全滅**（xDカード・Dポイント・バラの Epos・NASA の TBC 試験片） |
# | t146 | `EPOS Net` のヘッダーロゴ | **会員サイト名。カードのロゴではない** |
# | t148 | `DcardCharmLogo01〜06.gif`（65×65） | **買い物カート・NO の紙・d マーク**の特長アイコン |
# | t148 | `エポトクプラザ` / `ポイントUPサイト` | **別サービスのロゴ** |
#
# **`<img>` を漁る方針が尽きた。** ダンプに**まだ取っていない本命**が出ている。
#
#   dカード   og:image  = /st/common/images/ogp_logo.png
#             apple-touch-icon-precomposed = /st/common/images/webclip.png
#   エポス    og:image  = /common-files/img/ogimg.jpg
#             apple-touch-icon-precomposed = /apple-touch-icon-precomposed.png
#
# **`og:image` はバナーのことが多い**（blog-article スキル）。だが
# **`apple-touch-icon` はブランドマークであることが多い。** 両方 取って目で見る。
#
# **`com_foot_logo02.gif`（alt=株式会社エポスカード）は取らない。**
# **運営会社のロゴを、カードのロゴとして出さない**（最上位ルール 17）。
#
# **これで取れなければ、取れないと書いてロゴ無しで出す。**
# 推測で別ブランドを当てるくらいなら、無いほうがよい。
#
# **60 秒 で終わる**（6 リクエスト）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t149-dcard-epos-icon.md"
DIR="$RDIR/logos-card3"
mkdir -p "$DIR"
UA="daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"

{
  echo "# dカード / エポスカードのロゴ、3 回目（t149・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**判断はしない。候補を持ち帰るだけ。**"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

grab() {  # $1=保存名 $2=URL $3=説明
  local name="$1" url="$2" what="$3" ext="png" rc
  case "$url" in *.jpg|*.jpeg) ext="jpg" ;; *.gif) ext="gif" ;; *.svg) ext="svg" ;; esac
  if curl -sS -L --max-time 20 -A "$UA" -o "$DIR/$name.$ext" "$url" 2>/dev/null; then
    rc=$(wc -c < "$DIR/$name.$ext" | tr -d ' ')
    case "$rc" in ''|*[!0-9]*) rc=0 ;; esac
    if [ "$rc" -gt 200 ]; then
      echo "- ⬇️ \`$name.$ext\`（**$rc bytes**）$what" >> "$OUT"
      echo "      ← \`$url\`" >> "$OUT"
    else
      echo "- ⚠️ \`$name\` **中身がほぼ空**（$rc bytes）← \`$url\`" >> "$OUT"
      rm -f "$DIR/$name.$ext"
    fi
  else
    echo "- ⚠️ \`$name\` **取れない** ← \`$url\`" >> "$OUT"
  fi
}

{
  echo "## dカード"
  echo ""
} >> "$OUT"
grab "dcard-ogp"    "https://dcard.docomo.ne.jp/st/common/images/ogp_logo.png" "（og:image）"
grab "dcard-webclip" "https://dcard.docomo.ne.jp/st/common/images/webclip.png"  "（apple-touch-icon）"

{
  echo ""
  echo "## エポスカード"
  echo ""
} >> "$OUT"
grab "epos-ogp"     "https://www.eposcard.co.jp/common-files/img/ogimg.jpg" "（og:image）"
grab "epos-webclip" "https://www.eposcard.co.jp/apple-touch-icon-precomposed.png" "（apple-touch-icon）"

{
  echo ""
  echo "## 参考: 各社アプリのストア掲載アイコン"
  echo ""
  echo "**アプリの公式アイコンは提供元が登録したもの**で、ストア API から取れる"
  echo "（blog-article スキル）。**\`trackName\` と \`sellerName\` を必ず出す。**"
  echo "**出さないと ID の取り違えに気づけない。**"
  echo ""
  echo '```text'
} >> "$OUT"

for term in "dカード" "エポスカード"; do
  enc="$(printf '%s' "$term" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')"
  curl -sS -L --max-time 20 -A "$UA" \
    "https://itunes.apple.com/search?term=$enc&country=jp&entity=software&limit=3" 2>/dev/null \
    | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception as e: print('  読めない:', e); raise SystemExit
for r in d.get('results', []):
    print(f\"  {r.get('trackName')} / {r.get('sellerName')} / {r.get('bundleId')}\")
    print(f\"    {r.get('artworkUrl512') or r.get('artworkUrl100')}\")
" >> "$OUT" 2>/dev/null || echo "  検索が失敗（$term）" >> "$OUT"
done

{
  echo '```'
  echo ""
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | tr -d ' ') 件 持ち帰った。**"
  echo "**採否はクラウド側で目で見て決める。**"
  echo "**これで無ければ、取れないと書いてロゴ無しで出す。**"
  echo "推測で別ブランドを当てるくらいなら、無いほうがよい。"
} >> "$OUT"

cat "$OUT"
