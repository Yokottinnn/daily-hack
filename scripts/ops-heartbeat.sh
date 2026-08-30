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
    # **ディレクトリ名を決め打ちしない。** 2026-08-19 に
    # `-Users-ny--projects-anta-baka-x-blog` と書いて外した（ダッシュが 1 つ多い）。
    # Claude Code は `/` も `.` も `-` に置き換えるため、ドットを含むパスだけが
    # 二重ダッシュになる。`/Users/ny/.openclaw/workspace` → `-Users-ny--openclaw-workspace`、
    # `/Users/ny/projects/anta-baka-x/blog` → `-Users-ny-projects-anta-baka-x-blog`。
    #
    # 規則を推測して書くより、**実在するディレクトリから探す**ほうが確実。
    SID=""
    for d in "$HOME"/.claude/projects/*anta-baka-x-blog; do
      [ -d "$d" ] || continue
      SID="$(ls -t "$d"/*.jsonl 2>/dev/null | head -1 | sed 's#.*/##; s#\.jsonl$##')"
      [ -n "$SID" ] && break
    done
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

# --- コミットされたタスクを Mac 上で実行する --------------------------------
#
# **これがクラウドから Mac へ仕事を渡す正式な経路。**
#
# それまでは Mac の Claude セッションに依頼していたが、その経路は
#   1. remote-control の接続  2. OAuth の認証  3. 会話 ID の一致
# の 3 つすべてに依存し、どれか 1 つ壊ると全部止まる。2026-08-16〜19 に
# 3 つとも壊れ、**依頼が 3 日間 1 件も届かなかった。**
#
# このジョブは launchd から 30 分ごとに走り、接続にも認証にも依存しない。
#
# **実行そのものは `scripts/ops-run-tasks.sh` に移した。**
# 2026-08-30、承認済みの X 投稿が 30 分間隔に阻まれて 2 時間 20 分 出せなかった。
# 死活監視の間隔（30 分で妥当）と、命令が届くまでの時間（30 分では話にならない）は
# **別の要求**なので、実行を切り出して 1 分間隔のポーラーからも叩けるようにした。
# 経緯は `docs/x-post-latency-postmortem.md`。
#
# ここから呼ぶときは **push しない**（最後にこのスクリプトがまとめて push するため）。
# 二重実行は `ops-run-tasks.sh` 側のロックが防ぐ。
#
# 実行済みの印は heartbeat ブランチ側に残す（push されるので二重実行しない）。
# **出力は 300 字で切る。** 公開リポジトリに載るため、タスク側で秘密を出さないこと。

mkdir -p "$WT/done" "$WT/reports"
runner="${TMPDIR:-/tmp}/ops-run-tasks-latest.sh"
if git -C "$MAIN_REPO" show origin/main:scripts/ops-run-tasks.sh > "$runner" 2>/dev/null && [ -s "$runner" ]; then
  /bin/bash "$runner" >&2
else
  echo "ops-heartbeat: ops-run-tasks.sh を取り出せない。タスクは走らせない" >&2
fi

# `ops-run-tasks.sh` は走ったときに `last-tasks.json` を書く。
#
# **読んだら空にする。** ポーラーが走らせた分もここに残るので、空にしないと
# 次の周回でも同じ結果を載せてしまい、「2 回走った」ように見える。
# 実体（`reports/` と `done/`）は残るので、消えて困るものは無い。
tasks_json="$(cat "$WT/last-tasks.json" 2>/dev/null)"
[ -n "$tasks_json" ] || tasks_json="[]"
printf '[]\n' > "$WT/last-tasks.json" 2>/dev/null || true

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
  # **`-o -` を必ず付ける。** macOS の `plutil -extract KEY fmt FILE` は
  # 出力先を指定しないと **抽出結果でファイルそのものを上書きする。**
  # 2026-08-22、これを付けずに全 plist を走査したため、
  # `~/Library/LaunchAgents/ai.openclaw.*.plist` が
  # EnvironmentVariables の中身だけに潰れた（unloaded_count=56）。
  # この行も 30 分ごとに keeper / guard / watchdog 系を壊し続けていた。
  interval="$(plutil -extract StartInterval raw -o - "$plist" 2>/dev/null || echo "")"
  [ $first_rl -eq 1 ] && first_rl=0 || reloaders="$reloaders,"
  reloaders="$reloaders
      {\"label\": \"$label\", \"interval\": \"${interval}\", \"program\": \"${prog//\"/}\"}"
done

# --- plist はあるのに載っていないジョブを、全部あぶり出す -------------------
#
# **2026-08-22 の事故の根本原因はここにあった。**
#
# competitor-follower-follow（能動フォロー）は 7/07 に壊れて launchctl から
# 消えたが、**46 日間 誰も気づかなかった。** badge-followback も 13 日間。
# その間フォロワーは 12 日で +1 しか動いていない。
#
# なぜ気づけなかったか。監視は `launchctl list` の出力を見ていた。
# **消えたジョブはそこに出てこない。** 見えないものは検知できない。
#
# 対策として EXPECTED_JOBS に名前を足したが、**それだけでは足りない。**
# 手で保守するリストは、次に新しいジョブが増えたとき また同じ穴が開く。
# 「足し忘れたジョブ」は「消えても気づかれないジョブ」になる。
#
# そこで **名前を列挙せずに検知する。**
# `~/Library/LaunchAgents/` に plist があるのに `launchctl list` に無いものを
# 全部並べる。無効化したいものは plist を .disabled / .bak にリネームする
# 運用なので、**「.plist のまま載っていない」は原則すべて異常。**
#
# これなら私が名前を知らないジョブが壊れても捕まる。

unloaded=""
first_ul=1
unloaded_count=0
for plist in "$HOME/Library/LaunchAgents"/ai.openclaw.*.plist \
             "$HOME/Library/LaunchAgents"/com.dailyhack.*.plist; do
  [ -f "$plist" ] || continue
  label="$(basename "$plist" .plist)"
  # 無効化の意思表示（.disabled / .bak.*）は .plist で終わらないのでここに来ない
  printf '%s\n' "$jobs" | grep -qx "$label" && continue
  mtime="$(date -r "$plist" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")"
  [ $first_ul -eq 1 ] && first_ul=0 || unloaded="$unloaded,"
  unloaded="$unloaded
      {\"label\": \"$label\", \"plist_mtime\": \"$mtime\"}"
  unloaded_count=$((unloaded_count + 1))
done

# --- 成果そのものが止まっていないか（ジョブの生死は代理指標にすぎない）-----
#
# ジョブが載っていても、CDP が落ちていれば 1 件も実行されない。
# 実際 7/07〜8/09 の competitor-follower-follow がその状態だった
# （ログは動くが `scrape failure: ECONNREFUSED` の連発）。
#
# **だから最後は結果で見る。** フォロワー数が増えているかどうか。
# これなら壊れ方を知らなくても、未知のジョブが死んでも、必ず捕まる。

follower_now="null"
follower_prev="null"
follower_prev_date=""
follower_days="null"
FSLOG="$HOME/.openclaw/workspace/logs/follower-snapshot.log"
if [ -f "$FSLOG" ]; then
  # **行数で遡らない。** スナップショットの実行間隔を知らないまま「直近 N 件」で
  # 比べると、間隔が短ければ数時間分を「成長が止まった」と誤報する。
  # 誤報を出す監視は無視されるようになり、結局また見落とす。
  #
  # 日付ごとに最後の値を 1 つ取り、**日付が違う 2 点**で比べる。
  # 日付が読めなければ null にして、watchdog 側の判定を丸ごと飛ばす
  # （判定不能を「増えていない」と混同しない）。
  pairs="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[^}]*"count_today":[0-9]+' "$FSLOG" 2>/dev/null \
    | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2}).*"count_today":([0-9]+)$/\1 \2/' \
    | awk '{ last[$1] = $2 } END { for (d in last) print d, last[d] }' \
    | sort)"
  if [ -n "$pairs" ]; then
    follower_now="$(printf '%s\n' "$pairs" | tail -1 | awk '{print $2}')"
    now_date="$(printf '%s\n' "$pairs" | tail -1 | awk '{print $1}')"
    # 3 日以上前で、記録がある最も新しい日
    cutoff="$(date -u -v-3d +%Y-%m-%d 2>/dev/null || date -u -d '3 days ago' +%Y-%m-%d 2>/dev/null || echo "")"
    if [ -n "$cutoff" ]; then
      older="$(printf '%s\n' "$pairs" | awk -v c="$cutoff" '$1 <= c' | tail -1)"
      if [ -n "$older" ]; then
        follower_prev="$(printf '%s' "$older" | awk '{print $2}')"
        follower_prev_date="$(printf '%s' "$older" | awk '{print $1}')"
        follower_days=$(( ( $(date -u -j -f %Y-%m-%d "$now_date" +%s 2>/dev/null || date -u -d "$now_date" +%s) \
                          - $(date -u -j -f %Y-%m-%d "$follower_prev_date" +%s 2>/dev/null || date -u -d "$follower_prev_date" +%s) ) / 86400 ))
      fi
    fi
  fi
  [ -z "$follower_now" ] && follower_now="null"
  [ -z "$follower_prev" ] && follower_prev="null"
fi

# 目標設定（014 までで target=300 / deadline=2026-09-30 を入れてある）
follower_target="null"
follower_deadline=""
FCFG="$HOME/.openclaw/workspace/data/follower-target-config.json"
if [ -f "$FCFG" ]; then
  follower_target="$(grep -o '"target"[[:space:]]*:[[:space:]]*[0-9]*' "$FCFG" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)"
  [ -z "$follower_target" ] && follower_target="null"
  follower_deadline="$(grep -o '"deadline"[[:space:]]*:[[:space:]]*"[^"]*"' "$FCFG" 2>/dev/null | sed 's/.*"deadline"[[:space:]]*:[[:space:]]*"//; s/"$//' | head -1 || true)"
fi

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
  printf '  "tasks": %s,\n' "$tasks_json"
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
  # plist はあるのに載っていないもの。名前を列挙せずに「消えた」を検知する要
  echo "  \"unloaded_count\": $unloaded_count,"
  if [ -n "$unloaded" ]; then
    echo "  \"unloaded\": [$unloaded"
    echo "  ],"
  else
    echo "  \"unloaded\": [],"
  fi
  # 成果そのもの。ジョブの生死は代理指標にすぎないので、最後はここで見る
  echo "  \"followers\": {"
  echo "    \"now\": $follower_now,"
  echo "    \"prev\": $follower_prev,"
  echo "    \"prev_date\": \"$follower_prev_date\","
  echo "    \"span_days\": $follower_days,"
  echo "    \"target\": $follower_target,"
  echo "    \"deadline\": \"$follower_deadline\""
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

# `heartbeat.json` だけでなく、タスクが置いた報告（reports/）と
# 実行済みの印（done/）も一緒に載せる。
#
# **実行済みの印を push する理由**: これまで印はローカルにしか無く、worktree が
# 作り直されると同じタスクが再実行されていた。
# **報告を push する理由**: 2026-08-22 に、タスクは成功したのに `tasks` の記録が
# 履歴から消えていた（毎回 1 コミットに潰す設計のため）。実体でしか確認できず、
# 自己申告を照合できなかった。
# **ポーラーと同じ worktree を使う。** 相手が commit している最中に `add -A` すると
# ぶつかるので、`ops-run-tasks.sh` と同じロックを取ってから触る。
#
# **ただし、取れなくても押すのをやめてはいけない。**
# `.github/workflows/ops-watchdog.yml` の `STALE_MINUTES` は **90 分**。
# heartbeat は 30 分間隔なので、1 回飛ばすと 60 分、**2 回連続で飛ばすと閾値に触れて
# 「Mac が死んだ」と誤報する。** 押せないことは、それ自体が異常の合図として扱われる。
#
# 幸い **index の整合性は git 自身が `index.lock` で守る**（最悪 commit が 1 回失敗する
# だけで、壊れることはない）。だからロックは「行儀よく待つ」ためのものと割り切り、
# **待っても取れなければロック無しで進んで、失敗したら 1 回だけやり直す。**
hb_lock="$WT/.tasks.lock"
hb_got=0
for _ in $(seq 1 30); do          # 最大 60 秒 待つ
  if mkdir "$hb_lock" 2>/dev/null; then hb_got=1; date +%s > "$hb_lock/started_at"; break; fi
  sleep 2
done
if [ "$hb_got" = "1" ]; then
  trap 'rm -rf "$hb_lock"' EXIT INT TERM
else
  echo "ops-heartbeat: ロックが取れなかった。押すのを優先してロック無しで進む" >&2
fi

hb_commit() {
  git -C "$WT" add -A || return 1
  if git -C "$WT" diff --cached --quiet; then
    # 中身が同じでも「生きている」ことを示す必要があるため空コミットを打つ
    git -C "$WT" commit -q --allow-empty -m "ops: heartbeat $now ($count jobs)"
  else
    git -C "$WT" commit -q -m "ops: heartbeat $now ($count jobs)"
  fi
}

if ! hb_commit; then
  # 相手の commit とぶつかった可能性。少し待ってやり直す
  echo "ops-heartbeat: commit に失敗。10 秒待ってやり直す" >&2
  sleep 10
  if ! hb_commit; then
    # **取り残された index.lock だけ外す。** 生きている相手のロックは消さない
    gd="$(git -C "$WT" rev-parse --git-dir 2>/dev/null)"
    il="$gd/index.lock"
    if [ -n "$gd" ] && [ -f "$il" ]; then
      lock_age=$(( $(date +%s) - $(stat -f %m "$il" 2>/dev/null || stat -c %Y "$il" 2>/dev/null || date +%s) ))
      if [ "$lock_age" -gt 120 ] 2>/dev/null; then
        echo "ops-heartbeat: ${lock_age} 秒前の index.lock を外す" >&2
        rm -f "$il"
      fi
    fi
    hb_commit || die "commit に失敗した"
  fi
fi

# 履歴が無限に伸びないよう、毎回 1 コミットに潰して force push する
git -C "$WT" push -q --force origin "HEAD:$BRANCH" || die "push に失敗した"

echo "ops-heartbeat: pushed $now ($count jobs)"
