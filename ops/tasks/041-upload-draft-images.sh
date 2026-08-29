#!/bin/bash
# **X 告知の草案スレッドに画像を貼る。**
#
# 草案の文面は 2026-08-29 00:22 JST に Slack へ出してある。
# **画像だけが貼れていない**（クラウドセッションの Slack コネクタは添付できない）。
#
# ## なぜセッション依頼ではなくここに書くか
#
# Mac のセッションは全部 ARCHIVED か disconnected で、最後のものは
# `computer_unreachable`（2026-08-26）で落ちている。**トリガー経路が使えない。**
# `ops/tasks` は接続・認証・会話 ID のどれにも依存しないので、ここに置く
# （CLAUDE.md「機械的な操作は ops/tasks に置く。セッションに依頼しない」）。
#
# ## 秘密を出さない
#
# **結果は公開リポジトリに載る。** トークンは値を一切出さない。
#   - 参照するのは `OPENCLAW_BOT_TOKEN` の**キー名だけ**
#   - API の応答は file id と ok だけを出し、本文は捨てる
#   - 長い英数字は伏せる
#
# **読むのはローカルの画像だけ。何も書き換えない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
ENVF="$HOME/openclaw/config/.env"
OUT="${OPS_REPORT_DIR:-/tmp}/upload-draft-images.md"
CH=C0A5FKU7T5M
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

# 画像:スレッドts:説明
ROWS="public/images/odaiba-drone-show-2026/eyecatch.jpg|1787982139.718239|ドローン [1/2] 表紙
public/images/odaiba-drone-show-2026/photos/rainbow.jpg|1787982148.168179|ドローン [2/2] レインボーブリッジ
public/images/sauna-openings-2026/eyecatch.jpg|1787982163.602709|サウナ [1/2] 表紙
public/images/sauna-openings-2026/eyecatch.jpg|1787982170.491009|サウナ [2/2] 表紙"

{
echo "# 草案スレッドに画像を貼る（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **文面は投稿済み。画像だけが貼れていない。**"
echo "> 👍 をもらうまで X には出さない（CLAUDE.md 最上位ルール 4）。"

echo
echo "## 1. トークン"
echo
if [ ! -f "$ENVF" ]; then
  echo "- \`~/openclaw/config/.env\` が無い。**中止。**"
  exit 1
fi
# 値は絶対に出さない。存在の有無だけ
if grep -q '^OPENCLAW_BOT_TOKEN=' "$ENVF" 2>/dev/null; then
  echo "- \`OPENCLAW_BOT_TOKEN\`: **有り**（値は出さない）"
  TOKEN="$(grep '^OPENCLAW_BOT_TOKEN=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
else
  echo "- \`OPENCLAW_BOT_TOKEN\`: **無い。中止。**"
  exit 1
fi

echo
echo "## 2. 貼る画像"
echo
printf '%s\n' "$ROWS" | while IFS='|' read -r img ts label; do
  [ -n "$img" ] || continue
  p="$REPO/$img"
  if [ -f "$p" ]; then
    echo "- $label: $(basename "$img")（$(wc -c < "$p" | tr -d ' ') B）"
  else
    echo "- $label: **$img が無い**"
  fi
done

echo
echo "## 3. アップロード"
echo
printf '%s\n' "$ROWS" | while IFS='|' read -r img ts label; do
  [ -n "$img" ] || continue
  p="$REPO/$img"
  [ -f "$p" ] || { echo "- $label: 画像が無いので飛ばす"; continue; }
  sz="$(wc -c < "$p" | tr -d ' ')"
  fn="$(basename "$img")"

  # v2 の 3 段階（files.upload は廃止予定のため）
  #   1) アップロード先の URL をもらう
  #   2) その URL へ本体を POST
  #   3) チャンネル・スレッドへ紐づけて完了
  u1="$(curl -sS -X GET "https://slack.com/api/files.getUploadURLExternal" \
        -H "Authorization: Bearer $TOKEN" \
        --data-urlencode "filename=$fn" --data-urlencode "length=$sz" -G 2>/dev/null)"
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
echo "## 4. 次にすること"
echo
echo "- Jordan が両スレッドに 👍 を付けたら、OpenClaw が X へ投稿する"
echo "- **👍 の前に X へは出さない**"
echo "- ドローン記事は **8/29 19:00／21:00 のアクアシンフォニー**が直近なので急ぎ"
} > "$OUT" 2>&1

# 念のため、レポートにトークンらしき文字列が残っていないか通す
if [ -f "$OUT" ]; then
  mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
fi
ok="$(grep -c '貼れた' "$OUT" 2>/dev/null || true)"
echo "画像 ${ok:-0} 枚を草案スレッドへ貼った / $(basename "$OUT")"
