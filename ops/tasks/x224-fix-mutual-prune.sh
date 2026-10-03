#!/bin/bash
# **mutual-prune.js を直し、居座っている処理を止める。外す操作そのものは変えない。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > 相互フォローでこっそりフォローを外せそうな人はいる？／定期的にフォローを外すように指示していたつもりだけどちゃんと動いてる？
#   → x222・x223 の結果を見せ、「空のページは開き直す」「終わったら必ず終了させる」「居座っている処理を止める」を選んでもらった
#   （「直したらすぐ 1 回走らせる」は選ばれていないので、**走らせない**。次の定時から効く）
#
# ## 分かっていること（x223）
#
#   * 外す相手のページを開いて 3.5 秒 待つだけなので、空のページで「フォロー中のボタンが無い」→ 9/22 以降 0 件
#   * 調べもの（プロフィールを読む）も空のページで「フォロワー数が読めない」が多い
#   * 最後に `page.close()` するだけで **node が終了しない**（CDP の接続が残る）。10/3 05:03 の処理が 18 時間 残り、
#     launchd は「まだ走っている」と見て 18 時の回を飛ばす → 1 日 1 回 しか走らない
#
# ## 直すところ
#
#   ① 外す相手のページ: プロフィールが出るまで最大 15 秒 待つ。出なければ 1 回 開き直して もう 15 秒
#   ② 調べもの: プロフィールが出るまで最大 12 秒 待つ（出なければ 1 回 開き直す）。そのあとの待ちを 3.5 秒 → 3.5〜5 秒
#   ③ 終わり: 書き終えたら **1 秒後に process.exit**（落ちたときも同じ）
#   ④ いま居座っている mutual-prune.js（1 時間以上 走っているもの）を止める
#
# **当たったかを文字列で確かめ、node --check が通らなければ元に戻す。** 控えを残す。
# **ジョブは走らせない。外さない。フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
F="$S/mutual-prune.js"
LABEL="ai.openclaw.mutual-prune"
UIDN="$(id -u)"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BAK="$F.bak-x224-$STAMP"
TMP="$S/.mutual-prune-x224-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-mutual-prune.md"

{
echo "# mutual-prune.js を直す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "## ④ 居座っている処理を止める"
echo
echo '```'
pr="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
pid="$(printf '%s' "$pr" | awk -F'= ' '/^\tpid =/{print $2; exit}')"
if [ -n "$pid" ]; then
  ps -o pid,lstart,etime,command -p "$pid" 2>/dev/null | cut -c1-160 | sed 's/^/  /'
  et="$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')"
  # etime は [[dd-]hh:]mm:ss。1 時間以上（hh: を含む）なら止める
  if printf '%s' "$et" | grep -q -E '^([0-9]+-)?[0-9]+:[0-9]+:[0-9]+$' && ps -o command= -p "$pid" | grep -q 'mutual-prune.js'; then
    kill -TERM "$pid" 2>/dev/null; sleep 3
    kill -0 "$pid" 2>/dev/null && { kill -KILL "$pid" 2>/dev/null; sleep 1; }
    pr2="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
    printf '  止めた。いま: state=%s pid=%s\n' "$(printf '%s' "$pr2" | awk -F'= ' '/^\tstate =/{print $2; exit}')" "$(printf '%s' "$pr2" | awk -F'= ' '/^\tpid =/{print $2; exit}')"
  else
    echo "  走り始めて 1 時間 未満か、mutual-prune.js ではない。止めない（etime=$et）"
  fi
else
  echo "  居座っている処理は無い"
fi
echo '```'
echo
echo "## ①〜③ mutual-prune.js を直す"
echo
echo '```'
if [ ! -f "$F" ]; then echo "  **mutual-prune.js が無い**"; echo '```'; exit 1; fi
if grep -q 'x224:' "$F"; then echo "  もう当たっている（x224: の印がある）。何もしない"; echo '```'; exit 0; fi
cp "$F" "$BAK" && printf '  控え: %s\n' "$(basename "$BAK")"
node -e '
const fs = require("fs");
const [src, dst] = process.argv.slice(1);
let s = fs.readFileSync(src, "utf8");
let n1 = 0, n2 = 0, n3 = 0;
const ready = (ind, who, sec) =>
  ind + "// x224: 空のページは開き直す（2026-10-03。空のページで「ボタンが無い」「フォロワー数が読めない」になっていた）\n" +
  ind + "{ const ok = () => page.waitForSelector(\x27[data-testid=\"UserName\"], [data-testid=\"emptyState\"]\x27, { timeout: " + sec + "000 }).then(() => true).catch(() => false);\n" +
  ind + "  if (!(await ok())) { log(\"  @\" + " + who + " + \": ページが空。開き直す\"); await page.reload({ waitUntil: \"domcontentloaded\", timeout: 30000 }).catch(() => {}); await ok(); } }\n";
// ① 外す相手（+ h,）
s = s.replace(/(await page\.goto\("https:\/\/x\.com\/" \+ h, \{ waitUntil: "domcontentloaded", timeout: 30000 \}\);[ \t]*\r?\n)([ \t]*)await page\.waitForTimeout\(3500\);/, (m, a, ind) => {
  n1++; return a + ready(ind, "h", 15) + ind + "await page.waitForTimeout(1500);";
});
// ② 調べもの（+ handle,）
s = s.replace(/(await page\.goto\("https:\/\/x\.com\/" \+ handle, \{ waitUntil: "domcontentloaded", timeout: 30000 \}\);[ \t]*\r?\n)([ \t]*)await page\.waitForTimeout\(3500\);/, (m, a, ind) => {
  n2++; return a + ready(ind, "handle", 12) + ind + "await page.waitForTimeout(3500 + Math.floor(Math.random() * 1500));   // x224: 続けて開きすぎない";
});
// ③ 終わりに必ず終了する
s = s.replace(/(\r?\n)\}\)\(\)\.catch\(\(e\) => \{ log\(/, (m, nl) => {
  n3++;
  return nl + "  setTimeout(() => process.exit(0), 1000);   // x224: page.close() だけでは node が終わらず、次の定時を飛ばしていた\n" +
         "})().catch((e) => { setTimeout(() => process.exit(1), 1000); log(";
});
fs.writeFileSync(dst, s);
console.log("  当たった数: ① " + n1 + " ／ ② " + n2 + " ／ ③ " + n3);
if (n1 !== 1 || n2 !== 1 || n3 !== 1) process.exit(3);
' "$F" "$TMP"; RC=$?
if [ "$RC" -ne 0 ]; then
  echo "  **当たる場所が 1 か所ずつ見つからない。置かない**（元のまま）"
  rm -f "$TMP"; echo '```'; exit 1
fi
CK="$(node --check "$TMP" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
if [ "$CRC" -ne 0 ]; then echo "  **構文が通らない。置かない**（元のまま）"; rm -f "$TMP"; echo '```'; exit 1; fi
mv "$TMP" "$F"
printf '  置いた。%s 行 ／ x224 の印 %s 個\n' "$(wc -l < "$F" | tr -d ' ')" "$(grep -c 'x224:' "$F" | head -1)"
echo '```'
echo
echo "## 直したあとの該当箇所"
echo
echo '```'
grep -n -A3 'x224: 空のページは開き直す' "$F" | cut -c1-200 | sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'
grep -n 'x224: 続けて開きすぎない\|x224: page.close' "$F" | cut -c1-200
tail -3 "$F" | cut -c1-200
echo '```'
echo
echo "- **ジョブは走らせていない。** 次の定時（6 時 / 18 時）から効く"
echo "- 戻すときは \`$(basename "$BAK")\` を mutual-prune.js に戻す"
echo
echo "**外していない。フォローしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q '置いた。' "$OUT"; then echo "mutual-prune.js を直した / $(basename "$OUT")"
elif grep -q 'もう当たっている' "$OUT"; then echo "もう直っていた / $(basename "$OUT")"
else echo "**直せていない。元のまま** / $(basename "$OUT")"; exit 1; fi
