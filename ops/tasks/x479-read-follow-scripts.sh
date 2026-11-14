#!/bin/bash
# x479（2026-11-14・読むだけ・$0）: 自動のフォロー・解除を「1 回 1〜2 件・時刻と間隔をランダム・押す係を 1 つ」に作り替える（利用者がダイアログで選んだ）前に、
# 直す箇所のコードと設定を読む。x478 で follow-handle.js は待つだけで記録せず、badge-followback.js は間隔の決まりを通っていないと分かった。何も変えない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"; PB=/usr/libexec/PlistBuddy
OUT="${OPS_REPORT_DIR:-/tmp}/x479-read-follow-scripts.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(token|Token|TOKEN)(["\x27]?\s*[:=]\s*["\x27])[^"\x27]+/$1$2<伏せ>/g'; }
show() { local f="$1" a="$2" b="$3"; echo; echo "### $(basename "$f") の $a〜$b 行"; echo '```js'; sed -n "${a},${b}p" "$f" 2>/dev/null | cut -c1-220 | hide; echo '```'; }
{
echo "# フォローのスクリプトを読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
echo; echo "## 1. follow-handle.js（全行のうち、押す前後）"
F="$S/follow-handle.js"; echo "行数 $(wc -l < "$F" | tr -d ' ')"
N="$(grep -n 'x-action-pacer' "$F" | head -1 | cut -d: -f1)"; [ -n "$N" ] && show "$F" $((N>5?N-5:1)) $((N+12))
grep -nE '\.click\(|follow_btns|data-testid.*follow|process\.argv|console\.log\(JSON' "$F" | head -15 | cut -c1-200 | hide
echo; echo "## 2. unfollow-handle.js（押す前後）"
F="$S/unfollow-handle.js"; echo "行数 $(wc -l < "$F" | tr -d ' ')"
N="$(grep -n 'x-action-pacer' "$F" | head -1 | cut -d: -f1)"; [ -n "$N" ] && show "$F" $((N>5?N-5:1)) $((N+10))
echo; echo "## 3. badge-followback（起動の sh と js）"
echo '```'; cat "$S/run-badge-followback.sh" 2>/dev/null | hide; echo '```'
F="$S/badge-followback.js"; echo "行数 $(wc -l < "$F" | tr -d ' ')"
grep -nE 'MAX|CAP|LIMIT|process\.env|for \(|while|\.click\(|setTimeout|waitForTimeout|followed back' "$F" | head -40 | cut -c1-200 | hide
N="$(grep -n 'followed back' "$F" | head -1 | cut -d: -f1)"; [ -n "$N" ] && show "$F" $((N>30?N-30:1)) $((N+6))
echo; echo "## 4. 1 回あたりの上限と起動の時刻（plist）"
for L in badge-followback competitor-follower-follow comment-warmup hashtag-follow follow-balance mutual-prune reply-followers-cleanup incoming-reply-watcher; do
  P="$LA/ai.openclaw.$L.plist"; [ -f "$P" ] || continue
  echo; echo "### $L"; echo '```'
  echo "時刻: $("$PB" -c 'Print :StartCalendarInterval' "$P" 2>/dev/null | tr -s ' \n' ' ' | cut -c1-300)"
  echo "間隔: $("$PB" -c 'Print :StartInterval' "$P" 2>/dev/null)"
  "$PB" -c 'Print :EnvironmentVariables' "$P" 2>/dev/null | grep -vE 'TOKEN|KEY|SECRET|PASS|NODE_OPTIONS' | tr -s ' ' | head -25
  echo '```'
done
echo; echo "## 5. スクリプトの中の 1 回あたりの上限（既定値）"
echo '```'
grep -nE 'DAILY_CAP|FOLLOW_GAP_MS|MAX_FOLLOW|MAX_PICKS|REPLY_FOLLOW|MIN_UNFOLLOW|MAX_UNFOLLOW|MAX_PER' "$S/competitor-follower-follow.js" "$S/hashtag-follow.js" "$S/comment-orchestrator.sh" "$S/follow-balance.js" "$S/mutual-prune.js" "$S/reply-followers-cleanup.js" 2>/dev/null | head -30 | cut -c1-200 | sed "s#$S/##"
echo '```'
} > "$OUT" 2>&1
grep -c '###' "$OUT" | head -1
exit 0
