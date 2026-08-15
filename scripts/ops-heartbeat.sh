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

# --- 認証の状態を見る -----------------------------------------------------
#
# 2026-08-15 に OAuth が失効し、Mac のセッションが 2 時間半 何も返さなくなった。
# クラウド側からは connected に見え、fire_trigger も成功するため判別できない。
# 症状は「返事が来ない」だけで、失効を知る手段が無かった。
#
# そこで 2 つの経路で見る。片方が取れなくても、もう片方が効く。
#   1. 直近の会話ログに認証エラーが出ていないか（launchd から必ず読める）
#   2. Keychain のトークン有効期限（読めれば失効「前」に警告できる）

auth_ok="null"        # true / false / null(判定不能)
auth_expires="null"
auth_detail="判定不能"

# 1) 直近3時間に更新された会話ログの末尾に認証エラーが出ていないか。
#    ファイル全体を見ると過去の失効が永久に残るため、末尾 200KB だけ見る。
auth_err=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if tail -c 200000 "$f" 2>/dev/null \
       | grep -qE 'OAuth session expired|Not logged in'; then
    auth_err="$f"
    break
  fi
done <<EOF
$(find "$HOME/.claude/projects" -name '*.jsonl' -mmin -180 2>/dev/null)
EOF

if [ -n "$auth_err" ]; then
  auth_ok="false"
  auth_detail="直近の会話ログに認証エラーが出ている"
fi

# 2) Keychain からトークンの有効期限を読む。
#    launchd からはキーチェーンを読めないことがある（§16 の -25308 と同じ罠）。
#    読めなければ判定不能のままにする。**読めないことを異常として扱わない。**
cred="$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null || true)"
if [ -n "$cred" ]; then
  exp_ms="$(printf '%s' "$cred" \
    | /usr/bin/python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    while isinstance(d, dict) and "expiresAt" not in d:
        d = next((v for v in d.values() if isinstance(v, dict)), None)
    print(int(d["expiresAt"]) if d else "")
except Exception:
    print("")' 2>/dev/null)"
  if [ -n "$exp_ms" ]; then
    auth_expires="\"$(date -u -r "$((exp_ms / 1000))" +%Y-%m-%dT%H:%M:%SZ)\""
    if [ "$auth_ok" = "null" ]; then
      if [ "$((exp_ms / 1000))" -le "$(date -u +%s)" ]; then
        auth_ok="false"
        auth_detail="トークンの有効期限を過ぎている"
      else
        auth_ok="true"
        auth_detail="有効期限内"
      fi
    fi
  fi
fi

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
  echo "  ],"
  echo "  \"auth\": {"
  echo "    \"ok\": $auth_ok,"
  echo "    \"expires_at\": $auth_expires,"
  echo "    \"detail\": \"$auth_detail\""
  echo "  }"
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
