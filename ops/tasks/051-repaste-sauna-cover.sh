#!/bin/bash
# **1 枚目を貼り直す。キャラと温泉マークが入る前の版が貼られている。**
#
#   044 の実行   2026-08-30 20:39 JST（origin/main = bdc2512）
#   #271 マージ  2026-08-30 20:48 JST（キャラ＋♨ を追加）
#
# **9 分 早かった。** 貼られた 1-summary.jpg は 257741 B で、キャラ入りの版
# （273571 B）ではない。Jordan は「右上にキャラを透過で」と指示しているので、
# **この状態の 👍 は取りに行けない。**
#
# 2〜4 枚目は変わっていないので貼り直さない。**1 枚目だけ**。
#
# ## 確かめてから貼る
#
# サイズだけでは版を取り違える。**キャラ画像が実際に合成されているか**を
# 画素で確かめる。右上 220×220 にキャラのピンク（髪色）が十分あるかを見る。
# 無ければ貼らずに中止する。**古い版をもう一度貼らない。**
#
# **出力は公開リポジトリに載る。** トークンは値を出さない。**LLM を呼ばない（$0）。**
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
ENVF="$HOME/openclaw/config/.env"
OUT="${OPS_REPORT_DIR:-/tmp}/repaste-cover.md"
TMPD="${TMPDIR:-/tmp}/repaste.$$"
CH=C0A5FKU7T5M
TS=1788083265.060919
IMG=public/images/sauna-openings-2026/x/1-summary.jpg
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
PY="$(command -v python3.11 || command -v python3)"

mkdir -p "$TMPD"; trap 'rm -rf "$TMPD"' EXIT

{
echo "# 1 枚目を貼り直す（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> 044 は #271（キャラ＋♨）のマージより **9 分 早く**走った。"
echo "> 貼られた 1 枚目は**キャラが入る前の版**。"

echo
echo "## 1. 最新を取り出す"
echo
git -C "$REPO" fetch -q origin main 2>/dev/null && echo "- fetch: 成功" || echo "- fetch: **失敗**"
echo "- origin/main: $(git -C "$REPO" log --oneline -1 origin/main 2>/dev/null | mask)"
DST="$TMPD/1-summary.jpg"
if git -C "$REPO" show "origin/main:$IMG" > "$DST" 2>/dev/null && [ -s "$DST" ]; then
  echo "- 取り出せた: $(wc -c < "$DST" | tr -d ' ') B"
else
  echo "- **取り出せない。中止。**"; exit 1
fi

echo
echo "## 2. キャラが本当に写っているか（サイズでは判断しない）"
echo
CHECK="$("$PY" - "$DST" <<'PY' 2>&1
import sys, struct, zlib
# 依存を増やさずに JPEG を読むのは面倒なので、PIL があれば使う。無ければ諦めて報告する
try:
    from PIL import Image
except Exception:
    print("SKIP PIL が無いので画素で確かめられない"); sys.exit(0)
im = Image.open(sys.argv[1]).convert("RGB")
w, h = im.size
# 右上のキャラがいる領域
box = im.crop((w-260, 20, w-20, 230))
pink = 0
for r, g, b in box.getdata():
    if r > 180 and 60 < g < 165 and 110 < b < 210 and r - g > 55:
        pink += 1
ratio = pink / (box.width * box.height)
print(f"{'OK' if ratio > 0.03 else 'NG'} 右上のピンク比率 {ratio:.3%}")
PY
)"
echo "- $CHECK"
case "$CHECK" in
  NG*) echo; echo "**キャラが写っていない。古い版を掴んでいる。貼らずに中止する。**"; exit 1;;
  SKIP*) echo "  → 画素で確かめられないが、サイズが 044 時点（257741 B）と違えば新しい版";;
esac

echo
echo "## 3. 貼る"
echo
if ! grep -q '^OPENCLAW_BOT_TOKEN=' "$ENVF" 2>/dev/null; then
  echo "- \`OPENCLAW_BOT_TOKEN\`: **無い。中止。**"; exit 1
fi
echo "- \`OPENCLAW_BOT_TOKEN\`: **有り**（値は出さない）"
TOKEN="$(grep '^OPENCLAW_BOT_TOKEN=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
sz="$(wc -c < "$DST" | tr -d ' ')"
u1="$(curl -sS -G "https://slack.com/api/files.getUploadURLExternal" \
      -H "Authorization: Bearer $TOKEN" \
      --data-urlencode "filename=1-summary-v2.jpg" --data-urlencode "length=$sz" 2>/dev/null)"
url="$(printf '%s' "$u1" | sed -n 's/.*"upload_url":"\([^"]*\)".*/\1/p' | sed 's#\\/#/#g')"
fid="$(printf '%s' "$u1" | sed -n 's/.*"file_id":"\([^"]*\)".*/\1/p')"
if [ -z "$url" ] || [ -z "$fid" ]; then
  echo "- **URL を取れない** — $(printf '%s' "$u1" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p' | head -1)"; exit 1
fi
curl -sS -X POST "$url" -F "file=@$DST" >/dev/null 2>&1
u3="$(curl -sS -X POST "https://slack.com/api/files.completeUploadExternal" \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json; charset=utf-8" \
      -d "{\"files\":[{\"id\":\"$fid\",\"title\":\"1-summary.jpg（差し替え版・右上にキャラと♨）\"}],\"channel_id\":\"$CH\",\"thread_ts\":\"$TS\"}" 2>/dev/null)"
if printf '%s' "$u3" | grep -q '"ok":true'; then
  echo "- **貼れた**（1 枚目・差し替え版）"
else
  echo "- **失敗** — $(printf '%s' "$u3" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p' | head -1)"
fi

echo
echo "## 4. 次にすること"
echo
echo "- **後から貼ったほうが最新。** 先に貼った 1 枚目はキャラが入っていない"
echo "- 2〜4 枚目は変わっていないので貼り直していない"
echo "- **画像を見たうえでの 👍 をもらってから投稿する**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
grep -q '貼れた' "$OUT" 2>/dev/null && echo "1 枚目を貼り直した / $(basename "$OUT")" || echo "**貼り直せていない** / $(basename "$OUT")"
