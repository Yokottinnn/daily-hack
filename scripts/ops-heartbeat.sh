#!/bin/bash
# Mac 側の死活を GitHub に押し出す heartbeat
#
#   bash scripts/ops-heartbeat.sh
#
# 30分ごとに launchd から実行する想定。稼働中ジョブの一覧と時刻を
# ops/heartbeat ブランチに push するだけ。
#
# なぜ「押す」側なのか:
#   監視を Mac 側に置くと、Mac が死んだとき監視も一緒に死ぬ。実際 2026-08-10 に
#   Chrome の自動更新で全ジョブが停止したが、異常を検知する pipeline-heartbeat も
#   同じ Mac で止まっており、5日間 誰も気づかなかった。
#   そこで「来なくなったこと」を GitHub Actions 側で検知する形にする。
#   Mac が丸ごと落ちても、押されなくなること自体が異常の証拠になる。
#
# 作業ツリーは触らない。専用の worktree を使うため、Mac 上で進行中の作業と衝突しない。

set -uo pipefail

MAIN_REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${OPS_HEARTBEAT_WORKTREE:-$HOME/.openclaw/ops-heartbeat-wt}"
BRANCH="${OPS_HEARTBEAT_BRANCH:-ops/heartbeat}"

die() { echo "ops-heartbeat: $1" >&2; exit 1; }

[ -d "$MAIN_REPO/.git" ] || die "リポジトリが見つからない: $MAIN_REPO"

# --- worktree を用意する（初回のみ） -------------------------------------

git -C "$MAIN_REPO" fetch -q origin "$BRANCH" 2>/dev/null || true

if [ ! -e "$WT/.git" ]; then
  mkdir -p "$(dirname "$WT")"
  if git -C "$MAIN_REPO" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    git -C "$MAIN_REPO" worktree add -f "$WT" -B "$BRANCH" "origin/$BRANCH" >/dev/null \
      || die "worktree の作成に失敗した"
  else
    # ブランチが無い初回。履歴を持たない orphan として作る。
    git -C "$MAIN_REPO" worktree add -f --detach "$WT" >/dev/null || die "worktree の作成に失敗した"
    git -C "$WT" checkout -q --orphan "$BRANCH" || die "orphan ブランチの作成に失敗した"
    git -C "$WT" rm -rqf . >/dev/null 2>&1 || true
  fi
else
  git -C "$WT" fetch -q origin "$BRANCH" 2>/dev/null || true
  git -C "$WT" reset -q --hard "origin/$BRANCH" 2>/dev/null || true
fi

# --- 現在の稼働状況を集める ----------------------------------------------

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
host="$(hostname)"
jobs="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -E '^(ai\.openclaw|com\.dailyhack)\.' | sort)"
count="$(printf '%s' "$jobs" | grep -c . || true)"

{
  echo "{"
  echo "  \"generated_at\": \"$now\","
  echo "  \"host\": \"$host\","
  echo "  \"job_count\": $count,"
  echo "  \"jobs\": ["
  first=1
  for j in $jobs; do
    [ $first -eq 1 ] && first=0 || echo ","
    printf '    "%s"' "$j"
  done
  [ $first -eq 0 ] && echo ""
  echo "  ]"
  echo "}"
} > "$WT/heartbeat.json"

# --- push する -----------------------------------------------------------

git -C "$WT" add heartbeat.json
if git -C "$WT" diff --cached --quiet; then
  # 中身が同じでも「生きている」ことを示す必要があるため空コミットを打つ
  git -C "$WT" commit -q --allow-empty -m "ops: heartbeat $now ($count jobs)" || die "commit に失敗した"
else
  git -C "$WT" commit -q -m "ops: heartbeat $now ($count jobs)" || die "commit に失敗した"
fi

# 履歴が無限に伸びないよう、毎回 1 コミットに潰して force push する
git -C "$WT" push -q --force origin "HEAD:$BRANCH" || die "push に失敗した"

echo "ops-heartbeat: pushed $now ($count jobs)"
