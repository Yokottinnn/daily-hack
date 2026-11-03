#!/bin/bash
# x411（2026-11-03・$0）: 利用者が「空振りする相手を枠から外す」を選んだ。
# x410: 候補 20 件のうち、ページが空で押せない 7 件・そもそもフォローしていない 9 件で枠を使い、外れたのは 3 件。
#   ① 候補は最大 40 件まで集め、外れた数が 20 件（1 回の上限・今のまま）になったら止める
#   ② ページが空で「フォロー中」のボタンが読めなかった相手を記録し、7 日以内に 2 回そうなった相手は候補に入れない
#   ③ 走っていなければ、いま 1 回走らせる
# 外す条件・間隔（120 秒・30 分 6 回）は変えない。LLM を呼ばない（1 回 $0）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts/follow-balance.js"; UIDN="$(id -u)"
L="gui/$UIDN/ai.openclaw.follow-balance"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x411-follow-balance-skip-empties.md"
{
echo "# 比率の調整：空振りする相手を枠から外す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
if grep -q 'x411' "$S"; then echo "もう入っている"; else
  cp "$S" "$S.bak-x411"
  TMPJS="$W/scripts/.follow-balance-x411.js"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const SKIP="require(\"path\").join(process.env.HOME, \".openclaw/workspace/data/follow-balance-empty.json\")";
const A="  if (notFollowSet.size) log(\"覚えている未フォロー: \" + notFollowSet.size + \" 件（今回は見ない）\");\n";
const B="          log(\"  @\" + h + \": フォロー中のボタンが無い\" +\n";
const C="  for (const c of cuts) {\n    const h = c.h;\n    try {\n";
for (const [n,a] of [["A",A],["B",B],["C",C]]) { const k=s.split(a).length-1; if(k!==1){console.log("差し込み口 "+n+" が "+k+" 箇所。止める");process.exit(3);} }
const lt=s.split("cuts.length < quota").length-1, ge=s.split("cuts.length >= quota").length-1;
console.log("置き換え: cuts.length < quota "+lt+" 箇所 / cuts.length >= quota "+ge+" 箇所");
if (lt+ge===0) { console.log("候補の上限の箇所が無い。止める"); process.exit(3); }
s=s.split("cuts.length < quota").join("cuts.length < quota * 2").split("cuts.length >= quota").join("cuts.length >= quota * 2");
s=s.replace(A, A+
"  // x411: ページが空で押せなかった相手を、7 日以内に 2 回なら今回は見ない（枠を空振りで使わない）\n"+
"  { let n = 0; try { const j = JSON.parse(fs.readFileSync("+SKIP+", \"utf8\")); const lim = Date.now() - 7 * 86400000; for (const [k, ts] of Object.entries(j)) { if ((ts || []).filter((t) => new Date(t).getTime() > lim).length >= 2) { notFollowSet.add(String(k).toLowerCase()); n++; } } } catch (e) {} if (n) log(\"ページが空で 2 回押せなかった相手: \" + n + \" 件（今回は見ない・x411）\"); }\n");
s=s.replace(B,
"          if (why && why.empty) { try { let j = {}; try { j = JSON.parse(fs.readFileSync("+SKIP+", \"utf8\")); } catch (e) {} const k = String(h).toLowerCase(); j[k] = (j[k] || []).concat(new Date().toISOString()).slice(-5); fs.writeFileSync("+SKIP+", JSON.stringify(j, null, 1)); } catch (e) {} }   // x411\n"+B);
s=s.replace(C, "  for (const c of cuts) {\n    if (done >= quota) { log(\"外れた数が上限 \" + quota + \" 件に届いた。残りの候補は次回（x411）\"); break; }\n    const h = c.h;\n    try {\n");
fs.writeFileSync(o,s);console.log("差し込んだ");' "$S" "$TMPJS"
  if [ $? -eq 0 ] && "$NODE_BIN" --check "$TMPJS" 2>&1; then mv "$TMPJS" "$S"; echo "入れた・構文 OK"; else echo "構文 NG か差し込み失敗。元のまま。止める"; rm -f "$TMPJS"; echo '```'; exit 1; fi
fi
grep -n 'x411\|quota \* 2' "$S" | cut -c1-150
echo "--- 走っていなければ、いま 1 回走らせる"
st="$(launchctl print "$L" 2>/dev/null | grep -E '^\s*state = ' | head -1 | sed -E 's/.*state = //')"
echo "いまの状態: $st"
if [ "$st" = "running" ]; then echo "走っている（重ねない）"; else launchctl kickstart "$L" 2>&1; echo "kickstart rc=$?"; fi
sleep 5
launchctl print "$L" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | head -3 | tr -s ' \n' ' '; echo
echo '```'
echo "**LLM を呼ばない（1 回 \$0・1 日 \$0・1 か月 \$0）。結果は次のタスクで読む**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
