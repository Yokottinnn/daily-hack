#!/bin/bash
# **ポーラーが動いていない。原因を出して、同じ実行の中で直す。**
#
# ## 症状
#
# `t008` は成功し `launchctl list` にも載っている（StartInterval=60・ロード 1 件）。
# **なのに `t009` が 21 分経っても走らなかった。**
#
# ## 疑い（これを実際の出力で確かめる）
#
# `t008` が書いた plist はこれ。
#
#     ProgramArguments = ["/bin/bash", "<REPO>/scripts/ops-run-tasks.sh"]
#
# `t008` は**存在確認を `origin/main` に対して**やった。
#
#     git cat-file -e origin/main:scripts/ops-run-tasks.sh   ← ここは通る
#
# しかし **plist が指すのは作業ツリーのパス**である。
# `ops-heartbeat.sh` は「**作業ツリーには触らない**」設計で `git fetch` しかしないため、
# **Mac のディスク上に `scripts/ops-run-tasks.sh` が無い**可能性が高い。
# その場合 launchd は 60 秒ごとに存在しないファイルを叩いて失敗し続ける。
#
# **origin/main にあることと、ディスクにあることは別である。** これを混同した。
#
# ## 直し方
#
# **作業ツリーに依存しない場所へ実体を置く。**
#
#     ~/.openclaw/bin/ops-run-tasks.sh   ← origin/main から書き出す
#
# ここを plist から指す。`ops-run-tasks.sh` は**起動時に origin/main から自分を
# 更新して exec し直す**作りなので、この写しは古くなっても自動で最新になる。
# 以後この置き場を変える必要は無い。
#
# ## 自分を殺さない
#
# 触るのは `com.dailyhack.ops-poller`。このタスクは `com.dailyhack.ops-heartbeat` の
# 子として走るので、bootout しても自分は死なない（`docs/ops-task-runner.md`）。
#
# ## ついでに: 稼働ジョブが 20 → 7 に減っている
#
# 14:44 UTC は 20 件、15:14 UTC は 6 件。**14 件 消えている。**
# 原因は不明なので、**まず一覧を出す**（直しはしない。当て推量で戻さない）。
#
# **読むのと、ポーラーの plist を直すことだけ。他は変更しない。**
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

LBL="com.dailyhack.ops-poller"
HB="com.dailyhack.ops-heartbeat"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-poller-path.md"
PLIST="$HOME/Library/LaunchAgents/$LBL.plist"
BIN="$HOME/.openclaw/bin"
DST="$BIN/ops-run-tasks.sh"
LOGDIR="$HOME/.openclaw/logs"
UID_N="$(id -u)"
PY="$(command -v python3.11 || command -v python3)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# ポーラーが動いていない原因を出して直す（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> \`t008\` は成功したのに \`t009\` が 21 分 走らなかった。"
echo "> **origin/main にあることと、ディスクにあることは別である。**"

echo
echo "## 1. 疑いを確かめる"
echo
WT_PATH="$REPO/scripts/ops-run-tasks.sh"
if [ -f "$WT_PATH" ]; then
  echo "- 作業ツリーの \`scripts/ops-run-tasks.sh\`: **ある**（$(wc -c < "$WT_PATH" | tr -d ' ') B）"
  echo "  → **想定と違う。** 原因は別。下のログを見ること"
else
  echo "- 作業ツリーの \`scripts/ops-run-tasks.sh\`: **無い** ← **これが原因**"
  echo "  plist が指しているのは \`$WT_PATH\`"
fi
echo "- origin/main にはあるか: $(git -C "$REPO" cat-file -e origin/main:scripts/ops-run-tasks.sh 2>/dev/null && echo '**ある**' || echo '**無い**')"

echo
echo "### ポーラーの launchd 状態（直す前）"
echo '```'
launchctl print "gui/$UID_N/$LBL" 2>&1 | grep -aE 'state|last exit|program|path|runs =' | head -10 | mask
echo '```'
echo
echo "### ポーラーのエラーログ（末尾）"
echo '```'
tail -8 "$LOGDIR/ops-poller.err.log" 2>/dev/null | mask || echo "(err ログなし)"
echo '```'

echo
echo "## 2. 直す（**作業ツリーに依存しない場所へ実体を置く**）"
echo
mkdir -p "$BIN" "$LOGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
if ! git -C "$REPO" show origin/main:scripts/ops-run-tasks.sh > "$DST" 2>/dev/null || [ ! -s "$DST" ]; then
  echo "- **origin/main から取り出せない。中止。**"
  rm -f "$DST"
  exit 1
fi
chmod +x "$DST"
echo "- 書き出した: \`$DST\`（$(wc -c < "$DST" | tr -d ' ') B）"
if ! /bin/bash -n "$DST" 2>/dev/null; then
  echo "- **構文が壊れている。中止。**"; rm -f "$DST"; exit 1
fi
echo "- 構文: **OK**"
echo
echo "> \`ops-run-tasks.sh\` は起動時に origin/main から自分を更新して exec し直すので、"
echo "> **この写しは古くなっても自動で最新になる。** 置き場を変える必要は以後無い。"

echo
echo "### plist の ProgramArguments を差し替える"
echo
[ -n "$PY" ] || { echo "- **python3 が無い。中止。**"; exit 1; }
[ -f "$PLIST" ] || { echo "- **plist が無い（\`$PLIST\`）。中止。**"; exit 1; }
cp "$PLIST" "$PLIST.bak.$(date +%Y%m%d-%H%M%S)"
"$PY" - "$PLIST" "$DST" <<'PY' 2>&1 | head -6
import plistlib, sys
p, dst = sys.argv[1], sys.argv[2]
with open(p, "rb") as f: d = plistlib.load(f)
old = d.get("ProgramArguments")
d["ProgramArguments"] = ["/bin/bash", dst]
with open(p, "wb") as f: plistlib.dump(d, f)
print(f"- 前: {old}")
print(f"- 後: {d['ProgramArguments']}")
print(f"- StartInterval: {d.get('StartInterval')} / OPS_PUSH={(d.get('EnvironmentVariables') or {}).get('OPS_PUSH')}")
PY

if ! plutil -p "$PLIST" 2>/dev/null | grep -q '"Label"'; then
  echo "- **plist が壊れた。退避から戻す**"
  cp "$(ls -t "$PLIST".bak.* | head -1)" "$PLIST"
  exit 1
fi

echo
echo "## 3. 読み込み直す（**触るのは ops-poller だけ**）"
echo
launchctl bootout "gui/$UID_N/$LBL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID_N" "$PLIST" >/dev/null 2>&1
sleep 3
LOADED="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$LBL" || true)"
echo "- ロード: **${LOADED}** 件"
[ "${LOADED:-0}" = "0" ] && { echo "- **ロードできなかった。中止。**"; exit 1; }

echo
echo "## 4. 実際に走ったか（**90 秒 待って exit status を見る**）"
echo
echo "> このタスクはロックを握っているので、待っても \`t009\` は動けない"
echo "> （\`ops-run-tasks.sh\` はロックが取れなければ黙って終わる）。"
echo "> **見るのは「ポーラーが起動して正常終了したか」。**"
sleep 90
echo '```'
launchctl print "gui/$UID_N/$LBL" 2>&1 | grep -aE 'state|last exit|runs =' | head -8 | mask
echo '```'
echo
echo "### ポーラーのログ（直したあと）"
echo '```'
echo "-- out --"; tail -4 "$LOGDIR/ops-poller.out.log" 2>/dev/null | mask || echo "(なし)"
echo "-- err --"; tail -4 "$LOGDIR/ops-poller.err.log" 2>/dev/null | mask || echo "(なし)"
echo '```'
echo
echo "**\`last exit code = 0\` なら成功。** このタスクが終わってロックが外れれば、"
echo "**60 秒以内に \`t009\` が走る。**"

echo
echo "## 5. 稼働ジョブが 20 → 7 に減っている件（**一覧を出すだけ。直さない**）"
echo
echo "14:44 UTC は 20 件、15:14 UTC は 6 件。**14 件 消えている。**"
echo "原因が分からないので**当て推量で戻さない。**"
echo
echo "### いま launchctl に載っているもの"
echo '```'
launchctl list 2>/dev/null | awk 'NR==1 || /dailyhack|openclaw/ {print}' | head -30 | mask
echo '```'
echo
echo "### LaunchAgents に plist はあるのに、載っていないもの"
echo '```'
for f in "$HOME/Library/LaunchAgents"/*.plist; do
  [ -f "$f" ] || continue
  b="$(basename "$f" .plist)"
  case "$b" in *dailyhack*|*openclaw*) ;; *) continue ;; esac
  if ! launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$b"; then
    echo "未ロード: $b"
  fi
done | head -25
echo '```'
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'last exit code = 0' "$OUT" 2>/dev/null; then echo "**ポーラーを直した（exit 0）** / $(basename "$OUT")"
elif grep -q 'ロード: \*\*1\*\* 件' "$OUT" 2>/dev/null; then echo "差し替えて再ロードした。exit status は報告を見ること / $(basename "$OUT")"
else echo "**直せていない** / $(basename "$OUT")"; fi
