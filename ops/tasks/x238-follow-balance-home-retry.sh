#!/bin/bash
# **follow-balance.js の「自分のハンドルを読む」ところで、空のページなら開き直す。費用 $0。**
#
# ## 何が起きたか（2026-10-04 18:11）
#
#   ダイアログで「いまもう 1 回外す」を選んでもらい x236 で走らせたが、開始 4 秒で
#     **自分のハンドルが読めない。何もしない。**
#   で終わった。ログインは切れていない（URL が login に飛んでいない・heartbeat の cdp も auth も正常）。
#   /home を開いて **3 秒 固定で待つだけ** なので、ページが出切る前に読んでいる。
#   外す相手のページ・下調べのページは x219 / x224 で「空のページは開き直す」にしてあるが、ここだけ残っていた。
#
# ## 直すところ（1 か所）
#
#   ① /home を開いたあと: プロフィールへのリンクが出るまで最大 15 秒 待つ。出なければ 1 回 開き直して もう 15 秒
#   ② それでも読めないときは、**開いていた URL とページの文字数をログに出す**（次に理由を読めるように）
#
# 当たったかを文字列で確かめ、node --check が通らなければ置かない。控えを残す。
# **ジョブは走らせない（x239 で走らせる）。外さない。フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
F="$S/follow-balance.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BAK="$F.bak-x238-$STAMP"
TMP="$S/.follow-balance-x238-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-home-retry.md"

{
echo "# follow-balance.js: 自分のハンドルを読むところで開き直す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo '```'
if [ ! -f "$F" ]; then echo "  **follow-balance.js が無い**"; echo '```'; exit 1; fi
if grep -q 'x238:' "$F"; then echo "  もう当たっている（x238: の印がある）。何もしない"; echo '```'; exit 0; fi
cp "$F" "$BAK" && printf '  控え: %s\n' "$(basename "$BAK")"
node -e '
const fs = require("fs");
const [src, dst] = process.argv.slice(1);
let s = fs.readFileSync(src, "utf8");
let n1 = 0, n2 = 0;
// ① /home のあとの 3 秒 固定待ち
s = s.replace(/(await page\.goto\("https:\/\/x\.com\/home", \{ waitUntil: "domcontentloaded", timeout: 30000 \}\);[ \t]*\r?\n)([ \t]*)await page\.waitForTimeout\(3000\);/g, (m, a, ind) => {
  n1++;
  return a +
    ind + "// x238: プロフィールへのリンクが出るまで待つ。出なければ 1 回 開き直す（3 秒 固定では空のページを読んでいた）\n" +
    ind + "{ const ok = () => page.waitForSelector(\x27[data-testid=AppTabBar_Profile_Link]\x27, { timeout: 15000 }).then(() => true).catch(() => false);\n" +
    ind + "  if (!(await ok())) { log(\"/home が空。開き直す\"); await page.reload({ waitUntil: \"domcontentloaded\", timeout: 30000 }).catch(() => {}); await ok(); } }";
});
// ② 読めなかったときに URL と文字数を出す
const A2 = `if (!me) { log("**自分のハンドルが読めない。何もしない。**");`;
const k = s.split(A2).length - 1;
if (k === 1) {
  s = s.replace(A2, `if (!me) { let u = "", L = -1; try { u = page.url(); L = await page.evaluate(() => (document.body && document.body.innerText || "").length); } catch (e) {} log("**自分のハンドルが読めない。何もしない。**（x238: url=" + u + " 文字数=" + L + "）");`);
  n2 = 1;
} else n2 = k === 0 ? 0 : -k;
fs.writeFileSync(dst, s);
console.log("  当たった数（1 なら当たり）: ① " + n1 + " ／ ② " + n2);
if (n1 !== 1 || n2 !== 1) process.exit(3);
' "$F" "$TMP"; RC=$?
if [ "$RC" -ne 0 ]; then echo "  **当たる場所が 1 か所ずつ見つからない。置かない**（元のまま）"; rm -f "$TMP"; echo '```'; exit 1; fi
CK="$(node --check "$TMP" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
if [ "$CRC" -ne 0 ]; then echo "  **構文が通らない。置かない**（元のまま）"; rm -f "$TMP"; echo '```'; exit 1; fi
mv "$TMP" "$F"
printf '  置いた。%s 行 ／ x238 の印 %s 個\n' "$(wc -l < "$F" | tr -d ' ')" "$(grep -c 'x238' "$F" | head -1)"
echo '```'
echo
echo "## 直したあとの該当箇所"
echo
echo '```'
grep -n -A3 'x238: プロフィールへのリンク' "$F" | cut -c1-200
grep -n 'x238: url=' "$F" | cut -c1-200
echo '```'
echo
echo "- 戻すときは \`$(basename "$BAK")\` を follow-balance.js に戻す"
echo
echo "**走らせていない。外していない。フォローしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q '置いた。' "$OUT"; then echo "follow-balance.js の /home 読みを直した / $(basename "$OUT")"
elif grep -q 'もう当たっている' "$OUT"; then echo "もう直っていた / $(basename "$OUT")"
else echo "**直せていない。元のまま** / $(basename "$OUT")"; exit 1; fi
