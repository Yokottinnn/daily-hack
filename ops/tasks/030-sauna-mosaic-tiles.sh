#!/bin/bash
# 利用者が置いた施設写真をタイル合成してアイキャッチにする。
#
# **チャットに貼られた画像はクラウド側でファイルにできない。**
# トランスクリプトに画像データが残らないため、bytes を取り出す手段が無い（2026-08-27 実測）。
# そこで Mac の決まったフォルダを見に行く。
#
#   ~/Downloads/sauna-tiles/   ← ここに 6 枚置く（名前順にタイルへ入る）
#
# 3x2 のタイルに敷いてタイトルを載せる（scripts/gen-mosaic-hero.py）。
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SLUG="sauna-openings-2026"
BRANCH="claude/sauna-mosaic-eyecatch"
WT="${TMPDIR:-/tmp}/dh-mosaic-$$"
OUT="${OPS_REPORT_DIR:-/tmp}/sauna-mosaic.md"

SRC=""
for d in "$HOME/Downloads/sauna-tiles" "$HOME/Desktop/sauna-tiles" "$HOME/sauna-tiles"; do
  [ -d "$d" ] && { SRC="$d"; break; }
done
if [ -z "$SRC" ]; then
  echo "置き場が無い。~/Downloads/sauna-tiles/ を作って画像を入れること"
  exit 1
fi

# 名前順に最大 6 枚
FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(find "$SRC" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort | head -6)
if [ "${#FILES[@]}" -lt 6 ]; then
  echo "画像が ${#FILES[@]} 枚しかない（6 枚必要）: ${SRC/#$HOME/~}"
  exit 1
fi

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }
[ -f "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" ] || { echo "ヒラギノが無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1

# webp が混ざっても Pillow で読めるよう jpg に寄せる
TMPD="${TMPDIR:-/tmp}/mosaic-src-$$"; mkdir -p "$TMPD"
CONV=()
i=0
for f in "${FILES[@]}"; do
  i=$((i+1))
  dst="$TMPD/tile-$i.jpg"
  "$PY" - "$f" "$dst" <<'PYX' 2>/dev/null || { echo "変換に失敗: $(basename "$f")"; continue; }
import sys
from PIL import Image
Image.open(sys.argv[1]).convert("RGB").save(sys.argv[2], quality=92)
PYX
  [ -f "$dst" ] && CONV+=("$dst")
done
[ "${#CONV[@]}" -ge 6 ] || { echo "読める画像が ${#CONV[@]} 枚しかない"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

"$PY" scripts/gen-mosaic-hero.py \
  "public/images/$SLUG/eyecatch.jpg" \
  "2026年オープン" "サウナ新店" "首都圏15施設" \
  "料金・最寄駅・男女別で全部並べた" \
  "画像: 各施設公式サイト" \
  "${CONV[@]:0:6}" > "$OUT" 2>&1

[ -f "public/images/$SLUG/eyecatch.jpg" ] || {
  echo "合成に失敗" | tee -a "$OUT"
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

{
  echo
  echo "# タイル合成アイキャッチ（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "置き場: \`${SRC/#$HOME/~}\`"
  echo
  echo "## 使った画像（名前順・左上から右下へ）"
  echo
  n=0
  for f in "${FILES[@]:0:6}"; do n=$((n+1)); echo "${n}. \`$(basename "$f")\`"; done
  echo
  echo "**必ず Read で開いて、タイルの並びと文字の重なりを確認すること。**"
} >> "$OUT"

git -C "$WT" add "public/images/$SLUG/eyecatch.jpg"
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "assets: アイキャッチを施設写真 6 枚のタイル合成にする

利用者が ~/Downloads/sauna-tiles/ に置いた施設写真を 3x2 で合成した。
クレジットは「画像: 各施設公式サイト」。" \
  || { echo "コミットするものが無い"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" || { echo "push 失敗"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
rm -rf "$TMPD"
echo "push した: $BRANCH（施設写真 6 枚のタイル合成）"
