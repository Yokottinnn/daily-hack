#!/bin/bash
# アイキャッチの文字が記事と食い違っているので作り直す。
#
# 記事は「首都圏15施設」に絞ったのに、アイキャッチは「主要20施設」のままだった。
# 公開ページを実際に描画して見て気づいた。**画像の文字も記事の一部**なので、
# 対象を変えたら必ず作り直す。
#
# ついでに、event-pick を 4 枚から 6 枚に戻すための写真候補も取る（幕張・小田原）。
# 候補はサムネイルで push するだけ。**採用は見てから決める。**
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SLUG="sauna-openings-2026"
BRANCH="claude/sauna-eyecatch-15"
WT="${TMPDIR:-/tmp}/dh-ec15-$$"
OUT="${OPS_REPORT_DIR:-/tmp}/sauna-eyecatch-15.md"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }
[ -f "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" ] || { echo "ヒラギノが無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1

DIR="public/images/$SLUG/photos"
[ -f "$DIR/sauna-room.jpg" ] || { echo "背景 $DIR/sauna-room.jpg が無い"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

# --- アイキャッチを作り直す（文言を記事に合わせる） ---
"$PY" scripts/gen-photo-hero.py \
  "$DIR/sauna-room.jpg" "public/images/$SLUG/eyecatch.jpg" \
  "2026年オープン" "サウナ新店" "首都圏15施設" \
  "料金・最寄駅・男女別で全部並べた" \
  "背景: Jorge Royan / Wikimedia Commons CC BY-SA 3.0" > "$OUT" 2>&1

[ -f "public/images/$SLUG/eyecatch.jpg" ] || {
  echo "アイキャッチ生成に失敗" | tee -a "$OUT"
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

# --- カードを 6 枚に戻すための候補（採用は後で人が決める） ---
CAND="candidates"
mkdir -p "$CAND"
pick() {
  local q="$1" tag="$2" i=0 t
  while IFS= read -r t; do
    i=$((i+1)); [ "$i" -gt 4 ] && break
    local key="${tag}-${i}"
    if "$PY" scripts/fetch-commons-photo.py --file "$t" --key "$key" --dir "$CAND" >/dev/null 2>&1; then
      "$PY" - "$CAND/$key.jpg" <<'PYX' 2>/dev/null
import sys
from PIL import Image
p = sys.argv[1]
im = Image.open(p).convert("RGB"); w, h = im.size
im.resize((480, max(1, int(h * 480 / w))), Image.LANCZOS).save(p, quality=72)
PYX
      echo "| \`${key}.jpg\` | ${t#File:} |"
    fi
  done < <("$PY" scripts/fetch-commons-photo.py --search "$q" --limit 8 2>/dev/null | grep -o 'File:.*')
}

{
  echo
  echo "# アイキャッチ作り直し（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "文言を「主要20施設」→「首都圏15施設」に変更。**Read で開いて確認すること。**"
  echo
  echo "## カードを 6 枚に戻すための候補"
  echo
  echo "| ファイル | Commons の題名 |"
  echo "| --- | --- |"
  pick "Makuhari Chiba cityscape" makuhari
  pick "Odawara Castle Kanagawa"  odawara
  echo
  echo "## ライセンス台帳（候補）"
  echo '```json'
  cat "$CAND/_manifest.json" 2>/dev/null
  echo '```'
} >> "$OUT"

git -C "$WT" add "public/images/$SLUG" "$CAND"
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "assets: アイキャッチの文言を首都圏15施設に合わせる

記事は首都圏15施設に絞ったのに、アイキャッチは主要20施設のままだった。
candidates/ は event-pick を 6 枚に戻すための候補（レビュー用・採用は別途）。" \
  || { echo "コミットするものが無い"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" || { echo "push 失敗"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "push した: $BRANCH（eyecatch 作り直し + カード候補）"
