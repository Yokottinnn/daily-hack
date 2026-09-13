#!/bin/bash
# **`unfollow-handle.js` の実物を読む。直さない。費用 $0。**
#
# ## x53 で判定が出た（2026-09-13 11:0x の実測）
#
#   /following に居る: 3 件 / 居ない: 1 件
#   → **B. フォロー中なのに外せていない。**
#
# ボタンは**在る。**
#
#   [{"testid":"2040770556531011584-unfollow","text":"フォロー中"},
#    {"testid":"1058380986843447296-follow","text":"フォロー"}, ...]
#
# **1 つ目が対象ユーザーの `-unfollow`、2 つ目以降は「おすすめユーザー」欄の `-follow`。**
# x17 で実際に動いた押し方と同じ形なので、**`unfollow-handle.js` 側の探し方が違う。**
#
# ## x09 は答えを出せていない
#
# `playwright`（`-core` ではない）で落ちて、全文を出す前に終わっていた。
#
# ## ルール 15 を守る
#
# **読むだけ。1 分 で終わる。** 直す側は、実物を見てから別タスクにする。
# **推測でセレクタを書き換えない。** どこが違うか分かってから直す。
#
# ## やらないこと
#
# **押さない。アンフォローしない。書き換えない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/read-unfollow-handle.md"
F="$S/unfollow-handle.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# \`unfollow-handle.js\` の実物"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x53 の判定: **B. フォロー中なのに外せていない。**"
echo "> ボタンは在る（\`2040770556531011584-unfollow\` ／「フォロー中」）。"
echo "> **探し方が違う。** 推測で書き換えず、実物を見る。"

echo
echo "## 1. 全文"
echo
echo '```'
if [ ! -f "$F" ]; then
  echo "  **$F が無い。**"
  ls -1 "$S" 2>/dev/null | grep -iE 'unfollow' | sed 's/^/    候補: /'
else
  echo "  $(wc -l < "$F" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$F" 2>/dev/null)"
fi
echo '```'
if [ -f "$F" ]; then
  echo
  echo '```javascript'
  cat "$F" | clean
  echo '```'
fi

echo
echo "## 2. これを呼んでいる側"
echo
echo '```'
for c in reply-followers-cleanup.js reply-followers-cleanup.sh auto_detect_and_unfollow_inactive.js \
         revenge-unfollow.js unfollow-cleanup.js; do
  P="$S/$c"; [ -f "$P" ] || continue
  echo "  [$c] $(wc -l < "$P" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  echo "    --- unfollow-handle の呼び方 ---"
  grep -nE 'unfollow-handle|unfollowHandle|spawn|exec|require' "$P" 2>/dev/null \
    | head -8 | cut -c1-200 | sed 's/^/      /' | clean
  echo
done
echo
echo "  --- scripts/ の unfollow 系 ---"
ls -1 "$S" 2>/dev/null | grep -iE 'unfollow|cleanup' | head -12 | sed 's/^/    /'
echo '```'

echo
echo "## 3. x17 で実際に動いた押し方（比較用）"
echo
echo "\`x17\` はこの形で**外せた。** 差分を見るための基準として置く。"
echo
echo '```javascript'
cat <<'REFEOF'
const btn = await page.evaluate(() => {
  const bs = Array.from(document.querySelectorAll("button,[role=button]"));
  // ① data-testid が *-unfollow で終わる／unfollow で始まる
  for (const b of bs) {
    const t = (b.getAttribute("data-testid") || "");
    if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText||"").trim() };
  }
  // ② 文字が「フォロー中」か "Following"
  for (const b of bs) {
    const x = (b.innerText || "").trim();
    if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid")||"", text: x };
  }
  return null;
});
// 押したあと、**確認ダイアログを必ず確定する**
await page.evaluate(() => {
  const c = document.querySelector("[data-testid=confirmationSheetConfirm]");
  if (c) c.click();
});
REFEOF
echo '```'
echo
echo "**見るところ**"
echo
echo "| 疑うところ | なぜ |"
echo "| --- | --- |"
echo "| 探す範囲を絞っている | \`[data-testid=UserName]\` の中など。**おすすめ欄と混ざるのを避けようとして、本体も外している**かもしれない |"
echo "| 文字が英語だけ | \`Following\` のみで **「フォロー中」を見ていない** |"
echo "| \`-unfollow\` を見ていない | 文字だけで探すと、描画の揺れで外す |"
echo "| 確認ダイアログを確定していない | 押しても**元に戻る** |"
echo "| 待ち時間が短い | プロフィールの描画前に探している |"

echo
echo "## 4. 期限到来は増え続けている"
echo
echo '```'
echo "  2026-09-12 の x09 時点: 197 件（30 日以上 放置が 164 件）"
echo "  2026-09-13 の x53 時点: **322 件**（30 日以上 放置が 223 件）"
echo "  いちばん古い: 2026-05-16"
echo '```'
echo
echo "**外せていないので積み上がっている。** 直せば一気に減る。"
echo "ただし**一度に大量に外さない。** 上限は今のまま（1 回 5 件）で始める。"

echo
echo "## 5. 費用"
echo
echo "**読むだけ。LLM を呼ばない。押さない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "unfollow-handle の実物 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
