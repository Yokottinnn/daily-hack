#!/bin/bash
# サウナ記事の画像を本採用する。**候補を 1 枚ずつ見て選んだ結果**を確定させる。
#
# 022 / 023 が持ち帰った 35 枚をすべて Read で確認し、
# 「現代の実写・人物が主題でない・横長」を満たす 6 枚だけを採る。
# ここでは検索をしない。**題名を決め打ちで指定する。**
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SLUG="sauna-openings-2026"
BRANCH="claude/sauna-images-final"
WT="${TMPDIR:-/tmp}/dh-final-$$"
OUT="${OPS_REPORT_DIR:-/tmp}/sauna-final-images.md"

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
mkdir -p "$DIR"

save() { # $1=File:題名  $2=key
  if "$PY" scripts/fetch-commons-photo.py --file "$1" --key "$2" --dir "$DIR" >/dev/null 2>&1; then
    echo "  - ${2}: OK"
  else
    echo "  - ${2}: 失敗（$1）"; return 1
  fi
}

{
  echo "# サウナ記事の画像 本採用（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "## 保存した写真（すべて実写・人物が主題でない・横長）"
  save "File:Munich - Sauna in Bath House - 8470.jpg" "sauna-room"
  save "File:Japanese communal bathhouse SENTO Sentō 銭湯の浴室.jpg" "sento"
  save "File:Minato City, Tokyo, Japan (Night)-denoised.jpg" "tokyo"
  save "File:Minato Mirai - Yokohama Skyline March 2025.jpg" "yokohama"
  save "File:Nagoya Lucent Tower and JR Central Towers from west.jpg" "nagoya"
  save "File:Nakasu02.jpg" "fukuoka"
  echo
} > "$OUT"

if [ ! -f "$DIR/sauna-room.jpg" ]; then
  echo "sauna-room が取れなかったため中止" | tee -a "$OUT"
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1
fi

"$PY" scripts/gen-photo-hero.py \
  "$DIR/sauna-room.jpg" "public/images/$SLUG/eyecatch.jpg" \
  "2026年オープン" "サウナ新店" "主要20施設" \
  "料金・最寄駅・男女別で全部並べた" \
  "背景: Jorge Royan / Wikimedia Commons CC BY-SA 3.0" >> "$OUT" 2>&1

[ -f "public/images/$SLUG/eyecatch.jpg" ] || {
  echo "アイキャッチ生成に失敗" | tee -a "$OUT"
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

{
  echo "## アイキャッチ"
  echo
  echo "\`public/images/$SLUG/eyecatch.jpg\`（$(wc -c < "public/images/$SLUG/eyecatch.jpg" | tr -d ' ') bytes）"
  echo "**必ず Read で開いて題材を確認すること。**"
  echo
  echo "## ライセンス台帳"
  echo
  echo '```json'
  cat "$DIR/_manifest.json" 2>/dev/null
  echo '```'
} >> "$OUT"

git -C "$WT" add "public/images/$SLUG"
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "assets: サウナ記事の写真6枚とアイキャッチを追加する

022/023 が持ち帰った候補 35 枚を 1 枚ずつ確認し、現代の実写・人物が主題でない・
横長という条件を満たす 6 枚だけを採用した。アイキャッチの背景は
Munich - Sauna in Bath House（実写のサウナ室・無人）。" \
  || { echo "コミットするものが無い"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" || { echo "push 失敗"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "push した: $BRANCH（photos 6枚 + eyecatch）"
