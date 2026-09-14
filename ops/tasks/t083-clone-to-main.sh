#!/bin/bash
# **Mac のクローンを main に戻す。**（t081 の続き）
#
# ## t081 が止まった理由と、そこで分かったこと
#
#     ブランチ  ops/t006-sauna-thread-v3   ← **main ではない**
#     HEAD      ade78a1 2026-08-30 22:54:06
#     未追跡    docs/session-logs/ drafts/ ops/tasks/t006-post-sauna-thread.sh scripts/__pycache__/
#
# **クローンは 2026-08-30 に作業ブランチへ切り替えたまま、2 週間 放置されていた。**
# これが t067（weekly-blog-report.py が無い）と t082（コピー元が無い）の真因。
# リポジトリのファイルに依存する ops タスクは、全部この影響を受けている。
#
# ## 失うものが無いことを先に確かめてある
#
# `ade78a1` は **origin にも同じ SHA で上がっている**（`refs/heads/ops/t006-sauna-thread-v3`）。
# Mac だけにあるコミットではないので、main に切り替えても消えるものは無い。
# **それでもタスクの中でもう一度 確かめる**（クラウドで見た＝Mac で見た、ではない・ルール 14）。
#
# ## 触らないもの
#
# - **未追跡ファイルは消さない。** `git clean` は打たない
# - main に同名のファイルが無いことは確認済みなので、checkout で衝突しない
# - **`git checkout -B` は使わない**（最上位ルール 3。未マージのコミットを捨てる）
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t083-clone-to-main.md"
mkdir -p "$RDIR"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"

{
  echo "# Mac のクローンを main に戻す（t083）"
  echo
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo
} > "$OUT"

if [ ! -d "$REPO/.git" ]; then
  echo "⚠️ \`$REPO\` が git リポジトリとして見つからない。何もしていない。" >> "$OUT"
  cat "$OUT"; exit 1
fi

cd "$REPO" || { echo "cd できない" >> "$OUT"; cat "$OUT"; exit 1; }

branch0="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
head0="$(git rev-parse HEAD 2>/dev/null)"
git fetch -q origin main 2>/dev/null
git fetch -q origin "$branch0" 2>/dev/null || true

{
  echo "## 着手前"
  echo
  echo "| 項目 | 値 |"
  echo "| --- | --- |"
  echo "| ブランチ | \`$branch0\` |"
  echo "| HEAD | \`$(git log -1 --format='%h %ci %s' | cut -c1-80)\` |"
  echo
  echo "### いまの HEAD が origin にも在るか（**ここが安全確認**）"
  echo
} >> "$OUT"

remote_sha="$(git ls-remote --heads origin "$branch0" 2>/dev/null | awk '{print $1}')"
if [ "$remote_sha" = "$head0" ]; then
  echo "✅ \`origin/$branch0\` が **同じ SHA**（\`${head0:0:7}\`）。切り替えても失うものは無い。" >> "$OUT"
elif [ -n "$remote_sha" ]; then
  {
    echo "🚨 **origin の \`$branch0\` は \`${remote_sha:0:7}\` で、HEAD \`${head0:0:7}\` と違う。**"
    echo
    echo "origin に無いコミット:"
    echo '```'
    git log --oneline "origin/$branch0..HEAD" 2>/dev/null | head -20
    echo '```'
    echo
    echo "**失う可能性があるので何もしない。** 手で確認すること。"
  } >> "$OUT"
  cat "$OUT"; exit 0
else
  {
    echo "🚨 **\`$branch0\` が origin に無い。このクローンにしか無いコミットがある。**"
    echo
    echo '```'
    git log --oneline -5
    echo '```'
    echo
    echo "**失う可能性があるので何もしない。** 先に push するか、手で確認すること。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi

# 未追跡ファイルは残す。**git clean は打たない。**
{
  echo
  echo "### 残す未追跡ファイル（消さない）"
  echo
  echo '```'
  git status --porcelain | grep '^??' | head -20
  echo '```'
  echo
} >> "$OUT"

sw_out="$(git checkout main 2>&1 | tail -5)"
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  sw_out="$sw_out
$(git checkout -b main --track origin/main 2>&1 | tail -5)"
fi
mg_out="$(git merge --ff-only origin/main 2>&1 | tail -5)"

branch1="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
behind="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"

{
  echo "## 実行した"
  echo
  echo '```'
  echo "$sw_out"
  echo "$mg_out"
  echo '```'
  echo
  echo "## 着手後（**ここが証拠・ルール 13**）"
  echo
  echo "| 項目 | 値 |"
  echo "| --- | --- |"
  echo "| ブランチ | **\`$branch1\`** |"
  echo "| HEAD | \`$(git log -1 --format='%h %ci' | cut -c1-40)\` |"
  echo "| main に対して遅れ | **$behind コミット** |"
  echo
  if [ "$branch1" = "main" ] && [ "$behind" = "0" ]; then
    echo "✅ **main の最新に戻った。**"
  else
    echo "🚨 **戻れていない。** ブランチ=\`$branch1\` / 遅れ=$behind"
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
  echo
  echo "### 未追跡ファイルが残っているか"
  echo
  echo '```'
  git status --porcelain | grep '^??' | head -20
  echo '```'
} >> "$OUT"

cat "$OUT"
exit 0
