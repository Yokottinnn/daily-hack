#!/bin/bash
# **返信を打つ前に「どこに打つのか」と「打てたか」を確かめる。費用 $0。**
#
# ## 直す対象（`x145` / `x149` で確定したこと）
#
#   本文  「シも今年は結局満額いったわ😉」  ← **先頭 2 文字「アタ」が欠落**
#   親    （なし）                          ← **返信のつもりが単独投稿になった**
#
# `x149` が読んだ実物（`post-comment.js`）。
#
#    96    await ta.click();
#    97    await page.waitForTimeout(400);     ← **400ms の固定待ち**
#   100    await page.keyboard.type(text, { delay: 4 });
#
# **`x136`（自分が 9/23 に当てた画像添付）は無関係だった。**
# `if (imagePaths.length)` のガードが在り、画像が無い経路は丸ごと飛ばしている。
#
# ## 足すのは 3 つ。全部「送る前に止まる」側
#
# | # | 何を見るか | どの症状を止めるか |
# | --- | --- | --- |
# | ① | **打つ直前に、目的の status のページに居るか** | **親が付かない**（ページが離れていれば単独投稿になる） |
# | ② | **click のあと、本当にフォーカスが載ったか** | **先頭の欠落**（400ms の固定待ちをやめる） |
# | ③ | **打った文字列と、欄の中身が一致するか** | **両方。** 違えば送らない |
#
# **③ だけでも、今回の投稿は出ていない。** 一致しなければ `exit 1` で止まる。
#
# ## ③ が厳しすぎたら、それはそれで分かる
#
# 絵文字や末尾の扱いで取りこぼすと、**投稿が減る側に外れる**（出てしまう側ではない）。
# そのときレポートに `want_head` / `got_head` が出るので、**推測せずに緩められる。**
#
# ## 直す前に確かめること
#
# **目印の文字列が 1 つでも違えば、1 文字も書かずに止まり、その場の中身を吐く。**
# `x149` の grep で見た行をそのまま目印にしている。
#
# ## やらないこと
#
# **ループを戻さない**（直っても戻すのは別の判断）。**投稿しない。LLM も呼ばない（$0）。**
#
# ## Linux 側で先に回した結果（**Mac で確かめたことにはならない**・最上位ルール 14）
#
#   パッチ適用     OK（3 箇所すべて当たった）
#   node --check  OK
#   二重適用       FAIL already patched で止まる
#
# **踏んだ穴**: 目印をベタ書きの文字列にしたら **インデント違いで空振りした。**
# 正規表現に変えた。空振りしたときに前後を吐く経路は狙いどおり働いた。
#
# **③ の突き合わせを単体で回した結果**（今回の事故と、誤検知しやすい形）。
#
#   通す    同一                                  (want 16 / got 16)
#   止める  **先頭 2 文字が落ちた（今回の事故）**   (want 16 / got 14)
#   通す    末尾に改行が付いた                     (want 16 / got 16)
#   通す    ゼロ幅が混ざった                       (want 16 / got 16)
#   止める  空                                    (want 16 / got 0)
#
# **今回の投稿は止まる。末尾の改行とゼロ幅では止まらない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
FH="$S/post-comment.js"
TMPJS="$S/.x150-post-comment.js"
PATCHER="$W/.x150-patch.js"
OUT="${OPS_REPORT_DIR:-/tmp}/guard-reply-composer.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BAK="$FH.bak-$STAMP"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cat > "$PATCHER" <<'PATCHJS'
const fs = require("fs");
const SRC = process.argv[2];
const DST = process.argv[3];
let s = fs.readFileSync(SRC, "utf8");
const notes = [];
const fail = (m, extra) => {
  console.log("FAIL " + m);
  if (extra) console.log(extra);
  process.exit(1);
};

if (s.includes("x150")) fail("already patched (x150 の印がもう在る)");

// --- ① ② 打つ直前 ---
// **インデントで空振りしないよう正規表現で当てる**（Linux の試しで literal が外れた）
const R1 = /[ \t]*await ta\.click\(\);[ \t]*\r?\n[ \t]*await page\.waitForTimeout\(400\);/;
if (!R1.test(s)) {
  const idx = s.indexOf("await ta.click()");
  fail("anchor 1 not found (ta.click + waitForTimeout(400))",
    idx < 0 ? "  ta.click() 自体が無い" :
    "  実際の前後:\n" + s.slice(Math.max(0, idx - 200), idx + 260).split("\n").map(l => "    " + l).join("\n"));
}
s = s.replace(R1, `    // --- 2026-09-26 x150: 打つ前に「どこに打つのか」を確かめる ---
    // 2026-09-25 に、返信のつもりが単独投稿になり、しかも先頭 2 文字が落ちた
    // （「アタシも…」→「シも…」）。原因は 2 つとも ここに在った。
    //   ① ページが目的の status から離れていても、そのまま打っていた
    //   ② click の後 400ms 待つだけで、フォーカスが載る前に delay:4 で打ち始めていた
    const _x150want = String(targetUrl || "").match(/status\\/(\\d+)/);
    if (_x150want && !page.url().includes(_x150want[1])) {
      out({ ok: false, step: "wrong-page", error: "返信先のページに居ない: url=" + page.url().slice(0, 120) });
      process.exit(1);
    }
    await ta.click();
    // **400ms の固定待ちをやめる。** カーソルが本当に載るまで待つ
    const _x150focus = await page.waitForFunction(() => {
      const a = document.activeElement;
      return !!a && a.getAttribute && a.getAttribute("contenteditable") === "true";
    }, { timeout: 8000 }).catch(() => null);
    if (!_x150focus) {
      out({ ok: false, step: "no-focus", error: "入力欄にフォーカスが載らない（打たずに止まる）" });
      process.exit(1);
    }`);
notes.push("① 目的のページに居るかを見る / ② フォーカスが載るまで待つ");

// --- ③ 送る直前 ---
const R2 = /[ \t]*step = "arm-response-listener";/;
const M2 = s.match(R2);
if (!M2) fail('anchor 2 not found (step = "arm-response-listener")');
const A2 = M2[0];
s = s.replace(R2, `    // --- 2026-09-26 x150: 打った文字列と欄の中身が一致するかを見る ---
    // **一致しなければ送らない。** 先頭が落ちたまま出たのが、ここで止まる。
    // 厳しすぎて取りこぼすときは **投稿が減る側に外れる**（出てしまう側ではない）。
    // そのとき want_head / got_head が出るので、推測せずに緩められる。
    {
      const _got = await page.evaluate(() => {
        const t = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
        return t ? (t.innerText || t.textContent || "") : "";
      });
      const _norm = (v) => String(v).replace(/\\u200b/g, "").replace(/\\s+$/g, "");
      if (_norm(_got) !== _norm(text)) {
        out({
          ok: false, step: "text-mismatch",
          error: "欄の中身が打った文と違う。送らない",
          want_len: [..._norm(text)].length,
          got_len: [..._norm(_got)].length,
          want_head: _norm(text).slice(0, 12),
          got_head: _norm(_got).slice(0, 12),
        });
        process.exit(1);
      }
    }

${A2}`);
notes.push("③ 打った文と欄の中身を突き合わせ、違えば送らない");

fs.writeFileSync(DST, s);
console.log("OK " + notes.join(" / "));
PATCHJS

{
echo "# 返信を打つ前と送る前に確かめる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **ループは戻していない。** 直ったかどうかと、戻すかどうかは別の判断。"

echo
echo "## 0. 当てる前"
echo
if [ ! -f "$FH" ]; then
  echo "- **無い: \`$FH\`。止まる。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'
printf '  行数    : %s\n' "$(wc -l < "$FH" | tr -d ' ')"
printf '  更新     : %s\n' "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$FH" 2>/dev/null)"
printf '  sha256  : %s\n' "$(shasum -a 256 "$FH" 2>/dev/null | awk '{print $1}')"
echo '```'
echo
echo "> \`x149\` の時点は **292 行 / 更新 2026-09-23 21:06:40**。"

echo
echo "## 1. バックアップ"
echo
cp -p "$FH" "$BAK" 2>/dev/null
if [ -f "$BAK" ]; then
  echo '```'
  printf '  %s  (%s bytes)\n' "$(basename "$BAK")" "$(wc -c < "$BAK" | tr -d ' ')"
  echo '```'
else
  echo "- **バックアップが取れなかった。止まる。**"
  rm -f "$PATCHER"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 2. パッチ（**目印が違えば 1 文字も書かずに、その場の中身を吐く**）"
echo
echo '```'
PRES="$(node "$PATCHER" "$FH" "$TMPJS" 2>&1)"
PRC=$?
printf '%s\n' "$PRES" | clean | sed 's/^/  /'
printf '  rc=%s\n' "$PRC"
echo '```'
if [ "$PRC" -ne 0 ] || [ ! -f "$TMPJS" ]; then
  echo
  echo "- **当てていない。元のファイルは 1 文字も変わっていない。**"
  rm -f "$TMPJS" "$PATCHER"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 3. \`node --check\`（**通らなければ当てない**）"
echo
echo '```'
CHK="$(node --check "$TMPJS" 2>&1)"
CRC=$?
printf '  rc=%s\n' "$CRC"
[ -n "$CHK" ] && printf '%s\n' "$CHK" | clean | sed 's/^/  /'
echo '```'
if [ "$CRC" -ne 0 ]; then
  echo
  echo "- **構文が通らない。当てずに終わる。元のファイルはそのまま。**"
  rm -f "$TMPJS" "$PATCHER"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

mv "$TMPJS" "$FH"
rm -f "$PATCHER"

echo
echo "## 4. 当てたあと"
echo
echo '```'
printf '  行数    : %s\n' "$(wc -l < "$FH" | tr -d ' ')"
printf '  sha256  : %s\n' "$(shasum -a 256 "$FH" 2>/dev/null | awk '{print $1}')"
printf '  差分    : +%s 行\n' "$(( $(wc -l < "$FH" | tr -d ' ') - $(wc -l < "$BAK" | tr -d ' ') ))"
echo '```'
echo
echo "入った 3 箇所（**行番号と目印だけ**）:"
echo
echo '```javascript'
grep -n "x150\|wrong-page\|no-focus\|text-mismatch\|waitForFunction" "$FH" 2>/dev/null | cut -c1-200 | clean | sed 's/^/  /'
echo '```'
echo
echo "**\`waitForTimeout(400)\` が残っていないか**（残っていれば当たっていない）:"
echo
echo '```'
n="$(grep -c 'waitForTimeout(400)' "$FH" 2>/dev/null | head -1)"
case "$n" in ''|*[!0-9]*) n=0 ;; esac
printf '  waitForTimeout(400) : %s 箇所\n' "$n"
echo '```'

echo
echo "## 5. 差分（**入れたところだけ**）"
echo
echo '```diff'
diff -u "$BAK" "$FH" 2>/dev/null | sed -n '1,120p' | clean | sed 's/^/  /'
echo '```'

echo
echo "## 6. まだ確かめていないこと（**正直に書く**）"
echo
echo "| | |"
echo "| --- | --- |"
echo "| 構文 | **通った**（\`node --check\`） |"
echo "| 目印 | **3 箇所すべて当たった**（外れれば当てずに止まる作り） |"
echo "| **実際に返信が出るか** | **確かめていない。** ループは止めたまま。X に 1 回も触っていない |"
echo "| ③ が厳しすぎないか | **未検証。** 絵文字・末尾の扱いで取りこぼす可能性がある |"
echo
echo "**戻す前に 1 回、手で 1 件だけ走らせて確かめるのが筋。**"
echo "取りこぼすなら \`text-mismatch\` が出るので、\`want_head\` / \`got_head\` で緩め方が分かる。"
echo
echo "戻すとき:"
echo
echo '```bash'
echo "  cp -p \"$BAK\" \"$FH\""
echo '```'

echo
echo "## 7. 費用"
echo
echo "**ファイルを書き換えて構文を検査しただけ。LLM を呼んでいない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "> ループは停止中なので、返信の課金は **\$0 のまま**。"
echo "> 戻せば **\$0.081／日・約 \$2.43／月** に戻る（2026-09-21 の実測）。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'text-mismatch' "$OUT" 2>/dev/null && grep -q 'rc=0' "$OUT" 2>/dev/null; then
  echo "返信の打ち込みに 3 つのガードを入れた / $(basename "$OUT")"
else
  echo "**当たっていない。レポートを確認すること** / $(basename "$OUT")"
fi
