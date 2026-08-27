#!/bin/bash
# お台場ドローンショー記事の背景写真を Wikimedia Commons から取る。
#
# 公式の写真は 037 が取りに行く。こちらは
# 「会場・周辺・夜景」として使える再利用可の写真を台帳つきで確保する。
# **候補をサムネイルにして push するところまで。採用はセッション側で目で見て決める。**
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SLUG="odaiba-drone-show-2026"
BRANCH="claude/odaiba-commons"
WT="${TMPDIR:-/tmp}/dh-odcom-$$"
OUT="${OPS_REPORT_DIR:-/tmp}/odaiba-commons.md"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1

DIR="public/images/$SLUG/photos"
mkdir -p "$DIR"

{
  echo "# お台場ドローンショー記事の背景写真（Commons）"
  echo
  echo "## 検索の結果（採用はしていない。題名を見て選ぶ）"
  echo
  for q in "drone light show night" "Odaiba Kaihinkoen Park" "Daiba Park Tokyo" \
           "Rainbow Bridge night Tokyo" "Tokyo Tower night from Odaiba" "Yurikamome Odaiba"; do
    echo "### \`$q\`"
    echo
    echo '```'
    "$PY" scripts/fetch-commons-photo.py --search "$q" --limit 8 2>&1 | head -30
    echo '```'
    echo
  done

  echo "## 保存した写真"
  save() {
    if "$PY" scripts/fetch-commons-photo.py --file "$1" --key "$2" --dir "$DIR" >/dev/null 2>&1; then
      echo "- \`$2\`: OK（$1）"
    else
      echo "- \`$2\`: **失敗**（$1）"
    fi
  }
  save "File:Rainbow Bridge (Summer) - panoramio.jpg" "rainbow"
  save "File:Tokyo bay fireworks 2015.jpg" "hanabi"
  save "File:Minato City, Tokyo, Japan (Night)-denoised.jpg" "tokyo-night"
  echo
  echo "台帳:"
  echo '```json'
  cat "$DIR/_manifest.json" 2>/dev/null || echo "（_manifest.json なし）"
  echo '```'
} > "$OUT"

git -C "$WT" add -A "$DIR" 2>/dev/null
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "wip: お台場ドローンショー記事の背景写真（レビュー用）" 2>/dev/null || true
git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" 2>/dev/null || true
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/odaiba-commons.md / branch $BRANCH"
