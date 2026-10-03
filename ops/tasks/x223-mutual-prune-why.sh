#!/bin/bash
# **mutual-prune が外せない理由と、18 時の回が走らない理由を読む。読むだけ。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > 相互フォローでこっそりフォローを外せそうな人はいる？／定期的にフォローを外すように指示していたつもりだけどちゃんと動いてる？
#   → x222 の結果を見せ、「外せない理由を読む」「18 時の回が走らない理由を調べる」を選んでもらった
#
# x222 で分かったこと:
#   * 9/22 を最後に 1 件も外せていない。候補は 10/1 に 6 件・10/2 に 7 件 出ているのに「0 件 外した」
#   * 設定は 6 時と 18 時なのに、ログの start は毎日 1 回（05:03 前後 JST）だけ
#   * 23:02 の時点で launchctl が state=running（何が走っているのか）
#
#   ① 直近 3 回の「外す候補」から「done」までの行（なぜ外せなかったか）
#   ② mutual-prune.js の外す部分（ボタンの探し方・待ち方）
#   ③ launchd の詳細（pid・その process の開始時刻・runs・最後の終了・stdout/stderr の場所と末尾）
#   ④ plist の全体（定時・環境変数）と、Mac の眠り・目覚めの記録（18 時前後）
#
# **外さない。フォローしない。設定を変えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs/mutual-prune.log"
LABEL="ai.openclaw.mutual-prune"
PL="$HOME/Library/LaunchAgents/$LABEL.plist"
UIDN="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/mutual-prune-why.md"
mask() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#"/[A-Za-z0-9_]{2,15}"#"/<伏せ>"#g; s#x\.com/[A-Za-z0-9_]{2,15}#x.com/<伏せ>#g; s#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }

{
echo "# mutual-prune が外せない理由・18 時に走らない理由（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "## ① 直近 3 回の「外す候補」〜「done」"
echo
echo '```'
if [ -f "$L" ]; then
  D="$(awk '!s[$0]++' "$L")"
  for ln in $(printf '%s\n' "$D" | grep -n '外す候補:' | tail -3 | cut -d: -f1); do
    end="$(printf '%s\n' "$D" | tail -n +"$ln" | grep -n 'mutual-prune done' | head -1 | cut -d: -f1)"
    [ -z "$end" ] && end=40
    printf '%s\n' "$D" | sed -n "${ln},$(( ln + end - 1 ))p" | head -40 | cut -c1-220 | mask | sed 's/^/  /'
    echo "  ----"
  done
else
  echo "  **ログが無い**"
fi
echo '```'
echo
echo "## ② mutual-prune.js の外す部分"
echo
echo '```'
F="$S/mutual-prune.js"
if [ -f "$F" ]; then
  a="$(grep -n 'for (const d of cuts' "$F" | head -1 | cut -d: -f1)"
  if [ -n "$a" ]; then sed -n "${a},$(( a + 60 ))p" "$F" | cut -c1-200 | mask; else grep -n -E 'unfollow|confirmationSheet|waitFor|goto' "$F" | head -30 | cut -c1-200 | mask; fi
else
  echo "  **mutual-prune.js が無い**"
fi
echo '```'
echo
echo "## ③ launchd の詳細"
echo
echo '```'
pr="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
printf '%s\n' "$pr" | grep -E '^\s(state|pid|runs|last exit code|stdout path|stderr path|program|working directory) =|event triggers|run interval|StartCalendarInterval|Hour|Minute' | head -20 | sed 's/^/  /'
pid="$(printf '%s' "$pr" | awk -F'= ' '/^\tpid =/{print $2; exit}')"
if [ -n "$pid" ]; then
  echo
  echo "  --- いま走っている process（pid $pid）"
  ps -o pid,lstart,etime,command -p "$pid" 2>/dev/null | cut -c1-200 | mask | sed 's/^/  /'
  echo "  --- その子"
  ps -Ao pid,ppid,etime,command 2>/dev/null | awk -v p="$pid" '$2==p' | cut -c1-200 | mask | sed 's/^/  /'
fi
for k in "stdout path" "stderr path"; do
  f="$(printf '%s' "$pr" | awk -F'= ' -v k="$k" '$0 ~ "\t"k" =" {print $2; exit}')"
  [ -n "$f" ] && [ -f "$f" ] && { printf '\n  --- %s: %s（%s bytes・更新 %s）末尾 12 行\n' "$k" "$f" "$(wc -c < "$f" | tr -d ' ')" "$(stat -f '%Sm' -t '%m/%d %H:%M' "$f")"; tail -12 "$f" | cut -c1-200 | mask | sed 's/^/    /'; }
done
echo '```'
echo
echo "## ④ plist と、Mac の眠り・目覚め"
echo
echo '```'
plutil -p "$PL" 2>/dev/null | mask | sed 's/^/  /' | head -50
echo
echo "  --- 眠り・目覚め（直近 3 日の 17〜19 時と 4〜7 時）"
pmset -g log 2>/dev/null | grep -E ' (Sleep|Wake|DarkWake) ' | grep -E ' (0[4-7]|1[7-9]):[0-9]{2}:' | tail -24 | cut -c1-140 | sed 's/^/  /'
echo
echo "  --- いまの眠りの設定"
pmset -g 2>/dev/null | grep -E 'sleep|standby|powernap|autorestart' | sed 's/^/  /'
echo '```'
echo
echo "**外していない。フォローしていない。設定を変えていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -aq '## ④' "$OUT"; then echo "mutual-prune の理由を読んだ / $(basename "$OUT")"; else echo "**読めていない** / $(basename "$OUT")"; fi
