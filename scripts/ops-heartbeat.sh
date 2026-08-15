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
# launchd から動かすための前提（実機検証で判明。2026-08-15）:
#   1. push 認証に osxkeychain を使えない。launchd からはキーチェーンを読めず
#      必ず落ちる。gh のトークンファイル（~/.config/gh/hosts.yml）を使う。
#   2. PATH が最小限。git は絶対パスで呼ぶ。
#   3. 作業ツリーは触らない。専用の worktree を使い、進行中の作業と衝突させない。

set -uo pipefail

GIT="${GIT_BIN:-/usr/bin/git}"
MAIN_REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${OPS_HEARTBEAT_WORKTREE:-$HOME/.openclaw/ops-heartbeat-wt}"
BRANCH="${OPS_HEARTBEAT_BRANCH:-ops/heartbeat}"
GH_HOSTS="${GH_HOSTS_FILE:-$HOME/.config/gh/hosts.yml}"

die() { echo "ops-heartbeat: $1" >&2; exit 1; }

[ -x "$GIT" ] || die "git が見つからない: $GIT"
[ -d "$MAIN_REPO/.git" ] || die "リポジトリが見つからない: $MAIN_REPO"

# --- push 先を組み立てる（トークンは絶対に出力しない） --------------------

# osxkeychain は launchd から読めないため、gh のトークンを使う。
token="$(awk '/^github\.com:/ {f=1; next} f && /oauth_token:/ {print $2; exit}' "$GH_HOSTS" 2>/dev/null)"
[ -n "$token" ] || die "gh のトークンを取得できない: $GH_HOSTS"

origin_url="$("$GIT" -C "$MAIN_REPO" remote get-url origin 2>/dev/null)"
slug="$(printf '%s' "$origin_url" | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
[ -n "$slug" ] || die "origin から owner/repo を取り出せない: $origin_url"

push_url="https://x-access-token:${token}@github.com/${slug}.git"

# credential.helper を空にして osxkeychain を確実に無効化する
git_push() {
  "$GIT" -C "$WT" -c credential.helper= push -q --force "$push_url" "HEAD:$BRANCH"
}

# --- worktree を用意する（初回のみ） -------------------------------------

"$GIT" -C "$MAIN_REPO" fetch -q origin "$BRANCH" 2>/dev/null || true

if [ ! -e "$WT/.git" ]; then
  mkdir -p "$(dirname "$WT")"
  if "$GIT" -C "$MAIN_REPO" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    "$GIT" -C "$MAIN_REPO" worktree add -f "$WT" -B "$BRANCH" "origin/$BRANCH" >/dev/null \
      || die "worktree の作成に失敗した"
  else
    # ブランチが無い初回。履歴を持たない orphan として作る。
    "$GIT" -C "$MAIN_REPO" worktree add -f --detach "$WT" >/dev/null || die "worktree の作成に失敗した"
    "$GIT" -C "$WT" checkout -q --orphan "$BRANCH" || die "orphan ブランチの作成に失敗した"
    "$GIT" -C "$WT" rm -rqf . >/dev/null 2>&1 || true
  fi
else
  "$GIT" -C "$WT" fetch -q origin "$BRANCH" 2>/dev/null || true
  "$GIT" -C "$WT" reset -q --hard "origin/$BRANCH" 2>/dev/null || true
fi

# --- 現在の稼働状況を集める ----------------------------------------------

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
host="$(hostname)"

# 生出力もそのまま載せる。クラウド側の偽陽性検知と突き合わせやすくするため
# （Mac 側からの要望。2026-08-15）
# タブは JSON 文字列にそのまま入れられない（制御文字は要エスケープ）。
# 空白に潰しておく。潰さないと壊れた JSON を push し続けて監視が動かない。
raw="$(launchctl list 2>/dev/null | grep -E '(ai\.openclaw|com\.dailyhack)\.' | tr '\t' ' ' | sort -k3)"
jobs="$(printf '%s\n' "$raw" | awk 'NF {print $3}' | sort)"
count="$(printf '%s' "$jobs" | grep -c . || true)"

json_array() {
  local first=1 line
  printf '['
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ $first -eq 1 ] && first=0 || printf ','
    printf '\n    %s' "$(printf '%s' "$line" | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/')"
  done
  [ $first -eq 0 ] && printf '\n  '
  printf ']'
}

{
  printf '{\n'
  printf '  "generated_at": "%s",\n' "$now"
  printf '  "host": "%s",\n' "$host"
  printf '  "job_count": %s,\n' "$count"
  printf '  "jobs": '; printf '%s\n' "$jobs" | json_array; printf ',\n'
  printf '  "launchctl_raw": '; printf '%s\n' "$raw" | json_array; printf '\n'
  printf '}\n'
} > "$WT/heartbeat.json"

# --- push する -----------------------------------------------------------

"$GIT" -C "$WT" add heartbeat.json
if "$GIT" -C "$WT" diff --cached --quiet; then
  # 中身が同じでも「生きている」ことを示す必要があるため空コミットを打つ
  "$GIT" -C "$WT" commit -q --allow-empty -m "ops: heartbeat $now ($count jobs)" || die "commit に失敗した"
else
  "$GIT" -C "$WT" commit -q -m "ops: heartbeat $now ($count jobs)" || die "commit に失敗した"
fi

# 履歴が無限に伸びないよう、毎回 1 コミットに潰して force push する。
# 失敗しても push_url を出力に混ぜない（トークンが漏れる）
if ! git_push; then
  die "push に失敗した（認証・ネットワークを確認する。トークンは出力しない）"
fi

echo "ops-heartbeat: pushed $now ($count jobs)"
