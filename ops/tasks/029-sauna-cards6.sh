#!/bin/bash
# event-pick を 6 枚に戻すための写真 2 枚を本採用する。
#
# 028 が持ち帰った候補 7 枚を 1 枚ずつ確認した結果:
#   採用 makuhari-1（海浜幕張の夜景）／ odawara-4（小田原城の門と堀）
#   不採用 odawara-1〜3（庭園・360度パノラマで場所が伝わらない）
#          makuhari-2/3（1 とほぼ同じ／県のフォトモンタージュ）
#
# ここでは検索をしない。**題名を決め打ちで指定する。**
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SLUG="sauna-openings-2026"
BRANCH="claude/sauna-cards6"
WT="${TMPDIR:-/tmp}/dh-c6-$$"
OUT="${OPS_REPORT_DIR:-/tmp}/sauna-cards6.md"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1

DIR="public/images/$SLUG/photos"
mkdir -p "$DIR"

save() {
  if "$PY" scripts/fetch-commons-photo.py --file "$1" --key "$2" --dir "$DIR" >/dev/null 2>&1; then
    echo "  - ${2}: OK"
  else
    echo "  - ${2}: 失敗（$1）"; return 1
  fi
}

{
  echo "# カード用の写真 2 枚を本採用（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  save "File:Chiba-KaihinMakuhari - panoramio.jpg" "makuhari"
  save "File:Odawara Castle 20211201.jpg"          "odawara"
  echo
  echo "## ライセンス台帳"
  echo '```json'
  cat "$DIR/_manifest.json" 2>/dev/null
  echo '```'
} > "$OUT"

if [ ! -f "$DIR/makuhari.jpg" ] || [ ! -f "$DIR/odawara.jpg" ]; then
  echo "2 枚そろわなかったため中止" | tee -a "$OUT"
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1
fi

git -C "$WT" add "$DIR"
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "assets: カード用に幕張と小田原の写真を追加する

028 が持ち帰った候補 7 枚を 1 枚ずつ確認し、場所が伝わる 2 枚だけを採った。
event-pick を 4 枚から 6 枚（3 列 × 2 段）に戻すために使う。" \
  || { echo "コミットするものが無い"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" || { echo "push 失敗"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "push した: $BRANCH（makuhari + odawara）"
