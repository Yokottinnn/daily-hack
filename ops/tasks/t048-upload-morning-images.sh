#!/bin/bash
# **モーニング記事の草案スレッドに画像を実物で貼る。費用 $0。**
#
# ## なぜ必要か
#
# **クラウドセッションの Slack コネクタは添付できない。**
# ファイルパスを書くだけでは「画像を出した」ことにならない。
#
#   > 画像確認なしに投稿は絶対に許可しないので、覚えておいて
#   （CLAUDE.md 最上位ルール 4）
#
# **Jordan が画像そのものを見たうえでの 👍 でなければ投稿できない。**
#
# ## 画像は origin/main から取る
#
# 作業ツリーではなく `git show origin/main:<path>`。
# Mac のチェックアウトが最新とは限らない（041 がこれで全部 飛ばした）。
#
# ## 見つからなければ当て推量しない
#
# fetch してから探し、無ければ**候補を並べて中止する**。
# 「たぶんこれだろう」で別の画像を貼らない。
#
# ## 秘密を出さない
#
# **結果は公開リポジトリに載る。** `OPENCLAW_BOT_TOKEN` はキー名だけ。
#
# **LLM を呼ばない（費用 $0）。投稿はしない。**
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
ENVF="$HOME/openclaw/config/.env"
OUT="${OPS_REPORT_DIR:-/tmp}/upload-morning-images.md"
TMPD="${TMPDIR:-/tmp}/morning-img.$$"
CH=C0A5FKU7T5M
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

# 画像パス|スレッドts|説明
ROWS="public/images/morning-500-2026/x/1-summary.jpg|1788605877.166169|モーニング [1/4] 安い順トップ6
public/images/morning-500-2026/x/2-matsuya.jpg|1788605884.387209|モーニング [2/4] 松屋 350円
public/images/morning-500-2026/x/3-komeda.jpg|1788605892.428359|モーニング [3/4] コメダ
public/images/morning-500-2026/x/4-sukiya.jpg|1788605900.452319|モーニング [4/4] すき家 朝4:00"

mkdir -p "$TMPD"
trap 'rm -rf "$TMPD"' EXIT

{
echo "# モーニング記事の草案に画像を貼る（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **画像確認なしの投稿は絶対に許可されない**（CLAUDE.md 最上位ルール 4）。"
echo "> スレッドに実物を貼って、そのうえで 👍 をもらう。"

echo
echo "## 1. リポジトリを最新にする"
echo
[ -d "$REPO/.git" ] || { echo "- **\`$REPO\` が git リポジトリでない。中止。**"; exit 1; }
git -C "$REPO" fetch -q origin main 2>/dev/null && echo "- fetch: 成功" || echo "- fetch: **失敗**（ローカルの origin/main で続行）"
echo "- origin/main: $(git -C "$REPO" log --oneline -1 origin/main 2>/dev/null | mask)"

echo
echo "## 2. 画像を取り出す（origin/main から）"
echo
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

got="$(ls -1 "$TMPD" 2>/dev/null | wc -l | tr -d ' ')"
if [ "${got:-0}" != "4" ]; then
  echo
  echo "**4 枚そろわなかった（${got:-0} 枚）。別の画像で代用しない。中止。**"
  echo
  echo "origin/main にある morning-500-2026 配下:"
  git -C "$REPO" ls-tree -r --name-only origin/main -- public/images/morning-500-2026 2>/dev/null | head -20 | sed 's/^/    /'
  exit 1
fi

echo
echo "## 3. トークン"
echo
[ -f "$ENVF" ] || { echo "- \`~/openclaw/config/.env\` が無い。**中止。**"; exit 1; }
if grep -q '^OPENCLAW_BOT_TOKEN=' "$ENVF" 2>/dev/null; then
  echo "- \`OPENCLAW_BOT_TOKEN\`: **有り**（値は出さない）"
  TOKEN="$(grep '^OPENCLAW_BOT_TOKEN=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
else
  echo "- \`OPENCLAW_BOT_TOKEN\`: **無い。中止。**"; exit 1
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
echo "---"
echo
echo "**投稿はしていない。** Jordan が画像そのものを見たうえでの 👍 が要る"
echo "（CLAUDE.md 最上位ルール 4「画像確認なしの投稿は絶対に許可されない」）。"
echo "**LLM を呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '貼れた' "$OUT" 2>/dev/null; then echo "**草案に画像を貼った（投稿なし・\$0）** / $(basename "$OUT")"
else echo "**画像を貼れなかった** / $(basename "$OUT")"; fi
