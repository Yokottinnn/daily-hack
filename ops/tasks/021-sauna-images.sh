#!/bin/bash
# サウナ記事（sauna-openings-2026）の画像一式を Mac で作る。
#
# **クラウドセッションでは作れない。** 日本語フォントが無く（Noto Color Emoji のみ）、
# Commons にも到達できない（egress が塞がれている。2026-08-22 実測）。
# gen-photo-hero.py は macOS のヒラギノを直接参照している。
#
# やること: Commons から CC 写真を取る → 1600x900 のアイキャッチを作る →
#           ブランチ claude/sauna-eyecatch に push する。
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SLUG="sauna-openings-2026"
BRANCH="claude/sauna-eyecatch"
WT="${TMPDIR:-/tmp}/dh-eyecatch-$$"
OUT="${OPS_REPORT_DIR:-/tmp}/sauna-images.md"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }

PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do
  [ -x "$c" ] && { PY="$c"; break; }
done
[ -n "$PY" ] || { echo "python3.11 が無い（Pillow が要る）"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が入っていない: $PY"; exit 1; }
[ -f "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" ] || { echo "ヒラギノが無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 作成に失敗"; exit 1; }

cd "$WT" || exit 1
DIR="public/images/$SLUG/photos"
mkdir -p "$DIR"

# 検索結果の 1 件目を採用する。File: 以降が題名。
pick() {
  local q="$1" key="$2" t
  t="$("$PY" scripts/fetch-commons-photo.py --search "$q" --limit 6 2>/dev/null | grep -o 'File:.*' | head -1)"
  if [ -z "$t" ]; then echo "  - ${key}: 候補なし（${q}）"; return 1; fi
  if "$PY" scripts/fetch-commons-photo.py --file "$t" --key "$key" --dir "$DIR" >/dev/null 2>&1; then
    echo "  - ${key}: ${t}"
  else
    echo "  - ${key}: 保存に失敗（${t}）"; return 1
  fi
}

{
  echo "# サウナ記事の画像生成（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "## 取得した写真"
  pick "sauna interior wood"        hero
  pick "Japanese sento bathhouse"   sento
  pick "onsen open air bath"        rotenburo
  pick "Tokyo skyline night"        tokyo
  pick "Nagoya station"             nagoya
  pick "Hakata Fukuoka station"     hakata
  pick "Yokohama minato mirai"      yokohama
  echo
} > "$OUT"

if [ ! -f "$DIR/hero.jpg" ]; then
  echo "## アイキャッチ" >> "$OUT"
  echo "hero.jpg が取れなかったため中止した。" >> "$OUT"
  echo "hero 写真が取れず中止"
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
  exit 1
fi

"$PY" scripts/gen-photo-hero.py \
  "$DIR/hero.jpg" "public/images/$SLUG/eyecatch.jpg" \
  "2026年オープン" "サウナ新店" "主要20施設" \
  "料金・最寄駅・男女別で全部並べた" \
  "背景: Wikimedia Commons" >> "$OUT" 2>&1

if [ ! -f "public/images/$SLUG/eyecatch.jpg" ]; then
  echo "アイキャッチ生成に失敗"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1
fi

{
  echo "## アイキャッチ"
  echo
  echo "\`public/images/$SLUG/eyecatch.jpg\` を生成した（$(wc -c < "public/images/$SLUG/eyecatch.jpg" | tr -d ' ') bytes）。"
  echo
  echo "## ライセンス台帳"
  echo
  echo '```json'
  cat "$DIR/_manifest.json" 2>/dev/null
  echo '```'
} >> "$OUT"

git -C "$WT" add "public/images/$SLUG"
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "assets: サウナ記事のアイキャッチと写真を追加する

クラウドセッションには日本語フォントも Commons への到達性も無いため、
ops/tasks 経由で Mac の gen-photo-hero.py とヒラギノで生成した。
写真は Wikimedia Commons の再利用可ライセンスのみ。_manifest.json に台帳あり。" \
  || { echo "コミットするものが無い"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" || { echo "push に失敗"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1

echo "push した: $BRANCH（eyecatch + photos）"
