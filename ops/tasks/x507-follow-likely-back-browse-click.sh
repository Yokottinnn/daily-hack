#!/bin/bash
# x507（2026-11-15・$0）: bot っぽさをさらに消す。利用者がダイアログで「返ってきやすい相手に絞る」「押す前にタイムラインを眺める」「押す位置とマウスの動きをばらす」を選んだ。
#  ① 競合のフォロワー・ハッシュタグのフォローに FOLLOW_MIN_RATIO=0.7（相手のフォロー数÷フォロワー数が 0.7 未満なら見送る。いままで 0＝絞っていなかった）
#     返信をくれた人・認証済みへのフォロー返しは相手から接点があるので絞らない
#  ② follow-handle.js: まとまりの最初（前のフォロー・解除から 15 分以上あいた）だけ、相手のページの前にホームを 20〜60 秒 スクロールして眺める
#  ③ follow-handle.js: フォロー・いいねのボタンは、ボタンの中のランダムな位置へ、数段に分けてマウスを動かし、間をおいて押す
# LLM を呼ばない。置く前に node --check。通らなければ元に戻す。走っている最中のジョブは触らない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"; PB=/usr/libexec/PlistBuddy; UIDN="$(id -u)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x507-follow-likely-back-browse-click.md"
{
echo "# 返ってきやすい相手に絞る・眺める・押し方をばらす（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① FOLLOW_MIN_RATIO=0.7"
for name in competitor-follower-follow hashtag-follow; do
  LABEL="ai.openclaw.$name"; P="$LA/$LABEL.plist"; echo; echo "### $name"; echo '```'
  if [ ! -f "$P" ]; then echo "plist が無い"; echo '```'; continue; fi
  ST="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')"
  if [ "$ST" = "running" ]; then echo "**いま走っている。触らない**"; echo '```'; continue; fi
  cp -p "$P" "$P.bak-x507"
  echo "変える前: $("$PB" -c "Print :EnvironmentVariables:FOLLOW_MIN_RATIO" "$P" 2>/dev/null || echo 未設定)"
  "$PB" -c "Print :EnvironmentVariables" "$P" >/dev/null 2>&1 || "$PB" -c "Add :EnvironmentVariables dict" "$P"
  "$PB" -c "Set :EnvironmentVariables:FOLLOW_MIN_RATIO 0.7" "$P" 2>/dev/null || "$PB" -c "Add :EnvironmentVariables:FOLLOW_MIN_RATIO string 0.7" "$P"
  if ! plutil -lint "$P" >/dev/null 2>&1; then cp -p "$P.bak-x507" "$P"; echo "**plutil が通らない。元に戻した**"; echo '```'; continue; fi
  launchctl bootout "gui/$UIDN/$LABEL" 2>/dev/null; launchctl bootstrap "gui/$UIDN" "$P" 2>&1 | head -1
  PR="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
  if [ -z "$PR" ]; then echo "**載っていない**"; else echo "載っている ← $(printf '%s\n' "$PR" | grep -aE 'FOLLOW_MIN_RATIO' | tr -s ' \t' ' ')"; fi
  echo '```'
done
echo; echo "## ② ③ follow-handle.js"; echo '```'
F="$S/follow-handle.js"
if grep -q 'x507' "$F"; then echo "もう入っている"; else
cp -p "$F" "$F.bak-x507"
"$NODE_BIN" - "$F" <<'JS'
const fs = require("fs"); const f = process.argv[2]; let s = fs.readFileSync(f, "utf8");
const need = (a) => { const n = s.split(a).length - 1; if (n !== 1) { console.log("目印が " + n + " か所: " + a.slice(0, 60)); process.exit(1); } };
const A1 = "async function main() {";
const A2 = "    const profile = await getProfileData(page, handle);";
const A3 = "    await btn.click();";
const A4 = "await _lk.first().click({ timeout: 5000 });";
[A1, A2, A3, A4].forEach(need);
const helper = `/* x507（2026-11-15）: 押す位置とマウスの動きをばらす。ボタンの中のランダムな位置へ数段に分けて動かし、間をおいて押す */
async function _humanClick(page, el) {
  const r = (a, b) => a + Math.random() * (b - a);
  try {
    await el.scrollIntoViewIfNeeded();
    const b = await el.boundingBox();
    if (!b) return el.click();
    const x = b.x + b.width * r(0.25, 0.75), y = b.y + b.height * r(0.3, 0.7);
    await page.mouse.move(x + r(-120, 120), y + r(-80, 80), { steps: 4 });
    await page.mouse.move(x, y, { steps: Math.round(r(6, 18)) });
    await page.waitForTimeout(r(150, 650));
    await page.mouse.down(); await page.waitForTimeout(r(60, 160)); await page.mouse.up();
  } catch (e) { return el.click(); }
}
/* x507: まとまりの最初（前のフォロー・解除から 15 分以上あいた）だけ、相手のページの前にホームを眺める */
async function _browseHomeIfSessionStart(page) {
  try {
    const L = require("path").join(require("os").homedir(), ".openclaw", "workspace", "data", "x-action-ledger.json");
    const j = JSON.parse(require("fs").readFileSync(L, "utf8"));
    const last = Math.max(0, ...(j.follow || []), ...(j.unfollow || []));
    if (Date.now() - last < 15 * 60000) return;
    await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 20000 });
    const until = Date.now() + 20000 + Math.random() * 40000;
    while (Date.now() < until) { await page.mouse.wheel(0, 250 + Math.random() * 600); await page.waitForTimeout(1500 + Math.random() * 3500); }
    console.error("[x507] ホームを眺めてから相手のページへ");
  } catch (e) { console.error("[x507] 眺める段で失敗（続ける）: " + e.message); }
}

`;
s = s.replace(A1, helper + A1);
s = s.replace(A2, "    await _browseHomeIfSessionStart(page);\n" + A2);
s = s.replace(A3, "    await _humanClick(page, btn);");
s = s.replace(A4, "await _humanClick(page, _lk.first());");
fs.writeFileSync(f, s); console.log("入れた");
JS
if "$NODE_BIN" --check "$F" 2>/dev/null; then echo "node --check 通った（$(wc -l < "$F" | tr -d ' ') 行）"; grep -n '_humanClick\|_browseHome' "$F" | cut -c1-110 | head -6
else cp -p "$F.bak-x507" "$F"; echo "**node --check が通らない。元に戻した**"; fi
fi
echo '```'
echo; echo "**LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '入れた|通った|載っている ←|元に戻した|走っている|目印' "$OUT" | head -6 | cut -c1-140
exit 0
