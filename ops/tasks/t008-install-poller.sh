#!/bin/bash
# **1 分ごとに `ops/tasks` を拾うポーラーを入れる。**
#
# 利用者の判断（2026-08-30）: 「1分ポーラーを別立て」。
#
# ## なぜ別立てなのか
#
# 承認済みの X 投稿が **2 時間 20 分かけて出せなかった。**
# 原因のひとつは、タスクの実行が **30 分間隔の死活監視に相乗りしていた**こと。
#
#   死活監視（30 分で妥当）  →  そのまま  →  命令の経路（30 分では話にならない）
#
# 死活監視ごと 1 分にすると、`launchctl` の一覧・ログの mtime・git fetch を
# 30 倍の頻度で回すことになって筋が悪い。**実行だけを切り出して別ジョブにする。**
#
# - `com.dailyhack.ops-heartbeat`（30 分）… 死活監視。**触らない**
# - `com.dailyhack.ops-poller`（1 分）… `ops/tasks` を拾うだけ。**新規**
#
# ## 自分を殺さない
#
# `t003` は `launchctl bootout` で**自分を実行しているジョブごと**再ロードし、
# 自殺する設計だった（`docs/ops-task-runner.md`）。今回は
#
#   1. 触るのは**別ラベル**（`ops-poller`）。このタスクは heartbeat の子として走る
#   2. **既に 60 秒で入っていれば、何もせず `exit 0`**。
#      将来ポーラー自身がこのタスクを拾っても、bootout に到達しない
#
# ## API 課金 $0
#
# ポーラーがするのは `git fetch` と `ops/tasks` の実行だけ。**LLM を呼ばない。**
# 1 分間隔（1,440 回/日）でも Anthropic 側の課金は発生しない。
set -uo pipefail

LBL="com.dailyhack.ops-poller"
HB="com.dailyhack.ops-heartbeat"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/install-poller.md"
PLIST="$HOME/Library/LaunchAgents/$LBL.plist"
LOGDIR="$HOME/.openclaw/logs"
UID_N="$(id -u)"
WANT=60
PY="$(command -v python3.11 || command -v python3)"

interval_now() {
  plutil -extract StartInterval raw -o - "$PLIST" 2>/dev/null || echo ""
}

{
echo "# 1 分ポーラーを入れる（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> 死活監視（30 分）は触らない。**実行だけを別ジョブに切り出す。**"
echo "> 経緯: \`docs/x-post-latency-postmortem.md\`"

echo
echo "## 0. もう入っていないか"
echo
CUR="$(interval_now)"
LOADED="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$LBL" || true)"
echo "- 現在の StartInterval: \`${CUR:-無し}\` / ロード: \`${LOADED}\` 件"
if [ "$CUR" = "$WANT" ] && [ "${LOADED:-0}" != "0" ]; then
  echo
  echo "- → **既に 60 秒で入っている。何もしない。**"
  echo
  echo "> ここで止まるのが大事。**このタスクをポーラー自身が拾ったときに、"
  echo "> bootout まで進むと自分を殺す**（\`t003\` がそれで取り下げになった）。"
  exit 0
fi

echo
echo "## 1. 前提を確かめる"
echo
[ -n "$PY" ] || { echo "- **python3 が無い。中止。**"; exit 1; }
[ -d "$REPO/.git" ] || { echo "- **リポジトリが無い: $REPO。中止。**"; exit 1; }
if ! git -C "$REPO" cat-file -e origin/main:scripts/ops-run-tasks.sh 2>/dev/null; then
  git -C "$REPO" fetch -q origin main 2>/dev/null || true
fi
if ! git -C "$REPO" cat-file -e origin/main:scripts/ops-run-tasks.sh 2>/dev/null; then
  echo "- **origin/main に \`scripts/ops-run-tasks.sh\` が無い。中止。**"
  echo "  （ポーラーはこれを叩くので、先に main へ入っている必要がある）"
  exit 1
fi
echo "- \`scripts/ops-run-tasks.sh\` は origin/main にある"
echo "- python: \`$PY\`"

# **heartbeat の plist から環境を写す。** 当て推量で PATH を書かない
HBPLIST="$HOME/Library/LaunchAgents/$HB.plist"
if [ ! -f "$HBPLIST" ]; then
  echo "- **heartbeat の plist が見つからない（\`$HBPLIST\`）。中止。**"
  echo "  環境変数を当て推量で書くとポーラーが動かない"
  exit 1
fi
echo "- heartbeat の plist を環境の見本にする"

echo
echo "## 2. plist を書く"
echo
mkdir -p "$HOME/Library/LaunchAgents" "$LOGDIR"
"$PY" - "$HBPLIST" "$PLIST" "$LBL" "$REPO" "$LOGDIR" "$WANT" <<'PY' 2>&1 | head -20
import plistlib, sys, os
src, dst, label, repo, logdir, want = sys.argv[1:7]
with open(src, "rb") as f:
    hb = plistlib.load(f)

# heartbeat と同じ環境で走らせる。**PATH を推測で書かない**
env = dict(hb.get("EnvironmentVariables") or {})
env["DAILY_HACK_REPO"] = repo
env["OPS_PUSH"] = "1"          # 走ったときだけ push する

d = {
    "Label": label,
    "ProgramArguments": ["/bin/bash", os.path.join(repo, "scripts/ops-run-tasks.sh")],
    "StartInterval": int(want),
    "RunAtLoad": True,
    "EnvironmentVariables": env,
    "StandardOutPath": os.path.join(logdir, "ops-poller.out.log"),
    "StandardErrorPath": os.path.join(logdir, "ops-poller.err.log"),
}
for k in ("WorkingDirectory",):
    if k in hb:
        d[k] = hb[k]

with open(dst, "wb") as f:
    plistlib.dump(d, f)
print(f"- 書いた: StartInterval={d['StartInterval']} / 環境変数 {len(env)} 件を heartbeat から写した")
print(f"- 実行するもの: {' '.join(d['ProgramArguments'])}")
PY

if ! plutil -p "$PLIST" 2>/dev/null | grep -q '"Label"'; then
  echo "- **書いた plist が壊れている。消して中止。**"
  rm -f "$PLIST"
  exit 1
fi

echo
echo "## 3. ロードする"
echo
echo "> **触るのは \`$LBL\` だけ。** 自分を動かしている \`$HB\` には触らない"
launchctl bootout "gui/$UID_N/$LBL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID_N" "$PLIST" >/dev/null 2>&1
sleep 3
NOWLOADED="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$LBL" || true)"
if [ "${NOWLOADED:-0}" != "0" ]; then
  echo "- **ロード成功**"
else
  echo "- **ロードできなかった。plist を消して元の状態に戻す**"
  rm -f "$PLIST"
  exit 1
fi

echo
echo "## 4. 確認"
echo
echo "- \`$LBL\`: StartInterval=**$(interval_now)** 秒 / ロード=**${NOWLOADED}** 件"
echo "- \`$HB\`: ロード=**$(launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$HB" || echo 0)** 件（触っていない）"
echo
echo "**これで \`ops/tasks\` にコミットしたものは最大 1 分で走る。**"
echo
echo "> API 課金は **\$0**。ポーラーがするのは \`git fetch\` と \`ops/tasks\` の実行だけで、"
echo "> **LLM を呼ばない。** 1,440 回/日 でも Anthropic 側の課金は発生しない。"
} > "$OUT" 2>&1

if grep -q '既に 60 秒で入っている' "$OUT" 2>/dev/null; then echo "ポーラーは導入済み / $(basename "$OUT")"
elif grep -q 'ロード成功' "$OUT" 2>/dev/null; then echo "**1 分ポーラーを入れた** / $(basename "$OUT")"
else echo "**ポーラーを入れられていない** / $(basename "$OUT")"; fi
