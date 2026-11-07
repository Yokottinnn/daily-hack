#!/bin/bash
# **tab-guard: ensure-chrome が自動化用 Chrome を終了させて立ち上げ直す約 9 秒の間も止めない（x434）。費用 $0。**
#
# 利用者がダイアログで「立ち上げ直しの 9 秒も止めないようにする」を選んだ（2026-11-07）。
# x430 の印は launch_chrome の直前に書くので、その前の kill_chrome の間（プロセスが消えている）に tab-guard の見回り（30 秒ごと）が
# 当たると、A（プロセスが丸ごと消えた）で ai.openclaw.* を全部外しうる（11/6 は 08:01:06 終了 → 08:01:15 立ち上げの 9 秒）。
#   ① ensure-chrome.sh: 「CDP hang confirmed」のログの直後・kill_chrome の直前にも印を書く
#   ② tab-guard.js: A の haltAutomation の直前で、印から 180 秒以内なら止めずに記録だけして戻る
#   ③ どちらも差し込み口がちょうど 1 か所でなければ止める・構文を確かめてから入れ替える・退避を残す
#   ④ 常駐の tab-guard を立ち上げ直す
# LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。投稿しない・ジョブを外さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; UIDN="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/x434-tab-guard-kill-grace.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
EC="$S/ensure-chrome.sh"; TG="$S/tab-guard.js"
{
echo "# tab-guard: 立ち上げ直しの間も止めない（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① ensure-chrome.sh"; echo '```'
if grep -q 'x434' "$EC"; then echo "もう入っている"; else
  cp "$EC" "$EC.bak-x434"; TMP="$S/.x434-ensure-chrome.sh"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const A="  log \"CDP hang confirmed (${CONFIRM_TRIES} consecutive failures) — 自動化専用 Chrome を再起動\"\n  kill_chrome\n";
const n=s.split(A).length-1; if(n!==1){console.log("差し込み口が "+n+" か所。止める");process.exit(3);}
const B="  log \"CDP hang confirmed (${CONFIRM_TRIES} consecutive failures) — 自動化専用 Chrome を再起動\"\n  # x434（2026-11-07）: 終了させる前にも印を書く。tab-guard はこの間のプロセス消滅で止めない\n  date +%s > \"$HOME/.openclaw/workspace/data/ensure-chrome-restart-at\" 2>/dev/null || true\n  kill_chrome\n";
s=s.replace(A,()=>B); fs.writeFileSync(o,s); console.log("差し込んだ");' "$EC" "$TMP"
  RC=$?
  if [ $RC -eq 0 ] && bash -n "$TMP"; then chmod 755 "$TMP"; mv "$TMP" "$EC"; echo "構文 OK・入れ替えた（退避 ensure-chrome.sh.bak-x434）"
  else rm -f "$TMP"; echo "入れていない（rc=$RC）。止める"; echo '```'; exit 1; fi
fi
grep -n -B1 -A3 'x434' "$EC" | cut -c1-200
echo '```'
echo; echo "## ② tab-guard.js"; echo '```'
if grep -q 'x434' "$TG"; then echo "もう入っている"; else
  grep -q 'function restartAgeSec' "$TG" || { echo "restartAgeSec が無い（x430 が入っていない）。止める"; echo '```'; exit 1; }
  cp "$TG" "$TG.bak-x434"; TMP="$S/.x434-tab-guard.js"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const A="    haltAutomation(\"Jordan の Chrome プロセスが消滅（ウィンドウ全消え）\");";
const n=s.split(A).length-1; if(n!==1){console.log("差し込み口が "+n+" か所。止める");process.exit(3);}
const add=[
"    // x434（2026-11-07）: ensure-chrome が終了させて立ち上げ直している間（約 9 秒）は、プロセスが消えて見える。止めずに記録だけ",
"    { const _rs = restartAgeSec(); if (_rs !== null && _rs >= 0 && _rs < RESTART_GRACE_S) { log(`Chrome のプロセスが見えない。ensure-chrome が ${_rs} 秒前に立ち上げ直しを始めたので、消滅とみなさない（x434）`); return; } }",
""].join("\n");
s=s.replace(A,()=>add+A); fs.writeFileSync(o,s); console.log("差し込んだ");' "$TG" "$TMP"
  RC=$?
  if [ $RC -eq 0 ] && "$NODE_BIN" --check "$TMP" 2>&1; then mv "$TMP" "$TG"; echo "構文 OK・入れ替えた（退避 tab-guard.js.bak-x434）"
  else rm -f "$TMP"; echo "入れていない（rc=$RC）。止める"; echo '```'; exit 1; fi
fi
grep -n 'x434\|haltAutomation(' "$TG" | cut -c1-180
echo '```'
echo; echo "## ④ 常駐している tab-guard を立ち上げ直す"; echo '```'
LB="ai.openclaw.tab-guard"
launchctl kickstart -k "gui/$UIDN/$LB" 2>&1; echo "kickstart rc=$?"
sleep 5
launchctl print "gui/$UIDN/$LB" 2>/dev/null | grep -E '^\s*(state|pid|runs) =' | head -3 | tr -s ' \n' ' '; echo
tail -2 "$W/logs/tab-guard.log" | cut -c1-200
echo '```'
echo; echo "**LLM を呼ばない（\$0／回・\$0／日・\$0／月）。投稿していない。ジョブは外していない。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
