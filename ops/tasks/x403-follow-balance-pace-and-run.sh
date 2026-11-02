#!/bin/bash
# x403（2026-11-02・$0）: 利用者「もう少し外せないか見てみて　外せる人は外して」。
# x402 で分かったこと: follow-balance は外す間隔の台帳（x-action-pacer）を使っておらず、約 11 秒おきに外していた
# （最上位ルール 23 はフォロー解除 120 秒あけ・30 分 6 回まで）。候補探しは 150 秒で打ち切られ、1 回 6 件しか外せていない。
#   ① 外す直前に台帳で空きを待って記録する（waitTake("unfollow")・最大 35 分。空かなければその回はそこで止める）
#   ② 候補を探す時間 150 → 300 秒、プロフィールを開く上限 40 → 60 件（1 回に外す上限 20 件・猶予 24 時間・守る条件は今のまま）
#   ③ 載せ直して、いま 1 回走らせる（20 件外すと 120 秒あけ・30 分 6 回で 約 1 時間半かかる）
# LLM を呼ばない（1 回 $0）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts/follow-balance.js"; UIDN="$(id -u)"
P="$HOME/Library/LaunchAgents/ai.openclaw.follow-balance.plist"; L="gui/$UIDN/ai.openclaw.follow-balance"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x403-follow-balance-pace-and-run.md"
PACER="$W/lib/x-action-pacer.cjs"; [ -f "$PACER" ] || PACER="$HOME/projects/anta-baka-x/blog/ops/lib/x-action-pacer.cjs"
{
echo "# 比率の調整：外す間隔を決まりに合わせ、候補を広げて、いま走らせる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
echo "pacer: $PACER"; [ -f "$PACER" ] || { echo "pacer が無い。止める"; echo '```'; exit 1; }
if grep -q 'x403' "$S"; then echo "① もう入っている"; else
  cp "$S" "$S.bak-x403"
  TMPJS="$W/scripts/.follow-balance-x403.js"
  X403_PACER="$PACER" "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const anchor="      if (await page.locator(\x27[aria-label$=\"さんのフォローを解除\"]\x27).count()) {";
const n=s.split(anchor).length-1; if(n!==1){console.log("差し込み口が "+n+" 箇所。止める");process.exit(3);}
const add="      // x403: フォロー解除は全ジョブ共有の台帳で 120 秒あけ・30 分 6 回まで（最上位ルール 23）。空くまで待って記録する。空かなければこの回はここまで\n"+
"      { const _r = await require("+JSON.stringify(process.env.X403_PACER)+").waitTake(\"unfollow\", 35 * 60 * 1000); if (!_r.ok) { log(\"  間隔待ちで空かない（\" + _r.reason + \"）。この回はここまで（x403）\"); break; } }\n";
s=s.replace(anchor,add+anchor); fs.writeFileSync(o,s); console.log("① 差し込んだ");' "$S" "$TMPJS"
  if [ $? -eq 0 ] && "$NODE_BIN" --check "$TMPJS" 2>&1; then mv "$TMPJS" "$S"; echo "① 入れた・構文 OK"; else echo "① 構文 NG か差し込み失敗。元のまま。止める"; rm -f "$TMPJS"; echo '```'; exit 1; fi
fi
grep -n 'x403' "$S" | cut -c1-160
echo "--- ② plist"
/usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:DECIDE_BUDGET_S 300" "$P" 2>&1
/usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:MAX_PROFILE_READS 60" "$P" 2>&1
plutil -extract EnvironmentVariables json -o - "$P" 2>/dev/null | head -c 500; echo
echo "--- ③ 載せ直して走らせる"
launchctl bootout "$L" 2>/dev/null
launchctl bootstrap "gui/$UIDN" "$P" 2>&1; echo "bootstrap rc=$?"
launchctl kickstart "$L" 2>&1; echo "kickstart rc=$?"
sleep 8
launchctl print "$L" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | tr -s ' \n' ' '; echo
launchctl print "$L" >/dev/null 2>&1 && echo "**載っている**" || echo "**載っていない**"
echo "--- 台帳のいまの数"
"$NODE_BIN" "$PACER" status 2>&1
echo "--- ほかに外すジョブが台帳を使っているか（読むだけ）"
for f in mutual-prune.js unfollow-handle.js; do printf '%s: ' "$f"; grep -c 'x-action-pacer' "$W/scripts/$f" 2>/dev/null | head -1; done
echo '```'
echo "**LLM を呼ばない（1 回 \$0・1 日 \$0・1 か月 \$0）。結果は次のタスクで読む**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
