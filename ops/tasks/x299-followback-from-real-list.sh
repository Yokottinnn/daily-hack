#!/bin/bash
# **フォロー返しの対象を「処理済みの記録」ではなく「認証済みフォロワーの一覧の実物」で決める。1 日 3 回に。いま 1 回走らせる。費用 $0。**
#
# 利用者（2026-10-15）: 「ブルーバッジのタイミングでフォローしてくれた認証済みアカウントをちゃんとフォロバしてる？ すぐアンフォローされちゃうよ」
# x296: 認証済みフォロワー 210 人中 **43 人をフォロー返ししていない**。
# x298 で分かった原因:
#   ① ボタンを押す前に processed に入れるので、押せなかった相手は二度と試されない
#   ② 導入時の baseline で、その時点の認証済みフォロワーを（フォローせずに）全員 processed にした
# 直すこと:
#   ① badge-followback.js: /verified_followers を読み、ボタンが「フォロー（-follow）」の人を毎回 候補に足す（記録より実物を優先）
#      1 回の上限 FOLLOWBACK_MAX_PER_RUN（既定 25。凍結の危険を抑える）
#   ② 定時 00:50 に 08:50・16:20 を足す（他のフォロー・アンフォローのジョブと重ならない）
#   ③ いま kickstart（launchd で走るので、このタスクはすぐ終わる）
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/followback-from-real-list.md"
L="ai.openclaw.badge-followback"; PL="$HOME/Library/LaunchAgents/$L.plist"
PATCH="$W/.x299-patch.js"
cat > "$PATCH" <<'PATCHJS'
const fs = require("fs");
const { execFileSync } = require("child_process");
const p = process.argv[2] + "/badge-followback.js";
let src = fs.readFileSync(p, "utf8");
if (src.includes("x299")) { console.log(JSON.stringify({ ok: true, note: "もう当たっている" })); process.exit(0); }
let lines = src.split("\n");
const one = (needle) => { const h = lines.map((l, i) => l.includes(needle) ? i : -1).filter((i) => i >= 0); if (h.length !== 1) throw new Error("「" + needle + "」を含む行が " + h.length + " 行"); return h[0]; };
try {
  // ① 一覧の実物から「まだフォローしていない認証済みフォロワー」を集める
  let i = one("const verifiedFollowers = [...map.entries()]");
  let ind = lines[i].match(/^\s*/)[0];
  const add = [
    "// 2026-10-16 x299: 対象は「処理済みの記録」ではなく一覧の実物で決める（利用者の指摘・43 人が返し漏れ）。",
    "// 押す前に processed に入れていたため、押せなかった相手と baseline で記録だけした相手が二度と試されなかった",
    "const notFollowing = new Set();",
    "try {",
    "  await page.goto(`https://x.com/${X_USERNAME}/verified_followers`, { waitUntil: \"domcontentloaded\", timeout: 30000 });",
    "  await page.waitForSelector('[data-testid=\"UserCell\"]', { timeout: 15000 });",
    "  const seenVF = new Set(); let still = 0;",
    "  for (let k = 0; k < 40 && still < 4; k++) {",
    "    const rows = await page.evaluate(() => [...document.querySelectorAll('[data-testid=\"UserCell\"]')].map((c) => {",
    "      const a = [...c.querySelectorAll('a[href^=\"/\"]')].map((x) => x.getAttribute(\"href\")).find((h) => /^\\/[A-Za-z0-9_]{1,15}$/.test(h));",
    "      const b = c.querySelector('button[data-testid$=\"-follow\"], button[data-testid$=\"-unfollow\"]');",
    "      const t = b ? b.getAttribute(\"data-testid\") : \"\";",
    "      return [a ? a.slice(1) : null, t.endsWith(\"-follow\")];",
    "    }));",
    "    const before = seenVF.size;",
    "    for (const [h, nf] of rows) { if (!h) continue; seenVF.add(h); if (nf) notFollowing.add(h); }",
    "    still = seenVF.size === before ? still + 1 : 0;",
    "    await page.evaluate(() => window.scrollBy(0, 2500)); await page.waitForTimeout(1500);",
    "  }",
    "  log(`verified_followers: 読めた ${seenVF.size} 人 / まだフォローしていない ${notFollowing.size} 人`);",
    "} catch (e) { log(`verified_followers を読めなかった（記録だけで続ける）: ${e.message}`); }",
  ].map((x) => ind + x);
  lines.splice(i + 1, 0, ...add);
  // ② 候補 = 記録に無い人 ＋ 一覧で未フォローの人。1 回の上限つき
  i = one("const candidates = verifiedFollowers.filter((h) => !processed.has(h));");
  ind = lines[i].match(/^\s*/)[0];
  lines.splice(i, 1,
    ind + "// x299: 一覧で未フォローの人を必ず足す。1 回の上限 FOLLOWBACK_MAX_PER_RUN（既定 25）",
    ind + "const MAX_PER_RUN = Number(process.env.FOLLOWBACK_MAX_PER_RUN || 25);",
    ind + "const candidates = [...new Set([...notFollowing, ...verifiedFollowers.filter((h) => !processed.has(h))])].filter((h) => h.toLowerCase() !== String(X_USERNAME).toLowerCase()).slice(0, MAX_PER_RUN);");
} catch (e) { console.log(JSON.stringify({ ok: false, error: e.message })); process.exit(0); }
fs.copyFileSync(p, p + ".bak-x299");
fs.writeFileSync(p, lines.join("\n"));
const chk = process.argv[2] + "/.x299-check-badge-followback.js";
fs.copyFileSync(p, chk);
try { execFileSync(process.execPath, ["--check", chk], { stdio: "pipe" }); console.log(JSON.stringify({ ok: true, note: "書いた・node --check 通過" })); }
catch (e) { fs.copyFileSync(p + ".bak-x299", p); console.log(JSON.stringify({ ok: false, error: "node --check に落ちたので戻した " + String(e.stderr || e.message).slice(0, 200) })); }
finally { try { fs.unlinkSync(chk); } catch {} }
PATCHJS
add_time() {  # $1=hour $2=minute
  if plutil -extract StartCalendarInterval json -o - "$PL" 2>/dev/null | grep -q "\"Hour\":$1,\"Minute\":$2\|\"Minute\":$2,\"Hour\":$1"; then return; fi
  local n; n="$(plutil -extract StartCalendarInterval json -o - "$PL" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).length)')"
  /usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:$n dict" -c "Add :StartCalendarInterval:$n:Hour integer $1" -c "Add :StartCalendarInterval:$n:Minute integer $2" "$PL"
}
{
echo "# フォロー返しを一覧の実物で決める・1 日 3 回（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## ① badge-followback.js"
echo '```json'
cd "$W" && node "$PATCH" "$S" 2>&1 | tail -2
echo '```'
rm -f "$PATCH"
if grep -q "x299" "$S/badge-followback.js"; then
  echo
  echo "## ② 定時"
  cp "$PL" "$PL.bak-x299"
  if pgrep -f "badge-followback.js" >/dev/null 2>&1; then echo "**走っている最中なので、定時の追加は次のタスクに回す**"; else
    add_time 8 50; add_time 16 20
    launchctl bootout "gui/$(id -u)/$L" >/dev/null 2>&1; sleep 2
    launchctl bootstrap "gui/$(id -u)" "$PL" 2>&1 | head -1
    echo '```'
    echo "定時: $(plutil -extract StartCalendarInterval json -o - "$PL")"
    launchctl print "gui/$(id -u)/$L" 2>&1 | grep -m1 "state =" | tr -d '\t'
    echo '```'
    echo
    echo "## ③ いま 1 回走らせる"
    echo '```'
    launchctl kickstart "gui/$(id -u)/$L" 2>&1 | head -1; echo "kickstart rc=$?"
    sleep 4; launchctl print "gui/$(id -u)/$L" 2>&1 | grep -E "state =|pid =" | tr -d '\t' | head -2
    echo '```'
  fi
else
  echo "**パッチが当たっていないので、定時も起動も触っていない。**"
fi
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 戻すときは badge-followback.js.bak-x299 と plist の .bak-x299。結果は次のタスクで読む。"
} > "$OUT" 2>&1
echo "フォロー返しを一覧の実物で決め、1 日 3 回にして走らせた / $(basename "$OUT")"
