#!/bin/bash
# **tab-guard: タブの数では止めず、記録だけにする（x433）。費用 $0。**
#
# 利用者がダイアログで「タブの数では止めず、記録だけにする」を選んだ（2026-11-07）。
# x432: 利用者の Google Chrome には CDP のポートが無く、tab-guard から見えない。tab-guard が数えていたのは
#       自動化専用の Chrome（18810）のタブで、自動化が自分でタブを閉じる・ensure-chrome が立ち上げ直すたびに
#       ai.openclaw.* を全部外していた（10/26〜11/6 に 10 回。11/4 8:00 の予約投稿もこれで出なかった）。
# 利用者の Chrome を巻き込まない仕組みは ensure-chrome 側にある（終了させるのは remote-debugging-port=18810 だけ）。
#
#   ① tab-guard.js の B（0 枚になった）と C（半分以上減った）の haltAutomation を、ログに残すだけに置き換える
#      （ちょうど 1 か所ずつでなければ止める・構文を確かめてから入れ替える・退避を残す）
#   ② A（Chrome のプロセスが丸ごと消えた）の停止はそのまま
#   ③ 常駐の tab-guard を立ち上げ直し、新しい中身で監視が始まったかをログで見る
# LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。投稿しない・ジョブを外さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; UIDN="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/x433-tab-guard-log-only.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
TG="$S/tab-guard.js"
{
echo "# tab-guard: タブの数では止めない（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① tab-guard.js"; echo '```'
if grep -q 'x433' "$TG"; then echo "もう入っている"; else
  cp "$TG" "$TG.bak-x433"; TMP="$S/.x433-tab-guard.js"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const pairs=[
 ["    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);\n    result.halted = true;",
  "    // x433（2026-11-07）: 数えているのは自動化専用の Chrome（18810）。利用者の Chrome は見えていない。止めずに記録だけ\n    log(`記録のみ（止めない・x433）: 自動化用 Chrome のタブが ${prev.count} → ${now.count} 枚（0 枚）`);\n    result.tab_drop = true;"],
 ["    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（一括破壊）`);\n    result.halted = true;",
  "    // x433（2026-11-07）: 同上。半分以上減っても止めない\n    log(`記録のみ（止めない・x433）: 自動化用 Chrome のタブが ${prev.count} → ${now.count} 枚（半分以上減った）`);\n    result.tab_drop = true;"]];
for (const [a,b] of pairs) { const n=s.split(a).length-1; if(n!==1){console.log("置き換える場所が "+n+" か所。止める: "+a.slice(0,60));process.exit(3);} s=s.replace(a,()=>b); }
fs.writeFileSync(o,s); console.log("置き換えた（2 か所）");' "$TG" "$TMP"
  RC=$?
  if [ $RC -eq 0 ] && "$NODE_BIN" --check "$TMP" 2>&1; then mv "$TMP" "$TG"; echo "構文 OK・入れ替えた（退避 tab-guard.js.bak-x433）"
  else rm -f "$TMP"; echo "入れていない（rc=$RC）。止める"; echo '```'; exit 1; fi
fi
echo "--- 残っている haltAutomation の呼び出し（A のプロセス消滅だけのはず）"
grep -n 'haltAutomation(' "$TG" | cut -c1-160
echo '```'
echo; echo "## ③ 常駐している tab-guard を立ち上げ直す"; echo '```'
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
