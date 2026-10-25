#!/bin/bash
# **follow-balance.js と mutual-prune.js に、サブスクを出しているアカウントの外し方（アイコン → メニュー）を入れる（x341）。費用 $0。**
#
# ## 原因（x338〜x340 で片思い 1 件を観察した）
#
#   サブスクを出しているアカウントでは、`<id>-unfollow` の印のボタンが「購入する」（サブスク購入）で、押しても外れない。
#   本当に外すのはアイコンのボタン（aria「〇〇さんのフォローを解除」）で、**マウス操作で押すと**メニューが開き、
#   その中の「〇〇さんのフォローを解除」を押すと外れる。JS の click() では開かなかった。
#   10/25 の回は片思い 9 件のうち 2 件しか外せず、比率は 0.640（385/602）まで上がっていた。
#
# ## やること
#
#   ① 2 本を .bak-x341 に控え、押す処理と「外れたか」の判定を 1 箇所ずつ置き換える（1 箇所でなければ触らない）
#   ② node --check で確かめる。通らなければ元に戻す
#   ③ follow-balance をその場で 1 回走らせる（launchctl kickstart。いつもの定時と同じ処理・外すのは上限 20 件まで）。結果は次のタスクで読む
#
# **フォローはしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; UID_N="$(id -u)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-unfollow-subscription.md"
PATCH="$W/.x341-patch.js"
cat > "$PATCH" <<'PJS'
// x341: サブスクを出しているアカウントの外し方（アイコン → メニュー）に対応させる。各ファイル 1 箇所ずつだけ置き換える
const fs = require("fs");
const file = process.argv[2];
let s = fs.readFileSync(file, "utf8");
if (s.includes("x341:")) { console.log("  もう直っている: " + file); process.exit(0); }
const clickRe = /([ \t]*)await page\.evaluate\(\(\) => \{\s*const bs = Array\.from\(document\.querySelectorAll\("button,\[role=button\]"\)\);\s*const t = bs\.find\(\(b\) => \/-unfollow\$\|\^unfollow\/i[\s\S]*?if \(t\) t\.click\(\);\s*\}\);/g;
const afterRe = /([ \t]*)const after = await page\.evaluate\(\(\) => \{\s*const bs = Array\.from\(document\.querySelectorAll\("button,\[role=button\]"\)\);\s*const t = bs\.find\(\(b\) => \/-\(un\)\?follow\$\/i[\s\S]*?\}\);/g;
const c1 = (s.match(clickRe) || []).length, c2 = (s.match(afterRe) || []).length;
if (c1 !== 1 || c2 !== 1) { console.log("  置き換え対象が 1 箇所ずつではない（押す " + c1 + " / 判定 " + c2 + "）。触らない: " + file); process.exit(2); }
s = s.replace(clickRe, (m, ind) => [
  ind + "// x341（2026-10-25）: サブスクを出しているアカウントは「<id>-unfollow」が「購入する」ボタンで、押しても外れない。",
  ind + "// 外すのはアイコンのボタン（aria「〇〇さんのフォローを解除」）→ 出るメニューの「〇〇さんのフォローを解除」。マウス操作で押す（JS の click() では開かない）",
  ind + "if (await page.locator('[aria-label$=\"さんのフォローを解除\"]').count()) {",
  ind + "  await page.locator('[aria-label$=\"さんのフォローを解除\"]').first().click({ timeout: 8000 }).catch(() => {});",
  ind + "  await page.waitForTimeout(1200);",
  ind + "  await page.locator('[role=\"menuitem\"]:has-text(\"さんのフォローを解除\")').first().click({ timeout: 5000 }).catch(() => {});",
  ind + "} else {",
  m.split("\n").map((l) => "  " + l).join("\n"),
  ind + "}"].join("\n"));
s = s.replace(afterRe, (m, ind) => [
  ind + "const after = await page.evaluate(() => {",
  ind + "  // x341: 解除のアイコンが残っていれば外れていない。「購入する」は外す状態の判定に使わない",
  ind + "  if (document.querySelector('[aria-label$=\"さんのフォローを解除\"]')) return \"解除ボタンが残っている\";",
  ind + "  const bs = Array.from(document.querySelectorAll(\"button,[role=button]\")).filter((b) => !/購入する/.test(b.innerText || \"\"));",
  ind + "  const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute(\"data-testid\") || \"\"));",
  ind + "  return t ? ((t.innerText || \"\").trim() || t.getAttribute(\"data-testid\")) : \"-\";",
  ind + "});"].join("\n"));
fs.writeFileSync(file, s);
console.log("  置き換えた（押す 1 / 判定 1）: " + file);
PJS
{
echo "# 外し方の直し（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'
OK=1
for f in follow-balance.js mutual-prune.js; do
  F="$S/$f"; [ -f "$F" ] || { echo "  無い: $f"; OK=0; continue; }
  [ -f "$F.bak-x341" ] || cp "$F" "$F.bak-x341"
  "$NODE_BIN" "$PATCH" "$F"; RC=$?
  if [ "$RC" = "0" ] && "$NODE_BIN" --check "$F" 2>/dev/null; then echo "  node --check OK: $f"; grep -c 'x341' "$F" | sed 's/^/  x341 の行: /'
  else echo "  **$f は直せていない（rc=$RC）。元に戻す**"; cp "$F.bak-x341" "$F"; OK=0; fi
done
echo '```'
rm -f "$PATCH"
echo; echo "## follow-balance をその場で 1 回走らせる"; echo '```'
if launchctl kickstart "gui/$UID_N/ai.openclaw.follow-balance" 2>&1; then echo "  kickstart rc=0（走り始めた。結果は follow-balance.log）"; else echo "  kickstart できない"; fi
launchctl print "gui/$UID_N/ai.openclaw.follow-balance" 2>/dev/null | grep -E '^\s+(state|runs) ' | head -2
echo '```'
echo; echo "**フォローはしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x341 / $(basename "$OUT")"
