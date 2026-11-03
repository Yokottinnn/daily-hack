#!/bin/bash
# x419（2026-11-04・$0）: 利用者が「mutual-prune に間隔を入れる」を選んだ。
# mutual-prune（相互の整理）は外す間隔の台帳（x-action-pacer）を使っていない（x403 の最後で 0 件と確認）。
# 最上位ルール 23: フォロー解除は全ジョブ合算で 120 秒あけ・30 分 6 回まで。
#   ① 外すボタンを探す行（follow-balance と同じ差し込み口）が **ちょうど 1 か所** のときだけ、その直前に waitTake("unfollow") を入れる
#   ② 1 か所でなければ書き換えない。外す処理の周りの行を出して止める（推測で差し込まない・最上位ルール 20）
#   ③ 書き換えたら構文を確かめて載せ直す（いま走らせはしない。次の定時から効く）
# LLM を呼ばない（1 回 $0）。何も押さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts/mutual-prune.js"; UIDN="$(id -u)"
P="$HOME/Library/LaunchAgents/ai.openclaw.mutual-prune.plist"; L="gui/$UIDN/ai.openclaw.mutual-prune"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x419-mutual-prune-pacer.md"
PACER="$W/lib/x-action-pacer.cjs"; [ -f "$PACER" ] || PACER="$HOME/projects/anta-baka-x/blog/ops/lib/x-action-pacer.cjs"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# mutual-prune に外す間隔の台帳を入れる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
echo "pacer: $PACER"; [ -f "$PACER" ] || { echo "pacer が無い。止める"; echo '```'; exit 1; }
[ -f "$S" ] || { echo "mutual-prune.js が無い: $S"; echo '```'; exit 1; }
echo "--- 外す処理の周り（読むだけ）"
grep -nE 'フォローを解除|unfollow|confirmationSheetConfirm|x-action-pacer|waitTake|sleep|waitForTimeout' "$S" | cut -c1-170 | hide | head -40
if grep -q 'x419' "$S"; then echo "① もう入っている"; else
  cp "$S" "$S.bak-x419"
  TMPJS="$W/scripts/.mutual-prune-x419.js"
  X419_PACER="$PACER" "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
if(/^import /m.test(s)&&!/\brequire\(/.test(s)){console.log("ESM で require が使えない。書き換えない");process.exit(4);}
const lines=s.split("\n");
const hits=lines.map((l,i)=>[l,i]).filter(([l])=>/^\s*if \(await [A-Za-z_]+\.locator\(\x27\[aria-label\$="さんのフォローを解除"\]\x27\)\.count\(\)\) \{\s*$/.test(l));
if(hits.length!==1){console.log("差し込み口が "+hits.length+" 箇所。書き換えない");process.exit(3);}
const [line,idx]=hits[0]; const ind=line.match(/^\s*/)[0];
const loop=/\bfor\s*\(|\bwhile\s*\(/; let inLoop=false; for(let j=idx-1;j>=Math.max(0,idx-60);j--){ if(loop.test(lines[j])){inLoop=true;break;} }
const stop = inLoop ? "break;" : "return;";
const add=[ind+"// x419: フォロー解除は全ジョブ共有の台帳で 120 秒あけ・30 分 6 回まで（最上位ルール 23）。空くまで待って記録する。空かなければこの回はここまで",
 ind+"{ const _r = await require("+JSON.stringify(process.env.X419_PACER)+").waitTake(\"unfollow\", 35 * 60 * 1000); if (!_r.ok) { console.log(\"  間隔待ちで空かない（\" + _r.reason + \"）。この回はここまで（x419）\"); "+stop+" } }"];
lines.splice(idx,0,...add); fs.writeFileSync(o,lines.join("\n")); console.log("① 差し込んだ（"+(idx+1)+" 行目の前・止め方 "+stop+"）");' "$S" "$TMPJS"
  RC=$?
  if [ $RC -eq 0 ] && "$NODE_BIN" --check "$TMPJS" 2>&1; then mv "$TMPJS" "$S"; echo "① 入れた・構文 OK"
  else echo "① 書き換えていない（rc=$RC）。元のまま"; rm -f "$TMPJS"; echo '```'; exit 0; fi
fi
grep -n -A1 'x419' "$S" | cut -c1-200
echo "--- ③ 載せ直す（走らせない）"
if launchctl print "$L" 2>/dev/null | grep -qE '^\s*state = running'; then echo "いま走っている。載せ直さない（次の起動から新しい中身で動く）"
else launchctl bootout "$L" 2>/dev/null; launchctl bootstrap "gui/$UIDN" "$P" 2>&1; echo "bootstrap rc=$?"; fi
launchctl print "$L" >/dev/null 2>&1 && echo "**載っている**" || echo "**載っていない**"
launchctl print "$L" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | tr -s ' \n' ' '; echo
echo '```'
echo "**LLM を呼ばない（1 回 \$0・1 日 \$0・1 か月 \$0）。外す条件・猶予・上限は変えていない**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
