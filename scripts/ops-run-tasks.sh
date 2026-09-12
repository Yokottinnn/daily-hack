#!/bin/bash
# **`ops/tasks/*.sh` を実行する唯一の場所。**
#
#   bash scripts/ops-run-tasks.sh          # 実行するだけ（push しない）
#   OPS_PUSH=1 bash scripts/ops-run-tasks.sh   # 何か走ったら push もする
#
# ## なぜ heartbeat から切り出したのか
#
# 2026-08-30、承認済みの X 投稿が **2 時間 20 分かけて出せなかった。**
# 原因のひとつが「タスクの実行が 30 分間隔の死活監視に相乗りしていた」こと。
#
#   死活監視（30 分で十分）  →  そのまま  →  命令の経路（30 分では話にならない）
#
# 死活監視の間隔を縮めるのは筋が悪い（`launchctl` の一覧・ログの mtime・
# git fetch を 30 倍の頻度で回すことになる）。**実行だけを切り出して、
# 軽いポーラーから 1 分ごとに叩く。** 経緯は `docs/x-post-latency-postmortem.md`。
#
# ## 二重実行はロックで防ぐ
#
# ポーラー（1 分）と heartbeat（30 分）は必ずぶつかる。**`mkdir` は原子的**なので
# ロックに使う。取れなければ**何もせずに終わる**（次の分にまた来る）。
#
# **投稿タスクを二重に走らせない。** ここが緩いと同じツイートが 2 回出る。
#
# ## タスクは 1 回しか走らない
#
# `done/<task>.sh` は **rc に関係なく**書く。失敗しても同じ名前では二度と走らない。
# 詳しくは `docs/ops-task-runner.md`。
#
# **出力は公開リポジトリに載る。** タスク側で秘密を出さないこと。
set -uo pipefail

MAIN_REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${OPS_HEARTBEAT_WORKTREE:-$HOME/.openclaw/ops-heartbeat-wt}"
BRANCH="${OPS_HEARTBEAT_BRANCH:-ops/heartbeat}"
LOCK="$WT/.tasks.lock"
OUTJSON="$WT/last-tasks.json"
# **300 秒。** 1800 秒（30 分）は 1 分間隔のポーラーに対して長すぎた。
# 2026-09-04、取り残しのせいで 28 分 タスクが 1 件も走らなかった。
# t016 で見つけて記録したのに直さず、同じことをもう一度起こした。
STALE_SEC="${OPS_TASK_STALE_SEC:-300}"

[ -d "$MAIN_REPO/.git" ] || { echo "ops-run-tasks: リポジトリが無い: $MAIN_REPO" >&2; exit 1; }
[ -d "$WT" ] || { echo "ops-run-tasks: worktree が無い: $WT" >&2; exit 1; }

# --- 自分自身を最新にしてから走る -------------------------------------------
#
# heartbeat と同じ理由。main にマージしても Mac 上は古いままなので、
# origin/main から中身を取り出して実行し直す。**作業ツリーには触らない。**
if [ -z "${OPS_RUN_TASKS_SELF_UPDATED:-}" ]; then
  latest="${TMPDIR:-/tmp}/ops-run-tasks-latest.sh"
  git -C "$MAIN_REPO" fetch -q origin main 2>/dev/null || true
  if git -C "$MAIN_REPO" show origin/main:scripts/ops-run-tasks.sh > "$latest" 2>/dev/null \
     && [ -s "$latest" ] && ! cmp -s "$latest" "$0"; then
    OPS_RUN_TASKS_SELF_UPDATED=1 exec /bin/bash "$latest" "$@"
  fi
else
  git -C "$MAIN_REPO" fetch -q origin main 2>/dev/null || true
fi

# --- ロック ----------------------------------------------------------------
#
# **`mkdir` は原子的。** `[ -e ]` してから作る形だと隙間で両方が通る。
if ! mkdir "$LOCK" 2>/dev/null; then
  # 取り残されたロックだけは外す。**それ以外は譲る（ログは出す）**
  if [ -f "$LOCK/started_at" ]; then
    started="$(cat "$LOCK/started_at" 2>/dev/null || echo 0)"
    now_s="$(date +%s)"
    if [ $((now_s - started)) -gt "$STALE_SEC" ] 2>/dev/null; then
      echo "ops-run-tasks: $STALE_SEC 秒以上前のロックを外す" >&2
      rm -rf "$LOCK"
      mkdir "$LOCK" 2>/dev/null || exit 0
    else
      # **黙って譲らない。** 無言だと「止まっている」のか「譲っている」のか
      # 外から区別できない。2026-09-04 にこれで 28 分 気づけなかった。
      echo "ops-run-tasks: 別の実行がロック中（$((now_s - started)) 秒経過）。譲る" >&2
      exit 0
    fi
  else
    echo "ops-run-tasks: ロックはあるが started_at が無い。譲る" >&2
    exit 0
  fi
fi
date +%s > "$LOCK/started_at"
trap 'rm -rf "$LOCK"' EXIT INT TERM

# --- 走らせる --------------------------------------------------------------

mkdir -p "$WT/done"
export OPS_REPORT_DIR="$WT/reports"
mkdir -p "$OPS_REPORT_DIR"
task_tmp="${TMPDIR:-/tmp}/ops-tasks"
mkdir -p "$task_tmp"

# --- 1 本あたりの制限時間 ---------------------------------------------------
#
# **タスクが止まると、後ろのタスクが 1 本も届かなくなる。**
# 実行は直列で、`done/` の印はタスクが終わってから書くため、
# 止まったタスクは印が付かず、次の周回でも同じところで止まる。
#
# 既定は 15 分。投稿を 3 分 待つタスクが複数あるので、短すぎると誤爆する。
TASK_TIMEOUT="${OPS_TASK_TIMEOUT:-900}"
TIMEOUT_BIN=""
for _c in timeout gtimeout; do
  if command -v "$_c" >/dev/null 2>&1; then TIMEOUT_BIN="$(command -v "$_c")"; break; fi
done
[ -z "$TIMEOUT_BIN" ] && echo "ops-run-tasks: timeout が無いので制限時間なしで走らせる" >&2

ran=0
results=""
first=1

for t in $(git -C "$MAIN_REPO" ls-tree --name-only "origin/main:ops/tasks" 2>/dev/null); do
  case "$t" in *.sh) ;; *) continue ;; esac
  [ -f "$WT/done/$t" ] && continue
  git -C "$MAIN_REPO" show "origin/main:ops/tasks/$t" > "$task_tmp/$t" 2>/dev/null || continue
  [ -s "$task_tmp/$t" ] || continue

  # **1 本あたりの制限時間。** これが無いと、長いタスク 1 本が後ろ全部を止める。
  #
  # 2026-09-13 に実際に起きた。`x44` が「目標 16 件に届くまで最大 8 回 繰り返す」
  # ループ（最大 8 回 × 3 分）に入り、**23 分 経っても終わらず、
  # `x45` / `x46` / `x47` が 1 本も届かなかった。**
  #
  # `done/` は**タスクが終わってから**書くので、止まったままだと印も付かない。
  # 次の周回も同じところで止まり、**キュー全体が永久に進まない。**
  #
  # `timeout` は macOS の素の状態には無い（coreutils）。
  # **無ければ無いで動くようにする。** 当て推量で失敗させない。
  if [ -n "$TIMEOUT_BIN" ]; then
    out="$("$TIMEOUT_BIN" -s TERM -k 30 "$TASK_TIMEOUT" /bin/bash "$task_tmp/$t" 2>&1)"
    rc=$?
  else
    out="$(/bin/bash "$task_tmp/$t" 2>&1)"
    rc=$?
  fi
  out="$(printf '%s' "$out" | tail -5 | tr '\n' ' ' | tr -d '"\\' | cut -c1-300)"
  # rc=124 は timeout が切った合図。**印を必ず付ける**ので、次の周回では飛ばされる
  if [ "$rc" = "124" ] || [ "$rc" = "137" ]; then
    out="制限時間 ${TASK_TIMEOUT} 秒 を超えたので打ち切った / $out"
  fi
  printf '%s rc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" > "$WT/done/$t"

  ran=$((ran + 1))
  [ $first -eq 1 ] && first=0 || results="$results,"
  results="$results
      {\"task\": \"$t\", \"rc\": $rc, \"out\": \"$out\"}"
done

# **毎回書く。** 走らなかったときは空配列。heartbeat はこれをそのまま載せる
if [ -n "$results" ]; then
  printf '[%s\n  ]\n' "$results" > "$OUTJSON"
else
  printf '[]\n' > "$OUTJSON"
fi

[ "$ran" = "0" ] && exit 0
echo "ops-run-tasks: $ran 件 実行した"

# --- push（頼まれたときだけ） ----------------------------------------------
#
# ポーラーからは `OPS_PUSH=1` で呼ぶ。**走ったときだけ push する**ので、
# 1 分間隔でも履歴は汚れない。heartbeat から呼ぶときは push しない
# （heartbeat 自身が最後にまとめて push するため）。
[ "${OPS_PUSH:-}" = "1" ] || exit 0

git -C "$WT" add -A
if git -C "$WT" diff --cached --quiet; then exit 0; fi
git -C "$WT" commit -q -m "ops: tasks $(date -u +%Y-%m-%dT%H:%M:%SZ) ($ran 件)" || exit 0
# heartbeat と同じく毎回 1 コミットに潰す
git -C "$WT" push -q --force origin "HEAD:$BRANCH" \
  && echo "ops-run-tasks: pushed" \
  || echo "ops-run-tasks: push に失敗" >&2
