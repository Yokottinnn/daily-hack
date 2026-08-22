#!/bin/bash
# サウナ記事の写真候補を「見て選べる」形で持ち帰る。
#
# **021 は検索結果の 1 件目を無条件に採用して失敗した。**
# hero に選ばれたのは 19 世紀の木版画「蒸し風呂に入る女性患者たち」で、
# 2026年の新店記事の表紙として題材が合わないうえ、裸体が写っている。
# 検索語が正しくても、1 件目が使える画像とは限らない。
#
# ここでは候補を縮小サムネイルにして push する。**人が見てから選ぶ。**
# 選んだあとに 023 で本採用・アイキャッチ生成を行う。
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
BRANCH="claude/sauna-photo-candidates"
WT="${TMPDIR:-/tmp}/dh-cand-$$"
OUT="${OPS_REPORT_DIR:-/tmp}/sauna-photo-candidates.md"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1

CAND="candidates"
mkdir -p "$CAND"

# 検索 → 上位 4 件を保存 → 幅 480px のサムネイルにする
collect() {
  local q="$1" tag="$2" i=0 t
  while IFS= read -r t; do
    i=$((i+1)); [ "$i" -gt 4 ] && break
    local key="${tag}-${i}"
    if "$PY" scripts/fetch-commons-photo.py --file "$t" --key "$key" --dir "$CAND" >/dev/null 2>&1; then
      "$PY" - "$CAND/$key.jpg" <<'PYX' 2>/dev/null
import sys
from PIL import Image
p = sys.argv[1]
im = Image.open(p).convert("RGB")
w, h = im.size
im = im.resize((480, max(1, int(h * 480 / w))), Image.LANCZOS)
im.save(p, quality=72)
PYX
      echo "| \`${key}.jpg\` | ${t#File:} |"
    fi
  done < <("$PY" scripts/fetch-commons-photo.py --search "$q" --limit 8 2>/dev/null | grep -o 'File:.*')
}

{
  echo "# サウナ記事の写真候補（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "**021 は検索 1 件目を無条件採用して失敗した。** ここでは候補を並べる。"
  echo "サムネイルはブランチ \`$BRANCH\` の \`candidates/\` にある。**見てから選ぶこと。**"
  echo
  for pair in \
    "Finnish sauna interior wooden|sauna" \
    "sauna stove loyly steam|stove" \
    "rotenburo open air bath Japan|rotenburo" \
    "sento public bathhouse Japan|sento" \
    "Tokyo skyline night Minato|tokyo" \
    "Yokohama Minato Mirai skyline|yokohama"; do
    q="${pair%%|*}"; tag="${pair##*|}"
    echo "## ${tag} — 検索語: \`${q}\`"
    echo
    echo "| ファイル | Commons の題名 |"
    echo "| --- | --- |"
    collect "$q" "$tag"
    echo
  done
  echo "## ライセンス台帳"
  echo
  echo '```json'
  cat "$CAND/_manifest.json" 2>/dev/null
  echo '```'
} > "$OUT"

git -C "$WT" add "$CAND"
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "wip: サウナ記事の写真候補（サムネイル・レビュー用）

021 が検索1件目を無条件採用して題材の合わない画像を選んだため、
候補を見て選べるようにした。このブランチはマージしない。" \
  || { echo "候補が 1 件も取れなかった"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" || { echo "push 失敗"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1

echo "push した: $BRANCH（candidates/ にサムネイル）"
