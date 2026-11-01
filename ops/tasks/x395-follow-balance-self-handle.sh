#!/bin/bash
# x395（2026-11-01・$0）: 利用者が「① 比率の調整を止まらなくする」を選んだ。
# follow-balance.js は 自分のハンドルを /home の AppTabBar_Profile_Link から読む。X の画面が描かれないと
# 読めず「何もしない」で終わる（10/31 18:45・本文 0 文字）。読めないときは決まっている自分のハンドルを使う。
# 外す量の判断はこれまでどおりヘッダーの数字（読めなければ外さない＝fail-open）。押すことはしない（コードを直すだけ）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; F="$W/scripts/follow-balance.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x395-follow-balance-self-handle.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 比率の調整：自分のハンドルが読めないときの代わり（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
if [ ! -f "$F" ]; then echo "無い: $F"; echo '```'; exit 1; fi
if grep -q 'x395' "$F"; then echo "もう入っている"; else
  cp "$F" "$F.bak-x395"
  TMPJS="$W/scripts/.follow-balance-x395.js"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const anchor="  if (!me) { let u = \"\", L = -1;";
const i=s.indexOf(anchor); if(i<0){console.log("差し込み口が見つからない");process.exit(3);}
const add="  // x395: 画面が描かれず自分のハンドルが読めないときは、決まっている自分のハンドルを使う（10/31 18:45 に本文 0 文字で止まった）\n"+
"  if (!me) { me = process.env.SELF_HANDLE || \"heng_ji31590\"; log(\"自分のハンドルが画面から読めない → \" + me + \" を使う（x395）\"); }\n";
s=s.slice(0,i)+add+s.slice(i); fs.writeFileSync(o,s); console.log("差し込んだ");' "$F" "$TMPJS"
  rc=$?
  if [ $rc -eq 0 ] && "$NODE_BIN" --check "$TMPJS" 2>&1; then mv "$TMPJS" "$F"; echo "入れた・構文 OK"; else echo "構文 NG か差し込み失敗。元のまま"; rm -f "$TMPJS"; fi
fi
echo "--- 直したところ"
grep -n 'x395' "$F" | cut -c1-200
echo "--- 次に動く時刻（plist の StartCalendarInterval）"
P="$HOME/Library/LaunchAgents/ai.openclaw.follow-balance.plist"
plutil -extract StartCalendarInterval json -o - "$P" 2>/dev/null | head -c 300; echo
launchctl print "gui/$(id -u)/ai.openclaw.follow-balance" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | head -3
echo '```'
echo "**LLM を呼ばない（1 回 \$0・1 日 \$0・1 か月 \$0）。このタスクは外していない・押していない。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
