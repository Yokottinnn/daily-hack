#!/bin/bash
# **サウナ告知の草案スレッドに、作り直した正方形画像 4 枚を貼る。**
#
# 草案 v2 は 2026-08-30 に Slack へ出してある。文面はあるが画像がまだ無い。
# **画像を見たうえでの 👍 でなければ投稿しない**（CLAUDE.md 最上位ルール 4）ので、
# ここが通らないと先へ進めない。
#
# ## 041 の失敗を繰り返さない
#
# 041 は `$REPO/public/images/...` を**作業ツリーのファイル**として見て、
# 4 枚とも「画像が無い」で飛ばした。Mac のチェックアウトが最新とは限らない。
# **`git show origin/main:<path>` で取り出す**（043 と同じ）。
#
# ## 貼る先
#
#   親    1788083240.782739  ドラフト v2
#   [1/2] 1788083265.060919  ← ここに 4 枚まとめて貼る
#   [2/2] 1788083445.006269  記事紹介（画像なし）
#
# ## 秘密を出さない
#
# **結果は公開リポジトリに載る。** `OPENCLAW_BOT_TOKEN` はキー名だけ。
# レポート全体を最後にマスクへ通す。
#
# **LLM を呼ばない（費用 $0）。**
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
ENVF="$HOME/openclaw/config/.env"
OUT="${OPS_REPORT_DIR:-/tmp}/upload-sauna-x.md"
TMPD="${TMPDIR:-/tmp}/sauna-x.$$"
CH=C0A5FKU7T5M
TS=1788083265.060919
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

IMGS="public/images/sauna-openings-2026/x/1-summary.jpg|6施設まとめ
public/images/sauna-openings-2026/x/2-maihama.jpg|舞浜ユーラシア
public/images/sauna-openings-2026/x/3-takanawa.jpg|高輪SAUNAS
public/images/sauna-openings-2026/x/4-oimachi.jpg|サウナメッツァ大井町"

mkdir -p "$TMPD"
trap 'rm -rf "$TMPD"' EXIT

{
echo "# サウナ告知の画像 4 枚を貼る（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **画像を見たうえでの 👍 でなければ投稿しない。** ここが通らないと先へ進めない。"

echo
echo "## 1. リポジトリを最新にする"
echo
if [ ! -d "$REPO/.git" ]; then
  echo "- **\`$REPO\` が git リポジトリでない。中止。**"; exit 1
fi
git -C "$REPO" fetch -q origin main 2>/dev/null && echo "- fetch: 成功" || echo "- fetch: **失敗**（ローカルの origin/main で続行）"
echo "- origin/main: $(git -C "$REPO" log --oneline -1 origin/main 2>/dev/null | mask)"

echo
echo "## 2. 画像を取り出す（**作業ツリーではなく origin/main から**）"
echo
printf '%s\n' "$IMGS" | while IFS='|' read -r img label; do
  [ -n "$img" ] || continue
  dst="$TMPD/$(basename "$img")"
  if git -C "$REPO" show "origin/main:$img" > "$dst" 2>/dev/null && [ -s "$dst" ]; then
    echo "- $label: 取り出せた（$(wc -c < "$dst" | tr -d ' ') B）"
  else
    rm -f "$dst"; echo "- $label: **origin/main に \`$img\` が無い**"
  fi
done

got="$(ls -1 "$TMPD" 2>/dev/null | wc -l | tr -d ' ')"
echo
echo "取り出せた枚数: ${got:-0} / 4"
if [ "${got:-0}" != "4" ]; then
  echo
  echo "**4 枚そろわないので貼らない。** 一部だけ貼ると、どれを見て 👍 したのか分からなくなる。"
  echo
  echo "origin/main の x/ 配下:"
  git -C "$REPO" ls-tree -r --name-only origin/main -- public/images/sauna-openings-2026/x 2>/dev/null | sed 's/^/    /'
  exit 1
fi

echo
echo "## 3. トークン"
echo
if [ ! -f "$ENVF" ]; then echo "- \`~/openclaw/config/.env\` が無い。**中止。**"; exit 1; fi
if grep -q '^OPENCLAW_BOT_TOKEN=' "$ENVF" 2>/dev/null; then
  echo "- \`OPENCLAW_BOT_TOKEN\`: **有り**（値は出さない）"
  TOKEN="$(grep '^OPENCLAW_BOT_TOKEN=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
else
  echo "- \`OPENCLAW_BOT_TOKEN\`: **無い。中止。**"; exit 1
fi

echo
echo "## 4. アップロード（[1/2] のスレッドへ 4 枚）"
echo
printf '%s\n' "$IMGS" | while IFS='|' read -r img label; do
  [ -n "$img" ] || continue
  p="$TMPD/$(basename "$img")"
  [ -s "$p" ] || { echo "- $label: 取り出せていないので飛ばす"; continue; }
  sz="$(wc -c < "$p" | tr -d ' ')"; fn="$(basename "$img")"

  u1="$(curl -sS -G "https://slack.com/api/files.getUploadURLExternal" \
        -H "Authorization: Bearer $TOKEN" \
        --data-urlencode "filename=$fn" --data-urlencode "length=$sz" 2>/dev/null)"
  url="$(printf '%s' "$u1" | sed -n 's/.*"upload_url":"\([^"]*\)".*/\1/p' | sed 's#\\/#/#g')"
  fid="$(printf '%s' "$u1" | sed -n 's/.*"file_id":"\([^"]*\)".*/\1/p')"
  if [ -z "$url" ] || [ -z "$fid" ]; then
    echo "- $label: **URL を取れない** — $(printf '%s' "$u1" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p' | head -1)"
    continue
  fi
  curl -sS -X POST "$url" -F "file=@$p" >/dev/null 2>&1
  u3="$(curl -sS -X POST "https://slack.com/api/files.completeUploadExternal" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "{\"files\":[{\"id\":\"$fid\",\"title\":\"$fn（$label）\"}],\"channel_id\":\"$CH\",\"thread_ts\":\"$TS\"}" 2>/dev/null)"
  if printf '%s' "$u3" | grep -q '"ok":true'; then
    echo "- $label: **貼れた**"
  else
    echo "- $label: **失敗** — $(printf '%s' "$u3" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p' | head -1)"
  fi
done

echo
echo "## 5. 貼れたあと"
echo
echo "- 1 枚目は **6 施設のまとめ**（舞浜ユーラシア／PARADISE 大手町／高輪SAUNAS／"
echo "  サウナメッツァ大井町／BlueOcean／sauna KOHAKU）"
echo "- 2〜4 枚目は**実際にオープンした施設の実写**。出典は画像の中に焼き込んである"
echo "- **Jordan が画像そのものを見たうえでの 👍 でなければ投稿しない**"
} > "$OUT" 2>&1

if [ -f "$OUT" ]; then mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; fi
ok="$(grep -c '貼れた' "$OUT" 2>/dev/null || true)"
echo "画像 ${ok:-0}/4 枚を草案スレッドへ貼った / $(basename "$OUT")"
