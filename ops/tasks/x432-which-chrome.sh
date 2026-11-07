#!/bin/bash
# x432（2026-11-07・読むだけ・$0）: tab-guard が見張る Chrome の取り違えを直す方針を決めるため、Mac で動いている Chrome を読む。
# 利用者がダイアログで「見張る Chrome の取り違えを直す方針を決める」を選んだ。
# tab-guard は 18810（自動化専用）を数えている。ensure-chrome の注記では利用者の Chrome は 18800。
# 利用者の Chrome は動いているか・CDP のポートを持っているか・どれだけのジョブが 18800 / 18810 を使うかを読む。
# **何も書き換えない。Chrome に操作しない（AppleScript も使わない＝画面に許可の確認が出ないように）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/x432-which-chrome.md"
{
echo "# Mac で動いている Chrome（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 1. Chrome の本体プロセス（ヘルパーは除く）と、付いている CDP のポート"; echo '```'
ps -axo pid=,lstart=,command= 2>/dev/null | grep -E 'Google Chrome( for Testing)?\.app/Contents/MacOS/' | grep -v ' Helper' | grep -v grep \
 | sed -E 's#--user-data-dir=([^ ]+)#UDD=\1#; s#'"$HOME"'#~#g' | awk '{ port="なし"; if (match($0,/remote-debugging-port=[0-9]+/)) port=substr($0,RSTART+22,RLENGTH-22); udd="既定"; if (match($0,/UDD=[^ ]+/)) udd=substr($0,RSTART+4,RLENGTH-4); app=($0 ~ /for Testing/)?"Chrome for Testing":"Google Chrome"; print "pid " $1 " ／ 起動 " $2" "$3" "$4" "$5 " ／ " app " ／ CDP " port " ／ プロファイル " udd }'
echo '```'
echo; echo "## 2. CDP のポートに聞く（タブ数だけ）"; echo '```'
for p in 18800 18810 9222; do
  r="$(curl -s -m 5 "http://127.0.0.1:$p/json/list" 2>/dev/null)"
  if [ -n "$r" ]; then n="$(printf '%s' "$r" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).filter(t=>t.type==="page").length)}catch(e){console.log("読めない")}})')"; echo "$p: 応答あり・ページ $n 枚"; else echo "$p: 応答なし"; fi
done
echo '```'
echo; echo "## 3. スクリプトと plist が使うポート（数）"; echo '```'
for p in 18800 18810; do
  ns="$(grep -l "$p" "$S"/*.js "$S"/*.sh 2>/dev/null | wc -l | tr -d ' ')"; nl="$(grep -l "$p" "$LA"/*.plist 2>/dev/null | wc -l | tr -d ' ')"
  echo "$p: スクリプト $ns 本 ／ plist $nl 本"
done
echo "--- 18800 を使うスクリプト（名前だけ）"
grep -l 18800 "$S"/*.js "$S"/*.sh 2>/dev/null | xargs -n1 basename 2>/dev/null | head -20
echo '```'
echo; echo "## 4. tab-guard の止めた記録（全期間の回数と、直近 10 回）"; echo '```'
grep -c '自動化を全停止' "$W/logs/tab-guard.log" | head -1 | xargs -I{} echo "全部で {} 回"
grep '自動化を全停止' "$W/logs/tab-guard.log" | tail -10 | cut -c1-140
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
