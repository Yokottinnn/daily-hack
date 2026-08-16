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

# --- 自分自身を最新にしてから走る -------------------------------------------
#
# main にマージしても、このスクリプトは Mac 上の古いままだった。
# 2026-08-16 に実測: #171 をマージした 18 分後の heartbeat に、新しい項目が
# 一切載っていなかった。**誰かが手で pull しない限り反映されない構造**だった。
#
# このジョブは 30 分ごとに確実に走る唯一のものなので、ここで自分を更新する。
#
# **作業ツリーには触らない。** `git pull` すると Mac 上で進行中の作業と衝突しうる。
# origin/main から中身だけ取り出して、それを実行し直す。

if [ -z "${OPS_HEARTBEAT_SELF_UPDATED:-}" ]; then
  latest="${TMPDIR:-/tmp}/ops-heartbeat-latest.sh"
  git -C "$MAIN_REPO" fetch -q origin main 2>/dev/null || true
  if git -C "$MAIN_REPO" show origin/main:scripts/ops-heartbeat.sh > "$latest" 2>/dev/null \
     && [ -s "$latest" ] && ! cmp -s "$latest" "$0"; then
    echo "ops-heartbeat: 新しい版に入れ替えて実行し直す" >&2
    # 環境変数で 1 回だけに制限する。取り違えても無限ループにならない
    OPS_HEARTBEAT_SELF_UPDATED=1 exec /bin/bash "$latest" "$@"
  fi
fi

# --- 切れた remote-control を繋ぎ直す（フラグがあるときだけ） ---------------
#
# 2026-08-17、Mac 側の `/remote-control` 接続が切れ、クラウドからの依頼が
# `SESSION_STATUS_PENDING` のまま届かなくなった。利用者は外出中で PC を開けない。
#
# Mac 本体と launchd は生きている（heartbeat が届き続けている）ため、
# **この 30 分ごとのジョブが、クラウドから Mac を動かせる唯一の経路**になる。
#
# 危険な操作なので、**リポジトリにフラグファイルがあるときだけ**動く。
# 不要になったら `ops/reconnect-request` を消せば止まる。

# フラグは **作業ツリーではなく `origin/main` を見る。**
# Mac の作業ツリーは誰かが pull しない限り古いままで、置いたファイルが見えない。
# 自己更新の直前で `git fetch origin main` を済ませてあるので、これで最新が引ける。
TMUX_SESSION="${OPS_RECONNECT_TMUX:-dhblog2}"
reconnect_status="無効（フラグ無し）"

if git -C "$MAIN_REPO" cat-file -e origin/main:ops/reconnect-request 2>/dev/null; then
  # launchd は PATH が最小限。絶対パスで拾えるようにしておく
  TMUX_BIN="$(command -v tmux 2>/dev/null || true)"
  [ -n "$TMUX_BIN" ] || TMUX_BIN=/opt/homebrew/bin/tmux
  CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
  [ -n "$CLAUDE_BIN" ] || CLAUDE_BIN=/opt/homebrew/bin/claude

  if [ ! -x "$TMUX_BIN" ] || [ ! -x "$CLAUDE_BIN" ]; then
    reconnect_status="tmux か claude が見つからない"
  elif "$TMUX_BIN" has-session -t "$TMUX_SESSION" 2>/dev/null; then
    reconnect_status="既に起動している"
  else
    # 直近の会話を選ぶ。**新しい会話を作らない。** 文脈が失われるため
    PROJ="$HOME/.claude/projects/-Users-ny--projects-anta-baka-x-blog"
    SID="$(ls -t "$PROJ"/*.jsonl 2>/dev/null | head -1 | sed 's#.*/##; s#\.jsonl$##')"
    if [ -z "$SID" ]; then
      reconnect_status="復旧する会話が見つからない"
    elif "$TMUX_BIN" new -d -s "$TMUX_SESSION" \
           "cd '$MAIN_REPO' && '$CLAUDE_BIN' --resume $SID" 2>/dev/null; then
      sleep 25
      "$TMUX_BIN" send-keys -t "$TMUX_SESSION" "/remote-control" Enter 2>/dev/null || true
      reconnect_status="起動して /remote-control を送った"
    else
      reconnect_status="tmux の起動に失敗した"
    fi
  fi
fi

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

# --- 何がジョブを勝手に戻しているのかを可視化する ---------------------------
#
# 「停止したはずのジョブが動いている」が繰り返し起きている。
# 2026-08-15 には、OpenClaw が bootout したと報告した comment-warmup が
# その後もずっと launchctl list に載り続けていた。
#
# 「落ちてたら戻す」系のジョブが犯人である疑いが強い（com.dailyhack.rc-keeper など）。
# クラウドからは Mac の plist を読めないため、ここで実行内容を押し出す。
#
# **環境変数の値は絶対に出さない。** API キーが入っている可能性があるため、
# 出すのは実行されるコマンドのパスだけにする。

reloaders=""
first_rl=1
for label in $jobs; do
  case "$label" in
    # tab-guard は 2026-08-10 に全ジョブを bootout した実績があるため必ず含める
    *keeper*|*guard*|*watchdog*|*ensure*|*supervis*) ;;
    *) continue ;;
  esac
  plist="$HOME/Library/LaunchAgents/${label}.plist"
  [ -f "$plist" ] || continue
  prog="$(plutil -p "$plist" 2>/dev/null \
    | awk '/"ProgramArguments"/,/\)/' \
    | grep -oE '"[^"]+"' | tr -d '"' | grep -v '^ProgramArguments$' \
    | tr '\n' ' ' | sed 's/ *$//' | cut -c1-300)"
  interval="$(plutil -extract StartInterval raw "$plist" 2>/dev/null || echo "")"
  [ $first_rl -eq 1 ] && first_rl=0 || reloaders="$reloaders,"
  reloaders="$reloaders
      {\"label\": \"$label\", \"interval\": \"${interval}\", \"program\": \"${prog//\"/}\"}"
done

# --- 本日の実活動を数える -------------------------------------------------
#
# ジョブが `launchctl list` に載っていることは、**リプが打てている証拠にならない。**
# 2026-08-15 に、載っているのに実際は動いていない（OAuth 失効で生成が失敗する）
# 状態が起きたが、クラウドからは区別できなかった。
#
# そこでログから「今日いくつ投稿したか」を数え、押し出す。
# ログの場所は docs/openclaw-recovery.md に記録がある実在のパス。
#
# **検出条件は実機のログ書式に合わせること。** 最初の実装は `tweet_id` という文字列と
# `2026-08-16` 形式の日付を条件にしていたが、実機の成功記録は次の形で、
# **どちらも含まれていなかった。** 投稿があっても 0 件と数えていた。
#
#   {"ok":true,"entry_id":"comment-20260816-...
#   [2026-08-16T19:03:05] today's reply-conn...
#
# 日付の表記が 2 通りある（`20260816` と `2026-08-16`）ため、両方を見る。

LOGS="${OPENCLAW_LOGS:-$HOME/.openclaw/workspace/logs}"
today="$(date -u +%Y-%m-%d)"
today_local="$(date +%Y-%m-%d)"
today_plain="$(date +%Y%m%d)"
today_plain_utc="$(date -u +%Y%m%d)"
posted_today=0
activity_sources=""
activity_detail="判定不能"

if [ -d "$LOGS" ]; then
  activity_detail="ログを走査した"
  first_src=1
  for f in "$LOGS"/*.log; do
    [ -e "$f" ] || continue
    # 成功記録は 2 通りの書き方をされている。grep -c は行単位で数えるため、
    # 両方に当たる行があっても二重には数えない。
    #   1. JSON 形式:  {"ok":true,"entry_id":"comment-20260816-...
    #   2. 行頭に日時: [2026-08-16T19:03:05] ... tweet_id ...
    n="$(grep -cE "(\"ok\":true.*(${today_plain}|${today_plain_utc}))|((${today}|${today_local}).*tweet_id)" \
      "$f" 2>/dev/null || true)"
    [ "${n:-0}" -eq 0 ] && continue
    posted_today=$((posted_today + n))
    [ $first_src -eq 1 ] && first_src=0 || activity_sources="$activity_sources,"
    activity_sources="$activity_sources
      {\"file\": \"$(basename "$f")\", \"count\": $n}"
  done
fi

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

# 2) トークンの有効期限を読む。
#
#    最初の実装は python3 で JSON を解いていたが、実機（手動実行・Keychain 読める状態）
#    でも判定不能のままだった。**解析側が動いていなかった。**
#    macOS の `/usr/bin/python3` は Command Line Tools を要求することがあり、
#    その場合は黙って失敗する。**外部インタプリタに依存しない形に変える。**
#
#    Keychain が読めないときのために、ファイル側も見る。
#    ただしファイルは古いことがある（再ログインしても更新されない）ため Keychain を優先する。
cred="$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null || true)"
if [ -z "$cred" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
  cred="$(cat "$HOME/.claude/.credentials.json" 2>/dev/null || true)"
fi
if [ -n "$cred" ]; then
  # "expiresAt": 1760000000000 から数字だけを取り出す。grep だけで完結させる。
  exp_ms="$(printf '%s' "$cred" \
    | grep -o '"expiresAt"[[:space:]]*:[[:space:]]*[0-9]*' \
    | grep -oE '[0-9]+$' | head -1)"
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
  echo "  \"reconnect\": \"$reconnect_status\","
  echo "  \"auth\": {"
  echo "    \"ok\": $auth_ok,"
  echo "    \"expires_at\": $auth_expires,"
  echo "    \"detail\": \"$auth_detail\""
  echo "  },"
  echo "  \"activity\": {"
  echo "    \"date\": \"$today\","
  echo "    \"posted_today\": $posted_today,"
  echo "    \"detail\": \"$activity_detail\","
  if [ -n "$activity_sources" ]; then
    echo "    \"sources\": [$activity_sources"
    echo "    ]"
  else
    echo "    \"sources\": []"
  fi
  echo "  },"
  if [ -n "$reloaders" ]; then
    echo "  \"reloaders\": [$reloaders"
    echo "  ]"
  else
    echo "  \"reloaders\": []"
  fi
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
