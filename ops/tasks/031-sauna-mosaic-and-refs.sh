#!/bin/bash
# (1) 参考記事 3 本の本文を持ち帰る (2) 施設写真でタイル合成のアイキャッチを作る。
#
# クラウド側は WebFetch も curl も全ホストで塞がれている（2026-08-27 実測）。
# 記事の取得も画像の取得も Mac を経由するしかない。
#
# 画像は各施設の公式ページの og:image を使う。**この方式は既存記事と同じ**
# （outlet-mall-guide-2026 の「カード画像は各運営会社の公式サイトより引用」）。
# 取った画像はサムネイルも push するので、**採用前に必ず目で見る。**
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SLUG="sauna-openings-2026"
BRANCH="claude/sauna-mosaic-eyecatch"
WT="${TMPDIR:-/tmp}/dh-mos-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }
[ -f "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" ] || { echo "ヒラギノが無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1

detag() {
  sed -e 's/<script[^>]*>.*<\/script>//g' -e 's/<style[^>]*>.*<\/style>//g' \
      -e 's/<br[^>]*>/\n/g' -e 's/<\/\(p\|div\|li\|h[1-6]\|tr\)>/\n/g' -e 's/<[^>]*>//g' \
    | sed -e 's/&nbsp;/ /g' -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e "s/&#39;/'/g"
}

# ---------- (1) 参考記事 ----------
{
  echo "# 参考記事の本文（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  for u in \
    "https://www.asoview.com/note/7948/" \
    "https://www.timeout.jp/tokyo/ja/things-to-do/new-sauna-bathing-facilities-opening-in-2026" \
    "https://onsen.nifty.com/rank/sauna/kanto/"; do
    echo
    echo "## $u"
    echo
    echo '```'
    curl -sSL --max-time 40 -A "$UA" "$u" 2>&1 | detag | grep -v '^[[:space:]]*$' | sed -n '1,400p' | cut -c1-300
    echo '```'
  done
} > "$RDIR/sauna-refs.md"

# ---------- (2) 施設写真 ----------
TILES="tiles"; mkdir -p "$TILES"
ogimg() { # $1=url  → og:image の URL を1つ返す
  curl -sSL --max-time 30 -A "$UA" "$1" 2>/dev/null \
    | grep -oE '<meta[^>]+property="og:image"[^>]*>' | head -1 \
    | grep -oE 'content="[^"]+"' | head -1 | sed 's/content="//; s/"$//'
}
grab() { # $1=key  $2..=候補URL
  local key="$1"; shift
  local u img
  for u in "$@"; do
    img="$(ogimg "$u")"
    [ -z "$img" ] && continue
    case "$img" in /*) img="$(printf '%s' "$u" | sed -E 's#(https?://[^/]+).*#\1#')$img" ;; esac
    if curl -sSL --max-time 40 -A "$UA" -o "$TILES/$key.img" "$img" 2>/dev/null && [ -s "$TILES/$key.img" ]; then
      if "$PY" - "$TILES/$key.img" "$TILES/$key.jpg" <<'PYX' 2>/dev/null
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
if min(im.size) < 300: raise SystemExit(1)
im.save(sys.argv[2], quality=92)
PYX
      then rm -f "$TILES/$key.img"; echo "| \`${key}\` | ${u} | ${img} |"; return 0; fi
      rm -f "$TILES/$key.img"
    fi
  done
  echo "| \`${key}\` | 取得できず | — |"; return 1
}

{
  echo
  echo "# 施設写真（og:image）"
  echo
  echo "| キー | 取得元ページ | 画像 URL |"
  echo "| --- | --- | --- |"
  grab takanawa  "https://saunas-saunas.com/takanawa"
  grab oimachi   "https://ryusenjinoyu.com/saunametsaoimachi/"
  grab blueocean "http://k-scc.co.jp/sauna/" "http://k-scc.co.jp/sauna/price/price.html"
  grab monnaka   "https://lo.saunas-saunas.com/monnaka/"
  grab paradise  "https://spaworks.jp/article/7704" "https://onsen.nifty.com/ootemachi-onsen/onsen024731/"
  grab koganeyu  "https://koganeyu.com/" "https://www.1010.or.jp/map/item/item-cnt-331"
  echo
} >> "$RDIR/sauna-refs.md"

# サムネイル（レビュー用）
for f in "$TILES"/*.jpg; do
  [ -f "$f" ] || continue
  "$PY" - "$f" "$TILES/thumb-$(basename "$f")" <<'PYX' 2>/dev/null
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB"); w, h = im.size
im.resize((480, max(1, int(h*480/w))), Image.LANCZOS).save(sys.argv[2], quality=72)
PYX
done

N=$(ls "$TILES"/[a-z]*.jpg 2>/dev/null | grep -v thumb | wc -l | tr -d ' ')
if [ "$N" -ge 6 ]; then
  # shellcheck disable=SC2046
  "$PY" scripts/gen-mosaic-hero.py \
    "public/images/$SLUG/eyecatch.jpg" \
    "2026年オープン" "サウナ新店" "首都圏15施設" \
    "料金・最寄駅・男女別で全部並べた" \
    "画像: 各施設公式サイト" \
    $(ls "$TILES"/[a-z]*.jpg | grep -v thumb | head -6) >> "$RDIR/sauna-refs.md" 2>&1
  echo "合成した（$N 枚から 6 枚）" >> "$RDIR/sauna-refs.md"
else
  echo "画像が $N 枚しか取れず合成は見送った" >> "$RDIR/sauna-refs.md"
fi

git -C "$WT" add -A "public/images/$SLUG" "$TILES" 2>/dev/null
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "assets: 施設写真のタイル合成アイキャッチと元画像

各施設の公式ページの og:image から取得。tiles/ はレビュー用（採用前に目で見る）。" \
  || { echo "コミットするものが無い"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" || { echo "push 失敗"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "push した: $BRANCH（tiles $N 枚 / 参考記事は reports/sauna-refs.md）"
