#!/bin/bash
# **Mac のクローンを main に追いつかせる。**
#
# t080 の実測: **186 コミット 遅れ。HEAD は 2026-08-30。**
#
#     HEAD        ade78a1 2026-08-30 22:54:06
#     origin/main e486831 2026-09-15 01:55:08
#     遅れ        186 コミット
#
# これが t067（weekly-blog-report.py が無い）の真因でもある。**リポジトリの
# ファイルに依存する ops タスクは、いまも全部この影響を受ける。**
#
# ## 安全側に倒す
#
# **`git reset --hard` はしない。** 未コミットの変更やローカルのコミットが
# あるかもしれない。`--ff-only` でしか進めず、進めないなら**理由を書いて止まる。**
# （最上位ルール 3: git checkout -B は未マージのコミットを捨てる）
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t081-pull-mac-clone.md"
mkdir -p "$RDIR"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"

{
  echo "# Mac のクローンを main に追いつかせる（t081）"
  echo
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo
} > "$OUT"

if [ ! -d "$REPO/.git" ]; then
  echo "⚠️ \`$REPO\` が git リポジトリとして見つからない。何もしていない。" >> "$OUT"
  cat "$OUT"; exit 1
fi

before="$(git -C "$REPO" log -1 --format='%h %ci' 2>/dev/null)"
branch="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)"
dirty="$(git -C "$REPO" status --porcelain 2>/dev/null | head -20)"
ahead="$(git -C "$REPO" rev-list --count origin/main..HEAD 2>/dev/null || echo '?')"

{
  echo "## 着手前"
  echo
  echo "| 項目 | 値 |"
  echo "| --- | --- |"
  echo "| ブランチ | \`$branch\` |"
  echo "| HEAD | \`$before\` |"
  echo "| main より先にあるコミット | **$ahead 本** |"
  echo
} >> "$OUT"

if [ -n "$dirty" ]; then
  {
    echo "### ⚠️ 未コミットの変更がある。**止まる。**"
    echo
    echo '```'
    echo "$dirty"
    echo '```'
    echo
    echo "手で確認してから、もう一度 タスクを出す。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi

if [ "$ahead" != "0" ] && [ "$ahead" != "?" ]; then
  {
    echo "### ⚠️ main に無いコミットが **$ahead 本** ある。**止まる。**"
    echo
    echo '```'
    git -C "$REPO" log --oneline origin/main..HEAD 2>/dev/null | head -20
    echo '```'
    echo
    echo "**捨ててよいか分からないので触らない。** 手で確認すること。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi

t0=$(date +%s)
fetch_out="$(git -C "$REPO" fetch origin main 2>&1 | tail -5)"
merge_out="$(git -C "$REPO" merge --ff-only origin/main 2>&1 | tail -5)"
rc=$?
t1=$(date +%s)

after="$(git -C "$REPO" log -1 --format='%h %ci' 2>/dev/null)"
behind="$(git -C "$REPO" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"

{
  echo "## 実行した"
  echo
  echo '```'
  echo "$fetch_out"
  echo "$merge_out"
  echo '```'
  echo
  echo "所要 **$((t1 - t0)) 秒**"
  echo
  echo "## 着手後（**ここが証拠**）"
  echo
  echo "| 項目 | 値 |"
  echo "| --- | --- |"
  echo "| HEAD | \`$after\` |"
  echo "| main に対して遅れ | **$behind コミット** |"
  echo
  # **rc=0 は証拠にならない（最上位ルール 13）。** 状態を別の口で見る。
  if [ "$behind" = "0" ]; then
    echo "✅ **追いついた。**"
  else
    echo "🚨 **まだ $behind コミット 遅れている。** merge の rc=$rc"
  fi
  echo
  echo "### リポジトリのファイルが来ているか"
  echo
  for f in scripts/weekly-blog-report.py scripts/check-article-ux.py docs/article-ux-baseline.json; do
    if [ -f "$REPO/$f" ]; then
      echo "- \`$f\` **ある**（$(wc -l < "$REPO/$f" | tr -d ' ') 行）"
    else
      echo "- \`$f\` **無い**"
    fi
  done
} >> "$OUT"

cat "$OUT"
exit 0
