#!/bin/bash
# **ポーラーが止まったのか、それとも黙って譲っているのか。証拠を取る。読むだけ。**
#
# ## 症状
#
#   16:44:33 UTC  ops: tasks（1 件）   ← 最後の push
#   16:48        t015 を main へマージ
#   16:59        **t015 はまだ走っていない**（11 分）
#
# ポーラーは 60 秒間隔なので、**10 回以上 素通りしている。**
#
# ## いちばんありそうなのは「ロックの取り残し」
#
# `ops-run-tasks.sh` は `mkdir "$WT/.tasks.lock"` でロックを取り、
# **取れなければ黙って `exit 0`** する（ログも出さない）。
# 何かがロックを握ったまま死ぬと、**取り残しが 30 分（`OPS_TASK_STALE_SEC`）
# 経つまで、毎分 黙って素通りし続ける。**
#
# だから**ロックの mtime を見れば分かる。** これが本命。
#
# ## それ以外の可能性
#
#   - ポーラーが落ちた（`last exit code` を見る）
#   - 実体（`~/.openclaw/bin/ops-run-tasks.sh`）が消えた
#   - `tab-guard` の `pkill -f 'workspace/scripts/.*\.js'` に巻き込まれた
#     （→ ポーラーは `workspace/scripts` の下ではないので、たぶん無関係。**確かめる**）
#
# ## t015 の内容もここで一緒に見る
#
# ポーラーが止まっているなら `t015` も走っていない。**同じ実行で両方 片付ける**
# （遅延 30 分の経路を往復しない。今日の反省）。
#
# **何も変更しない。ロックも消さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
WT="${OPS_HEARTBEAT_WORKTREE:-$HOME/.openclaw/ops-heartbeat-wt}"
OUT="${OPS_REPORT_DIR:-/tmp}/poller-stall-and-lock.md"
LBL="com.dailyhack.ops-poller"
BIN="$HOME/.openclaw/bin/ops-run-tasks.sh"
LOGDIR="$HOME/.openclaw/logs"
TG="$W/scripts/tab-guard.js"
UID_N="$(id -u)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$1" || true; }

{
echo "# ポーラーが素通りしている理由（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> 16:44:33 UTC を最後に \`ops: tasks\` の push が無い。60 秒間隔なので**10 回以上 素通り**。"

echo
echo "## 1. ロックの取り残し（**本命**）"
echo
LOCK="$WT/.tasks.lock"
if [ -e "$LOCK" ]; then
  age="?"
  if [ -f "$LOCK/started_at" ]; then
    s="$(cat "$LOCK/started_at" 2>/dev/null || echo 0)"
    age=$(( $(date +%s) - s ))
  fi
  echo "- **ロックが残っている**: \`$LOCK\`"
  echo "  - 作られた時刻: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$LOCK" 2>/dev/null)"
  echo "  - 経過: **${age} 秒**（\`OPS_TASK_STALE_SEC\` は既定 1800 秒）"
  echo
  if [ "$age" != "?" ] && [ "${age:-0}" -lt 1800 ] 2>/dev/null; then
    echo "🚨 **これが原因。** 取り残しが 1800 秒に達するまで、毎分 黙って素通りする。"
    echo "あと **$((1800 - age)) 秒**で自動的に外れて再開する見込み。"
    echo
    echo "> **設計の穴。** \`ops-run-tasks.sh\` はロックを取れないとき**何も出力しない**ので、"
    echo "> 外から見て「止まっている」のか「譲っている」のか区別できない。"
    echo "> 取り残しの閾値 1800 秒は、1 分間隔のポーラーに対して長すぎる。"
  else
    echo "- 1800 秒を超えているので、次の実行で自動的に外れるはず"
  fi
else
  echo "- ロックは**残っていない**。→ 原因は別。下を見ること"
fi

echo
echo "## 2. ポーラーは生きているか"
echo
echo "- ロード: **$(loaded "$LBL")** 件"
echo "- 実体 \`$BIN\`: $([ -f "$BIN" ] && echo "**ある**（$(wc -c < "$BIN" | tr -d ' ') B）" || echo '**無い** ← これなら 127 で落ち続ける')"
echo '```'
launchctl print "gui/$UID_N/$LBL" 2>&1 | grep -aE 'state|last exit|runs =|program' | head -8 | mask
echo '```'
echo
echo "### ポーラーのログ（末尾）"
echo '```'
echo "-- out ($(stat -f '%Sm' -t '%m-%d %H:%M' "$LOGDIR/ops-poller.out.log" 2>/dev/null)) --"
tail -6 "$LOGDIR/ops-poller.out.log" 2>/dev/null | mask || echo "(なし)"
echo "-- err ($(stat -f '%Sm' -t '%m-%d %H:%M' "$LOGDIR/ops-poller.err.log" 2>/dev/null)) --"
tail -6 "$LOGDIR/ops-poller.err.log" 2>/dev/null | mask || echo "(なし)"
echo '```'

echo
echo "## 3. tab-guard の pkill に巻き込まれていないか"
echo
echo "\`haltAutomation()\` は \`pkill -f 'workspace/scripts/.*\\.js'\` を撃つ。"
echo "**ポーラーの実体は \`~/.openclaw/bin/\` にあり \`workspace/scripts\` の下ではない**ので、"
echo "巻き込まれないはず。**念のため tab-guard の直近ログを見る。**"
echo '```'
tail -6 "$W/logs/tab-guard.log" 2>/dev/null | hide | mask || echo "(ログなし)"
echo '```'

echo
echo "---"
echo
echo "# ここから t015 の内容（停止ロックと、3 件が働いているか）"

echo
echo "## 4. tab-guard の停止ロックは残っているか"
echo
echo '```javascript'
grep -nE 'LOCK\s*=|HALT|lock' "$TG" 2>/dev/null | head -8 | cut -c1-150 | mask
echo '```'
LOCKS="$(grep -oE '"[^"]*lock[^"]*"|`[^`]*lock[^`]*`' "$TG" 2>/dev/null | tr -d '"`' | head -5)"
F=0
for cand in $LOCKS "$W/data/.halt.lock" "$W/data/halt.lock" "$W/.halt" "/tmp/openclaw-halt"; do
  [ -z "$cand" ] && continue
  case "$cand" in /*) p="$cand" ;; *) p="$W/$cand" ;; esac
  if [ -e "$p" ]; then
    echo "- **残っている**: \`$p\`（更新 $(stat -f '%Sm' -t '%m-%d %H:%M' "$p" 2>/dev/null)／中身 \`$(head -c 60 "$p" 2>/dev/null | tr -d '\n' | mask)\`）"
    F=1
  fi
done
[ "$F" = "0" ] && echo "- 候補にロックは**見つからなかった**"

echo
echo "## 5. Chrome とタブ"
echo
pgrep -f 'remote-debugging-port' >/dev/null 2>&1 \
  && echo "- Chrome プロセス: **生きている**" \
  || echo "- Chrome プロセス: **見つからない**"
PORT="$(grep -oE 'USER_PORT\s*=\s*[0-9]+' "$TG" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
if [ -n "$PORT" ]; then
  N="$(curl -s --max-time 5 "http://127.0.0.1:$PORT/json/list" 2>/dev/null | grep -c '"type": *"page"' || echo "?")"
  echo "- **いま開いているタブ: ${N} 枚**（発火時は 19 → 1）"
  if [ "$N" != "?" ] && [ "${N:-0}" -gt 1 ] 2>/dev/null; then
    echo "- ✅ タブは戻っている"
  else
    echo "- ⚠️ **まだ 1 枚以下、または CDP に届かない。** この状態で解除しても再発火する"
  fi
fi

echo
echo "## 6. 戻した 3 件は働いたか"
echo
echo "| ジョブ | ロード | ログの最終更新 |"
echo "| --- | --- | --- |"
for L in ai.openclaw.comment-warmup ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  s="${L#ai.openclaw.}"; lg=""
  for f in "$LOGDIR/$s".*log "$W/logs/$s".*log "$W/logs/$s.log"; do [ -f "$f" ] && lg="$f" && break; done
  echo "| \`$s\` | $(loaded "$L") | ${lg:+$(stat -f '%Sm' -t '%m-%d %H:%M' "$lg" 2>/dev/null)}${lg:-**ログ無し**} |"
done

echo
echo "## 7. 直すなら（**このタスクは直さない**）"
echo
echo "- ロックの取り残しが原因なら、\`OPS_TASK_STALE_SEC\` を **1800 → 300 秒**に縮める"
echo "  （1 分間隔のポーラーに 30 分の取り残し許容は長すぎる）"
echo "- あわせて、**譲ったときに 1 行 ログを出す。** いまは無言なので外から区別できない"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '🚨 \*\*これが原因' "$OUT" 2>/dev/null; then echo "🚨 **ロックの取り残しでポーラーが素通りしていた** / $(basename "$OUT")"
elif grep -q 'ロックは\*\*残っていない\*\*' "$OUT" 2>/dev/null; then echo "ロックは無い。別原因 / $(basename "$OUT")"
else echo "状態を出した / $(basename "$OUT")"; fi
