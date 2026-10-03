#!/bin/bash
# **follow-balance.js を 2 か所 直す。外す操作そのものは変えない。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > アンフォローのオペレーションってちゃんと動いてる？
#   → x217・x218 で原因を見せ、「空のページは開き直す」「下調べの間を空ける」を選んでもらった
#   （「直したらすぐ 1 回走らせる」は選ばれていないので、**走らせない**。次の定時 11:45 / 18:45 に効く）
#
# ## 分かっていること（x218）
#
#   * 今日 外せなかった相手のページを開き直すと、**1〜4 秒で「フォロー中」ボタンが出る**
#   * follow-balance が開いたときは**本文 40 文字未満の空のページ**だった（empty:true）
#   * その直前に、下調べでプロフィールを **約 2 分で 40 件** 続けて開いている
#
# ## 直すところ
#
#   ① 外す相手のページ: 開いたあと**プロフィール（UserName）が出るまで最大 15 秒 待つ。出なければ 1 回 開き直して もう 15 秒**
#   ② 下調べ: プロフィールを開くたびの待ちを 2.2 秒 → **4.7〜6.2 秒**に（続けて開きすぎない）
#
# **当たったかは文字列で確かめ、node --check が通らなければ元に戻す。** 控えを残す。
# **ジョブは走らせない。外さない。フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
F="$S/follow-balance.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BAK="$F.bak-x219-$STAMP"
TMP="$S/.follow-balance-x219-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/patch-follow-balance-reload.md"

{
echo "# follow-balance.js を直す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo '```'
if [ ! -f "$F" ]; then echo "  **follow-balance.js が無い**"; echo '```'; exit 1; fi
if grep -q 'x219:' "$F"; then echo "  もう当たっている（x219: の印がある）。何もしない"; echo '```'; exit 0; fi
cp "$F" "$BAK" && printf '  控え: %s\n' "$(basename "$BAK")"
node -e '
const fs = require("fs");
const [src, dst] = process.argv.slice(1);
let s = fs.readFileSync(src, "utf8");
let n1 = 0, n2 = 0;
// ① 外す相手のページ（goto のすぐあとの 1500 待ちの前に、出るまで待つ・開き直す）
s = s.replace(/(await page\.goto\("https:\/\/x\.com\/" \+ h, \{ waitUntil: "domcontentloaded", timeout: 30000 \}\);[ \t]*\r?\n)([ \t]*)(await page\.waitForTimeout\(1500\);)/, (m, a, ind, c) => {
  n1++;
  return a +
    ind + "// x219: 空のページは開き直す（2026-10-03。下調べで続けて開いたあと、本文が空のページが返り 0 件になっていた）\n" +
    ind + "const x219Ready = () => page.waitForSelector(\x27[data-testid=\"UserName\"], [data-testid=\"emptyState\"]\x27, { timeout: 15000 }).then(() => true).catch(() => false);\n" +
    ind + "if (!(await x219Ready())) {\n" +
    ind + "  log(\"  @\" + h + \": ページが空。開き直す\");\n" +
    ind + "  await page.reload({ waitUntil: \"domcontentloaded\", timeout: 30000 }).catch(() => {});\n" +
    ind + "  await x219Ready();\n" +
    ind + "}\n" +
    ind + c;
});
// ② 下調べ（プロフィールを開くたびの待ちを長くする）
s = s.replace(/(await page\.goto\("https:\/\/x\.com\/" \+ handle, \{ waitUntil: "domcontentloaded", timeout: 12000 \}\);[ \t]*\r?\n[ \t]*)await page\.waitForTimeout\(2200\);/, (m, a) => {
  n2++;
  return a + "await page.waitForTimeout(4700 + Math.floor(Math.random() * 1500));   // x219: 続けて開きすぎると X が空のページを返す（2.2 秒 → 4.7〜6.2 秒）";
});
fs.writeFileSync(dst, s);
console.log("  当たった数: ① " + n1 + " ／ ② " + n2);
if (n1 !== 1 || n2 !== 1) process.exit(3);
' "$F" "$TMP"; RC=$?
if [ "$RC" -ne 0 ]; then
  echo "  **当たる場所が 1 か所ずつ見つからない。置かない**（元のまま）"
  rm -f "$TMP"; echo '```'; exit 1
fi
CK="$(node --check "$TMP" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
if [ "$CRC" -ne 0 ]; then echo "  **構文が通らない。置かない**（元のまま）"; rm -f "$TMP"; echo '```'; exit 1; fi
mv "$TMP" "$F"
printf '  置いた。%s 行\n' "$(wc -l < "$F" | tr -d ' ')"
grep -c 'x219:' "$F" | head -1 | sed 's/^/  x219 の印: /'
echo '```'
echo
echo "## 直したあとの該当箇所"
echo
echo '```'
grep -n -B2 -A9 'x219: 空のページは開き直す' "$F" | cut -c1-200
echo
grep -n 'x219: 続けて開きすぎると' "$F" | cut -c1-200
echo '```'
echo
echo "- **ジョブは走らせていない。** 次の定時（11:45 / 18:45）から効く"
echo "- 戻すときは \`$(basename "$BAK")\` を follow-balance.js に戻す"
echo
echo "**外していない。フォローしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q '置いた。' "$OUT" 2>/dev/null; then echo "follow-balance.js を直した（開き直し・間を空ける） / $(basename "$OUT")"
elif grep -q 'もう当たっている' "$OUT" 2>/dev/null; then echo "もう直っていた / $(basename "$OUT")"
else echo "**直せていない。元のまま** / $(basename "$OUT")"; exit 1; fi
