#!/bin/bash
# **tab-guard が、自動化用 Chrome の再起動を「タブの一括破壊」と取り違えないようにする（x430）。費用 $0。**
#
# 利用者がダイアログで「再起動の直後は止めないようにする」を選んだ（2026-11-07）。
# x428: 11/4 05:05:06 と 05:18:31 に ensure-chrome が自動化用 Chrome（18810）を再起動 → 7〜14 秒後に tab-guard が
#       「23→9 枚」「9→1 枚（一括破壊）」で ai.openclaw.* を全部外した。11/4 8:00 の予約投稿もこれで走らなかった。
# x429 でコードを読んだ: ensure-chrome.sh は kill_chrome のあと launch_chrome で立ち上げ直す。tab-guard.js は B（0 枚）と C（半分以上）で止める。
#
#   ① ensure-chrome.sh: launch_chrome の直前に、時刻の印 data/ensure-chrome-restart-at（UNIX 秒）を書く（1 行足すだけ）
#   ② tab-guard.js: 印から 180 秒以内に「タブが減った」ときは、B・C の全停止をしない（ログに理由を残す）。
#      **A（Chrome のプロセスが丸ごと消えた）の停止はそのまま残す。** 状態の保存もいままでどおり
#   ③ 構文を確かめてから入れ替える（退避を残す）。差し込む場所がちょうど 1 か所でなければ止める
#   ④ tab-guard を立ち上げ直して、新しい中身で監視が始まったかをログで見る
# LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。投稿しない・ジョブを外さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; UIDN="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/x430-tab-guard-restart-grace.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
EC="$S/ensure-chrome.sh"; TG="$S/tab-guard.js"
{
echo "# tab-guard: 再起動の直後は止めない（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① ensure-chrome.sh"; echo '```'
if grep -q 'x430' "$EC"; then echo "もう入っている"; else
  cp "$EC" "$EC.bak-x430"; TMP="$S/.x430-ensure-chrome.sh"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const A="\nlaunch_chrome\nif wait_healthy 45; then\n";
const n=s.split(A).length-1; if(n!==1){console.log("差し込み口が "+n+" か所。止める");process.exit(3);}
const add="\n# x430（2026-11-07）: 立ち上げ直す時刻を残す。tab-guard はこの直後のタブの減少を「一括破壊」とみなさない\ndate +%s > \"$HOME/.openclaw/workspace/data/ensure-chrome-restart-at\" 2>/dev/null || true";
s=s.replace(A,()=>add+A); fs.writeFileSync(o,s); console.log("差し込んだ");' "$EC" "$TMP"
  RC=$?
  if [ $RC -eq 0 ] && bash -n "$TMP"; then chmod --reference="$EC" "$TMP" 2>/dev/null || chmod 755 "$TMP"; mv "$TMP" "$EC"; echo "構文 OK・入れ替えた（退避 ensure-chrome.sh.bak-x430）"
  else rm -f "$TMP"; echo "入れていない（rc=$RC）。止める"; echo '```'; exit 1; fi
fi
grep -n -B1 -A3 'x430' "$EC" | cut -c1-200
echo '```'
echo; echo "## ② tab-guard.js"; echo '```'
if grep -q 'x430' "$TG"; then echo "もう入っている"; else
  cp "$TG" "$TG.bak-x430"; TMP="$S/.x430-tab-guard.js"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const A1="function haltAutomation(reason) {";
const A2="  if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {";
for (const a of [A1,A2]) { const n=s.split(a).length-1; if(n!==1){console.log("差し込み口が "+n+" か所: "+a);process.exit(3);} }
const fn=[
"// x430（2026-11-07）: ensure-chrome が自動化用 Chrome を立ち上げ直した時刻（秒）。無ければ null",
"// 立ち上げ直すとタブは必ず減る。それを「一括破壊」と取り違えて ai.openclaw.* を全部外していた（2026-11-04 05:05・05:18）",
"const RESTART_MARK = \"/Users/ny/.openclaw/workspace/data/ensure-chrome-restart-at\";",
"const RESTART_GRACE_S = 180;",
"function restartAgeSec() {",
"  try { const t = parseInt(fs.readFileSync(RESTART_MARK, \"utf8\").trim(), 10); if (!t) return null; return Math.floor(Date.now() / 1000) - t; } catch { return null; }",
"}",
"",
""].join("\n");
s=s.replace(A1,()=>fn+A1);
const guard=[
"  // x430: 立ち上げ直した直後の減少は、破壊ではない。B・C では止めない（A のプロセス消滅は上で別に見ている）",
"  const _rs = restartAgeSec();",
"  if (_rs !== null && _rs >= 0 && _rs < RESTART_GRACE_S && typeof prev.count === \"number\" && now.count < prev.count) {",
"    log(`タブ ${prev.count} → ${now.count} 枚。ensure-chrome が ${_rs} 秒前に自動化用 Chrome を立ち上げ直したので、破壊とみなさない（x430）`);",
"    result.restart_grace = _rs;",
"  }",
"  else if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {"].join("\n");
s=s.replace(A2,()=>guard);
fs.writeFileSync(o,s); console.log("差し込んだ");' "$TG" "$TMP"
  RC=$?
  if [ $RC -eq 0 ] && "$NODE_BIN" --check "$TMP" 2>&1; then mv "$TMP" "$TG"; echo "構文 OK・入れ替えた（退避 tab-guard.js.bak-x430）"
  else rm -f "$TMP"; echo "入れていない（rc=$RC）。止める"; echo '```'; exit 1; fi
fi
grep -n 'x430\|restartAgeSec\|RESTART_GRACE' "$TG" | cut -c1-200
echo '```'
echo; echo "## ④ 常駐している tab-guard を立ち上げ直す（判定を手で 1 回走らせることはしない。条件に当たると全停止するため）"; echo '```'
LB="$(ls "$HOME"/Library/LaunchAgents/ai.openclaw.tab-guard*.plist 2>/dev/null | head -1 | xargs -I{} basename {} .plist)"
echo "ラベル: ${LB:-見つからない}"
if [ -n "$LB" ]; then
  launchctl kickstart -k "gui/$UIDN/$LB" 2>&1; echo "kickstart rc=$?"
  sleep 5
  launchctl print "gui/$UIDN/$LB" 2>/dev/null | grep -E '^\s*(state|pid|runs|last exit code) =' | tr -s ' \n' ' '; echo
  tail -3 "$W/logs/tab-guard.log" | cut -c1-200
fi
echo '```'
echo; echo "**LLM を呼ばない（\$0／回・\$0／日・\$0／月）。投稿していない。ジョブは外していない。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
