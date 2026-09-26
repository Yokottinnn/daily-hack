#!/bin/bash
# **返信するときに、その投稿へ「いいね」も付ける。費用 $0。**
#
# ## なぜ
#
# 利用者の指示（2026-09-26）。**`x151` で「押していない」ことは確かめた。**
#
#   post-comment.js          いいね関連  0 箇所
#   comment-orchestrator.sh  いいね関連  0 箇所
#   post-via-playwright.js   いいね関連  0 箇所
#   comment-state.js         いいね関連  0 箇所
#
# **`engage-via-playwright.js` には実装が在る**ので、同じタスクで**実物を吐かせる**。
# 当てた中身と突き合わせられるようにしておく（**推測で書いたまま放置しない**）。
#
# ## どこで押すか
#
# **本文を打つ前。** `x150` が入れた「目的の status のページに居るか」の判定の直後なら、
# **対象のツイートがそこに在ることが確定している。**
#
# 送信のあとに足すと、送信経路に手を入れることになる。**投稿の本体は触らない。**
#
# ## 押せなくても返信は止めない
#
# いいねは おまけ。**失敗しても返信は続ける**（`catch` で握り、結果だけ stderr に出す）。
# 逆に `x150` の 3 つのガードは**止めるための仕掛け**なので、そこは触らない。
#
#   `REPLY_LIKE=off` で無効にできる。既定は有効
#   **すでに「いいね」済み（`unlike` が在る）なら押さない**（解除してしまう）
#
# ## やらないこと
#
# **ループを戻さない。投稿しない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
FH="$S/post-comment.js"
REF="$S/engage-via-playwright.js"
TMPJS="$S/.x154-post-comment.js"
PATCHER="$W/.x154-patch.js"
OUT="${OPS_REPORT_DIR:-/tmp}/like-on-reply.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BAK="$FH.bak-$STAMP"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cat > "$PATCHER" <<'PATCHJS'
const fs = require("fs");
const SRC = process.argv[2];
const DST = process.argv[3];
let s = fs.readFileSync(SRC, "utf8");
const fail = (m, extra) => { console.log("FAIL " + m); if (extra) console.log(extra); process.exit(1); };

if (s.includes("x154")) fail("already patched (x154 の印がもう在る)");

// **`x150` が入れた判定の直前に差す。** そこなら対象のツイートが在ることが確定している
const R = /[ \t]*\/\/ --- 2026-09-26 x150: 打つ前に「どこに打つのか」を確かめる ---/;
if (!R.test(s)) {
  const i = s.indexOf("await ta.click()");
  fail("anchor not found (x150 の判定が無い。先に x150 を当てること)",
    i < 0 ? "  ta.click() 自体が無い" :
    "  実際の前後:\n" + s.slice(Math.max(0, i - 300), i + 200).split("\n").map((l) => "    " + l).join("\n"));
}

s = s.replace(R, `    // --- 2026-09-26 x154: 返信する相手の投稿に「いいね」も付ける ---
    // **おまけ。押せなくても返信は止めない。** 止めるのは x150 の 3 つのガードだけ。
    // REPLY_LIKE=off で無効にできる。すでに押してあるなら触らない（解除してしまう）
    if ((process.env.REPLY_LIKE || "on") !== "off") {
      try {
        const _x154art = await page.$('article[data-testid="tweet"]');
        if (!_x154art) {
          console.error("[x154] article が無い。いいねは飛ばす");
        } else if (await _x154art.$('[data-testid="unlike"]')) {
          console.error("[x154] すでに いいね済み。触らない");
        } else {
          const _x154btn = await _x154art.$('[data-testid="like"]');
          if (!_x154btn) {
            console.error("[x154] like ボタンが無い");
          } else {
            await _x154btn.click();
            // **押した結果を見る。** rc も「押せた」も証拠にならない（最上位ルール 13）
            // **page 側で待つ。** ElementHandle.waitForSelector は版で挙動が違う
            const _x154ok = await page.waitForSelector('article[data-testid="tweet"] [data-testid="unlike"]', { timeout: 6000 })
              .then(() => true).catch(() => false);
            console.error("[x154] like " + (_x154ok ? "付いた" : "**付いていない**"));
          }
        }
      } catch (e) {
        console.error("[x154] like で例外（返信は続ける）: " + String((e && e.message) || e).slice(0, 120));
      }
    }

$&`);
fs.writeFileSync(DST, s);
console.log("OK 返信の直前に いいね を差した");
PATCHJS

{
echo "# 返信するときに いいね も付ける（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **ループは戻していない。** 投稿もしていない。"

echo
echo "## 1. 既存の実装（\`engage-via-playwright.js\`）"
echo
echo "**書き方を写す元。** セレクタと待ちに実績がある。"
echo
echo '```javascript'
if [ -f "$REF" ]; then
  grep -n -B3 -A10 -E 'data-testid="like"|"unlike"' "$REF" 2>/dev/null | head -60 | cut -c1-240 | clean | sed 's/^/  /'
else
  echo "  **engage-via-playwright.js が無い**"
fi
echo '```'

echo
echo "## 2. 当てる前"
echo
if [ ! -f "$FH" ]; then
  echo "- **無い: \`$FH\`。止まる。**"
  rm -f "$PATCHER"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'
printf '  行数    : %s\n' "$(wc -l < "$FH" | tr -d ' ')"
printf '  更新     : %s\n' "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$FH" 2>/dev/null)"
printf '  sha256  : %s\n' "$(shasum -a 256 "$FH" 2>/dev/null | awk '{print $1}')"
printf '  x150 が入っているか: %s\n' "$(grep -c 'x150' "$FH" 2>/dev/null | head -1)"
echo '```'

echo
echo "## 3. バックアップ"
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
echo "## 4. パッチ（**目印が無ければ 1 文字も書かずに、その場の中身を吐く**）"
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
echo "## 5. \`node --check\`"
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
echo "## 6. 当てたあと"
echo
echo '```'
printf '  行数    : %s\n' "$(wc -l < "$FH" | tr -d ' ')"
printf '  sha256  : %s\n' "$(shasum -a 256 "$FH" 2>/dev/null | awk '{print $1}')"
printf '  差分    : +%s 行\n' "$(( $(wc -l < "$FH" | tr -d ' ') - $(wc -l < "$BAK" | tr -d ' ') ))"
echo '```'
echo
echo '```diff'
diff -u "$BAK" "$FH" 2>/dev/null | sed -n '1,70p' | clean | sed 's/^/  /'
echo '```'

echo
echo "## 7. まだ確かめていないこと（**正直に書く**）"
echo
echo "| | |"
echo "| --- | --- |"
echo "| 構文 | **通った** |"
echo "| 目印 | **当たった**（外れれば当てずに止まる作り） |"
echo "| **実際に いいねが付くか** | **確かめていない。** ループは止めたまま。X に 1 回も触っていない |"
echo "| セレクタ | \`[data-testid=\"like\"]\` / \`unlike\`。**§1 の実物と突き合わせること** |"
echo
echo "動かすと stderr（\`comment-warmup-err.log\`）に次のどれかが出る。"
echo
echo '```'
echo "  [x154] like 付いた"
echo "  [x154] like **付いていない**      ← セレクタか待ちを見直す"
echo "  [x154] すでに いいね済み。触らない"
echo "  [x154] like ボタンが無い"
echo "  [x154] article が無い。いいねは飛ばす"
echo '```'
echo
echo "戻すとき:"
echo
echo '```bash'
echo "  cp -p \"$BAK\" \"$FH\"        # いいねごと戻る"
echo "  # いいねだけ止めるなら plist に REPLY_LIKE=off を足す"
echo '```'

echo
echo "## 8. 費用"
echo
echo "**いいねは DOM 操作。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "> 返信ループ自体は停止中なので、いまの実額は **\$0**。"
echo "> 戻せば **\$0.081／日・約 \$2.43／月**（2026-09-21 の実測）。**いいねを足しても増えない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'x154] like' "$OUT" 2>/dev/null && grep -q 'rc=0' "$OUT" 2>/dev/null; then
  echo "返信の直前に いいね を入れた / $(basename "$OUT")"
else
  echo "**当たっていない。レポートを確認すること** / $(basename "$OUT")"
fi
