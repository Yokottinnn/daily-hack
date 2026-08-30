#!/bin/bash
# **草案スレッドに画像を貼る（041 のやり直し）。**
#
# ## 041 が失敗した理由
#
#   ドローン [1/2] 表紙: **public/images/odaiba-drone-show-2026/eyecatch.jpg が無い**
#
# 041 は `$REPO/public/images/...` を**作業ツリーのファイルとして**見た。
# だが Mac のチェックアウトが最新とは限らない（別ブランチ・未 pull）。
# 画像は `origin/main` には確かに在る。**見る場所が違った。**
#
# **028 と同じやり方に揃える。** `git -C "$REPO" show origin/main:<path>` で取り出す。
# これなら作業ツリーの状態に依存しない。
#
# ## それでも見つからないときは当て推量しない
#
# fetch してから探し、無ければ**候補を並べて中止する**。
# 「たぶんこれだろう」で別の画像を貼らない。**中身を見せずに出すのは許容できない**
# （CLAUDE.md 最上位ルール 4）。
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
OUT="${OPS_REPORT_DIR:-/tmp}/upload-draft-images-v2.md"
TMPD="${TMPDIR:-/tmp}/draft-img.$$"
CH=C0A5FKU7T5M
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

# 画像パス|スレッドts|説明
ROWS="public/images/odaiba-drone-show-2026/eyecatch.jpg|1787982139.718239|ドローン [1/2] 表紙
public/images/odaiba-drone-show-2026/photos/rainbow.jpg|1787982148.168179|ドローン [2/2] レインボーブリッジ
public/images/sauna-openings-2026/eyecatch.jpg|1787982163.602709|サウナ [1/2] 表紙
public/images/sauna-openings-2026/eyecatch.jpg|1787982170.491009|サウナ [2/2] 表紙"

mkdir -p "$TMPD"
trap 'rm -rf "$TMPD"' EXIT

{
echo "# 草案スレッドに画像を貼る（やり直し・$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> 041 は作業ツリーのファイルを見て「画像が無い」で全部飛ばした。"
echo "> **origin/main から取り出す形に直す**（028 と同じやり方）。"

echo
echo "## 1. リポジトリを最新にする"
echo
if [ ! -d "$REPO/.git" ]; then
  echo "- **\`$REPO\` が git リポジトリでない。中止。**"
  exit 1
fi
git -C "$REPO" fetch -q origin main 2>/dev/null && echo "- fetch: 成功" || echo "- fetch: **失敗**（ローカルの origin/main で続行）"
echo "- origin/main: $(git -C "$REPO" log --oneline -1 origin/main 2>/dev/null | mask)"

echo
echo "## 2. 画像を取り出す"
echo
missing=0
printf '%s\n' "$ROWS" | while IFS='|' read -r img ts label; do
  [ -n "$img" ] || continue
  dst="$TMPD/$(echo "$img" | tr '/' '_')"
  if git -C "$REPO" show "origin/main:$img" > "$dst" 2>/dev/null && [ -s "$dst" ]; then
    echo "- $label: 取り出せた（$(wc -c < "$dst" | tr -d ' ') B）"
  else
    rm -f "$dst"
    echo "- $label: **origin/main に \`$img\` が無い**"
  fi
done

# 1 枚も取れなければ、当て推量せず候補を並べて中止する
got="$(ls -1 "$TMPD" 2>/dev/null | wc -l | tr -d ' ')"
if [ "${got:-0}" = "0" ]; then
  echo
  echo "**1 枚も取り出せなかった。別の画像で代用しない。**"
  echo
  echo "origin/main にある images 配下の候補:"
  git -C "$REPO" ls-tree -r --name-only origin/main -- public/images 2>/dev/null \
    | grep -E 'eyecatch|sauna|drone|odaiba' | head -20 | sed 's/^/    /'
  exit 1
fi

echo
echo "## 3. トークン"
echo
if [ ! -f "$ENVF" ]; then
  echo "- \`~/openclaw/config/.env\` が無い。**中止。**"
  exit 1
fi
if grep -q '^OPENCLAW_BOT_TOKEN=' "$ENVF" 2>/dev/null; then
  echo "- \`OPENCLAW_BOT_TOKEN\`: **有り**（値は出さない）"
  TOKEN="$(grep '^OPENCLAW_BOT_TOKEN=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
else
  echo "- \`OPENCLAW_BOT_TOKEN\`: **無い。中止。**"
  exit 1
fi

echo
echo "## 4. アップロード"
echo
printf '%s\n' "$ROWS" | while IFS='|' read -r img ts label; do
  [ -n "$img" ] || continue
  p="$TMPD/$(echo "$img" | tr '/' '_')"
  [ -s "$p" ] || { echo "- $label: 取り出せていないので飛ばす"; continue; }
  sz="$(wc -c < "$p" | tr -d ' ')"
  fn="$(basename "$img")"

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
        -d "{\"files\":[{\"id\":\"$fid\",\"title\":\"$fn\"}],\"channel_id\":\"$CH\",\"thread_ts\":\"$ts\"}" 2>/dev/null)"
  if printf '%s' "$u3" | grep -q '"ok":true'; then
    echo "- $label: **貼れた**"
  else
    echo "- $label: **失敗** — $(printf '%s' "$u3" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p' | head -1)"
  fi
done

echo
echo "## 5. 貼れたあと"
echo
echo "- **Jordan が画像そのものを見たうえでの 👍 でなければ投稿しない**"
echo "  （CLAUDE.md 最上位ルール 4「画像確認なしの投稿は絶対に許可されない」）"
echo "- 文面だけの草案に既に付いている 👍 は、投稿の許可として扱わない"
echo "- ドローン記事のアクアシンフォニー（8/29）は**過ぎている**。Pixel Moon（9/4〜9/22）はまだ先"
} > "$OUT" 2>&1

if [ -f "$OUT" ]; then
  mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
fi
ok="$(grep -c '貼れた' "$OUT" 2>/dev/null || true)"
echo "画像 ${ok:-0} 枚を草案スレッドへ貼った / $(basename "$OUT")"
