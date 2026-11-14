#!/bin/bash
# x481（2026-11-14・$0）: x480 で mutual-prune だけ「走っている最中」で触れなかった（夕方から動いたまま）。
# ① いま走っているか・何分走っているかを見る。60 分を超えていたら固まっているとみなし、このジョブだけ launchctl kill で止める（プロセスグループは撃たない）
# ② 止まっていれば、x480 と同じ設定を入れる: MAX_UNFOLLOW=2・GRACE_DAYS=3・起動の先頭に x-jitter.sh 1500（元は .bak-x481）
# LLM を呼ばない。
set -uo pipefail
LA="$HOME/Library/LaunchAgents"; LIB="$HOME/.openclaw/workspace/lib"; PB=/usr/libexec/PlistBuddy; UIDN="$(id -u)"
L="ai.openclaw.mutual-prune"; P="$LA/$L.plist"; JIT="$LIB/x-jitter.sh"
OUT="${OPS_REPORT_DIR:-/tmp}/x481-mutual-prune-spread.md"
setenv() { if "$PB" -c "Print :EnvironmentVariables:$1" "$P" >/dev/null 2>&1; then "$PB" -c "Set :EnvironmentVariables:$1 $2" "$P"; else "$PB" -c "Add :EnvironmentVariables:$1 string $2" "$P"; fi; }
{
echo "# mutual-prune を散らす（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① いまの状態"; echo '```'
PR="$(launchctl print "gui/$UIDN/$L" 2>/dev/null)"
ST="$(printf '%s\n' "$PR" | awk -F'= ' '/^\tstate =/{print $2; exit}')"; PID="$(printf '%s\n' "$PR" | awk -F'= ' '/^\tpid =/{print $2; exit}')"
echo "state=${ST:-?} pid=${PID:-なし}"
MIN=0
if [ -n "$PID" ]; then
  ET="$(ps -o etime= -p "$PID" 2>/dev/null | tr -d ' ')"; echo "走っている時間: ${ET:-?}"
  MIN="$(printf '%s' "$ET" | awk -F'[-:]' '{ if (NF==4) print $1*1440+$2*60+$3; else if (NF==3) print $1*60+$2; else print $1 }')"
  [ -z "$MIN" ] && MIN=0
  ps -o pid=,etime=,command= -p "$PID" 2>/dev/null | cut -c1-160
  tail -n 5 "$HOME/.openclaw/workspace/logs/mutual-prune.log" 2>/dev/null | cut -c1-180 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
  if [ "$MIN" -ge 60 ]; then
    echo "→ ${MIN} 分。固まっているとみなして、このジョブだけ止める"
    launchctl kill SIGTERM "gui/$UIDN/$L" 2>&1 | head -1; sleep 5
    if ps -p "$PID" >/dev/null 2>&1; then launchctl kill SIGKILL "gui/$UIDN/$L" 2>&1 | head -1; sleep 2; fi
    ps -p "$PID" >/dev/null 2>&1 && echo "**まだ残っている**" || echo "止まった"
  else echo "→ ${MIN} 分。まだ動いている途中とみなして触らない（あとでやり直す）"; fi
fi
echo '```'
echo; echo "## ② 設定を入れる"; echo '```'
ST2="$(launchctl print "gui/$UIDN/$L" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')"
if [ "$ST2" = "running" ]; then echo "**まだ走っている。触らない**"
elif [ ! -f "$P" ]; then echo "plist なし"
else
  cp -p "$P" "$P.bak-x481"
  setenv MAX_UNFOLLOW 2; setenv GRACE_DAYS 3
  if ! "$PB" -c "Print :ProgramArguments" "$P" 2>/dev/null | grep -q 'x-jitter.sh'; then
    "$PB" -c "Add :ProgramArguments:0 string 1500" "$P"; "$PB" -c "Add :ProgramArguments:0 string $JIT" "$P"; "$PB" -c "Add :ProgramArguments:0 string /bin/bash" "$P"
  fi
  if ! plutil -lint "$P" >/dev/null 2>&1; then cp -p "$P.bak-x481" "$P"; echo "**plutil が通らない → 元に戻した**"
  else
    launchctl bootout "gui/$UIDN/$L" 2>/dev/null; BS="$(launchctl bootstrap "gui/$UIDN" "$P" 2>&1)"; echo "bootstrap rc=$? $(printf '%s' "$BS" | cut -c1-80)"
    PR2="$(launchctl print "gui/$UIDN/$L" 2>/dev/null)"
    if [ -z "$PR2" ]; then echo "**載っていない → 元に戻して載せ直す**"; cp -p "$P.bak-x481" "$P"; launchctl bootstrap "gui/$UIDN" "$P" 2>&1 | head -1
    else echo "載っている ← launchd が持っている値:"; printf '%s\n' "$PR2" | grep -aE 'x-jitter|MAX_UNFOLLOW|GRACE_DAYS' | sed 's/^[[:space:]]*/  /'; fi
  fi
fi
echo '```'
} > "$OUT" 2>&1
grep -E '走っている時間|止まった|載っている|触らない|戻した' "$OUT" | head -4 | cut -c1-120
exit 0
