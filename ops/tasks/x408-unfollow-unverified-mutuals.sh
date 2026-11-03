#!/bin/bash
# x408（2026-11-03・$0）: 利用者「未認証の相互は、アンフォローしても影響なさそうなやつは厳選してアンフォローしていいよ」。
# x406: 相互 413 件のうち認証済み 384 件（badge-followback の記録）・未認証で反応なしは最大 29 件。
# x407: follow-balance の相互の段は認証済みのプロフィールまで開いて時間切れになり、外す条件も「休眠」「大きいアカウント」だけだった。
#   ① 記録で認証済みと分かっている相互は、プロフィールを開かずに飛ばす
#   ② 未認証（プロフィールでも確かめる）・反応の記録なし・ホワイトリスト外・フォローして 7 日以上 の相互を外す候補にする（rank 4）
#   ③ いま 1 回走らせる（間隔 120 秒・30 分 6 回・1 回 20 件まで は今のまま）
# LLM を呼ばない（1 回 $0）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts/follow-balance.js"; UIDN="$(id -u)"
L="gui/$UIDN/ai.openclaw.follow-balance"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x408-unfollow-unverified-mutuals.md"
{
echo "# 未認証・反応なしの相互を外す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
if grep -q 'x408' "$S"; then echo "もう入っている"; else
  cp "$S" "$S.bak-x408"
  TMPJS="$W/scripts/.follow-balance-x408.js"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const A="      const why = protectedWhy(h, false);  // ← 相互の段。反応は守る\n      if (why) { noteKeep(why); continue; }\n";
const B="      if (fc !== null && fc >= BIG) { cuts.push({ h, why: \"大きいアカウント \" + fc + \" フォロワー\", rank: 3 }); continue; }\n";
const C="  if (cuts.length < quota) {\n    const dl2 = Date.now() + DECIDE_BUDGET_S * 1000;\n";
for (const [n,a] of [["A",A],["B",B],["C",C]]) { const k=s.split(a).length-1; if(k!==1){console.log("差し込み口 "+n+" が "+k+" 箇所。止める");process.exit(3);} }
s=s.replace(C, C+
"    // x408: 記録で認証済みと分かっている相互（badge-followback）はプロフィールを開かない。未認証の相互に時間を使う\n"+
"    const x408Ver = new Set(); try { const b = JSON.parse(fs.readFileSync(require(\"path\").join(process.env.HOME, \".openclaw/workspace/data/badge-followback-state.json\"), \"utf8\")); for (const x of (b.processed || [])) x408Ver.add(String(x).replace(/^@/, \"\").toLowerCase()); for (const x of (b.followed_back || [])) x408Ver.add(String(x.handle || x).replace(/^@/, \"\").toLowerCase()); } catch (e) {}\n"+
"    var x408Skip = 0;\n");
s=s.replace(A, A+"      if (x408Ver.has(String(h).toLowerCase())) { x408Skip++; continue; }   // x408\n");
s=s.replace(B, B+
"      // x408（2026-11-03 利用者「未認証の相互は、アンフォローしても影響なさそうなやつは厳選してアンフォローしていいよ」）:\n"+
"      // 未認証（いまプロフィールで確かめた）・反応の記録なし（protectedWhy で守っていない）・フォローして 7 日以上 の相互\n"+
"      { const fv = followedMap.get(h) || followedMap.get(String(h).toLowerCase()); const ft = fv && fv.at ? new Date(fv.at).getTime() : null;\n"+
"        if (ft === null || (now - ft) >= 7 * 86400000) { cuts.push({ h, why: \"未認証・反応なしの相互\" + (ft === null ? \"（フォロー日不明）\" : \"（フォローして \" + Math.floor((now - ft) / 86400000) + \" 日）\"), rank: 4 }); continue; } }\n");
s=s.replace("  log(\"プロフィールを開いた: \" + reads + \" 件", "  if (typeof x408Skip !== \"undefined\") log(\"認証済みと記録で分かっていて開かなかった相互: \" + x408Skip + \" 件（x408）\");\n  log(\"プロフィールを開いた: \" + reads + \" 件");
fs.writeFileSync(o,s);console.log("差し込んだ");' "$S" "$TMPJS"
  if [ $? -eq 0 ] && "$NODE_BIN" --check "$TMPJS" 2>&1; then mv "$TMPJS" "$S"; echo "入れた・構文 OK"; else echo "構文 NG か差し込み失敗。元のまま。止める"; rm -f "$TMPJS"; echo '```'; exit 1; fi
fi
grep -n 'x408' "$S" | cut -c1-150
echo "--- いま 1 回走らせる"
launchctl print "$L" >/dev/null 2>&1 || launchctl bootstrap "gui/$UIDN" "$HOME/Library/LaunchAgents/ai.openclaw.follow-balance.plist" 2>&1
st="$(launchctl print "$L" 2>/dev/null | grep -E '^\s*state =' | head -1)"
if echo "$st" | grep -q running; then echo "もう走っている（重ねない）"; else launchctl kickstart "$L" 2>&1; echo "kickstart rc=$?"; fi
sleep 5
launchctl print "$L" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | tr -s ' \n' ' '; echo
echo '```'
echo "**LLM を呼ばない（1 回 \$0・1 日 \$0・1 か月 \$0）。結果は次のタスクで読む**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
