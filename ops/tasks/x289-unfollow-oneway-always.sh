#!/bin/bash
# **片思いは比率に関係なく外す・相互の整理を 1 回 15 件に・いま片思いの整理を走らせる。費用 $0。**
#
# ## 利用者の指摘（2026-10-14）
#
#   > アンフォローの戦略はちゃんと動いている？…けっこうふぉろーされていないのにこちらからフォローしてしまっているアカウントがいたり、
#   > 相互フォローだけど、相手アカウントのフォロワー数がや比率が全然たいしたことなかったり…すごく重要な視点なので、すぐに取り組んで。
#   > 引き続きフォロー数を増やしてフォロバを狙うのも同様に、毎日の動きは絶対に止めないで。
#
# ## x288 で分かった原因
#
#   follow-balance（片思いを外す）は「フォロー中が目標比率を超えた分だけ外す」作り。
#   10/14 18:45 は 225/422＝0.533 で目標 228 件 以内 → **「外さない」で終わっていた**（片思いが残る）。
#   mutual-prune（釣り合いの悪い相互）は動いているが 1 回 8 件・1 日 2 回で、候補 53 件に追いついていない。
#
# ## 直すこと
#
#   ① follow-balance.js: 目標以内でも **片思い（猶予 24 時間を過ぎて返っていない）は毎回 上限まで外す**（上限 MAX_UNFOLLOW=20 は据え置き）。
#      下限（目標−0.15）を割ったら外さない歯止めは残す
#   ② mutual-prune の plist: MAX_UNFOLLOW 8 → 15
#   ③ follow-balance をいま kickstart する（launchd・ops から切り離される）
#   **フォローのジョブ（competitor / hashtag / badge-followback）には触らない。毎日の動きは止めない。**
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/unfollow-oneway-always.md"
PATCH="$W/.x289-patch.js"
cat > "$PATCH" <<'PATCHJS'
const fs = require("fs");
const { execFileSync } = require("child_process");
const p = process.argv[2] + "/follow-balance.js";
let src = fs.readFileSync(p, "utf8");
if (src.includes("x289")) { console.log(JSON.stringify({ ok: true, note: "もう当たっている" })); process.exit(0); }
let lines = src.split("\n");
const needle = "quota = Math.min(MAXN, Math.max(0, hdr.following - targetN));";
const hits = lines.map((l, i) => l.includes(needle) ? i : -1).filter((i) => i >= 0);
if (hits.length !== 1) { console.log(JSON.stringify({ ok: false, error: "対象の行が " + hits.length + " 行" })); process.exit(0); }
const i = hits[0], ind = lines[i].match(/^\s*/)[0];
lines.splice(i, 1,
  ind + "// 2026-10-14 x289: 片思い（猶予を過ぎて返っていない）は比率に関係なく毎回 上限まで外す（利用者の指摘）。",
  ind + "// 比率が目標以内でも片思いを残さない。目標を超えていれば、その分も同じ上限の中で外す",
  ind + "quota = MAXN;");
fs.copyFileSync(p, p + ".bak-x289");
fs.writeFileSync(p, lines.join("\n"));
const chk = process.argv[2] + "/.x289-check-follow-balance.js";
fs.copyFileSync(p, chk);
try { execFileSync(process.execPath, ["--check", chk], { stdio: "pipe" }); console.log(JSON.stringify({ ok: true, note: "書いた・node --check 通過" })); }
catch (e) { fs.copyFileSync(p + ".bak-x289", p); console.log(JSON.stringify({ ok: false, error: "node --check に落ちたので戻した " + String(e.stderr || e.message).slice(0, 200) })); }
finally { try { fs.unlinkSync(chk); } catch {} }
PATCHJS
{
echo "# 片思いは比率に関係なく外す・相互の整理を 1 回 15 件に（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## ① follow-balance.js"
echo '```json'
cd "$W" && node "$PATCH" "$S" 2>&1 | tail -2
echo '```'
grep -n -A2 "x289" "$S/follow-balance.js" | head -6
echo
echo "## ② mutual-prune の 1 回の上限"
PL="$HOME/Library/LaunchAgents/ai.openclaw.mutual-prune.plist"
cp "$PL" "$PL.bak-x289"
/usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:MAX_UNFOLLOW 15" "$PL" 2>&1 | head -1
launchctl bootout "gui/$(id -u)/ai.openclaw.mutual-prune" >/dev/null 2>&1; sleep 2
launchctl bootstrap "gui/$(id -u)" "$PL" 2>&1 | head -1
echo '```'
launchctl print "gui/$(id -u)/ai.openclaw.mutual-prune" 2>&1 | grep -E "state =|MAX_UNFOLLOW|MUTUAL_RATIO_CUT" | head -3
echo '```'
echo
echo "## ③ follow-balance をいま走らせる"
echo '```'
if grep -q "x289" "$S/follow-balance.js"; then
  launchctl kickstart "gui/$(id -u)/ai.openclaw.follow-balance" 2>&1 | head -1; echo "kickstart rc=$?"
  sleep 5; launchctl print "gui/$(id -u)/ai.openclaw.follow-balance" 2>&1 | grep -E "state =|runs =|pid =" | head -3
else echo "パッチが当たっていないので走らせない"; fi
echo '```'
echo
echo "## フォロー側は止めていない"
echo '```'
for L in competitor-follower-follow hashtag-follow badge-followback; do printf '%s: ' "$L"; launchctl print "gui/$(id -u)/ai.openclaw.$L" 2>&1 | grep -m1 "state =" | tr -d '\t'; done
echo '```'
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 戻すときは follow-balance.js.bak-x289 と plist の .bak-x289。結果は次のタスクで読む。"
} > "$OUT" 2>&1
rm -f "$PATCH"
echo "片思いは比率に関係なく外すようにし、いま走らせた / $(basename "$OUT")"
