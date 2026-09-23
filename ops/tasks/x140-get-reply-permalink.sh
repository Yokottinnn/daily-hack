#!/bin/bash
# **出し直した [2/2] の本当の URL を取る。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# **利用者に渡していたリンクが古かった。**
#
#   2102732550989115457  ← 1 回目に run-publish.sh が返した ID。**実在しない**
#
# `x139` が出し直した返信は**別の ID** を持つが、`x139` のプローブは
# **ID を記録していなかった**（ぶら下がっている数と画像の枚数しか見ていない）。
# そのため**存在しないリンクを渡したまま「出ています」と報告した。**
#
# ## 取るもの
#
#   * 返信の**本当の permalink**（これが無いと利用者が確認できない）
#   * **ログアウト状態でも見えるか**（見えないなら出ていないのと同じ）
#
# ログイン済みの Chrome でしか見えないなら、**第三者には出ていない。**
# 通常のコンテキストと**シークレット相当（新しいブラウザコンテキスト）**の両方で見る。
#
# **投稿しない。読むだけ。** LLM を呼ばない（$0）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-permalink.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.x140-probe.js"   # **$TMPDIR に置かない**（playwright-core が解決できない）
T1="2102732457930064353"
ME="heng_ji31590"

secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }

cat > "$PROBE" <<'PROBEJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const [t1, me] = process.argv.slice(2);

async function look(ctx, label) {
  const r = { view: label, replies: [] };
  const page = await ctx.newPage();
  try {
    await page.goto("https://x.com/" + me + "/status/" + t1,
      { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(7000);
    const arts = await page.$$('article[data-testid="tweet"]');
    r.articles = arts.length;
    for (const a of arts) {
      // **その article 自身の permalink を取る。** time 要素の親 a が投稿へのリンク
      const t = await a.$('time');
      let href = null;
      if (t) { const p = await t.evaluateHandle((e) => e.closest("a")); href = p ? await p.evaluate((e) => e && e.getAttribute("href")) : null; }
      const txt = await a.$('[data-testid="tweetText"]');
      r.replies.push({
        href,
        photos: await a.$$eval('[data-testid="tweetPhoto"]', (n) => n.length).catch(() => -1),
        head: txt ? (await txt.innerText()).split("\n")[0].slice(0, 24) : null,
      });
    }
  } catch (e) { r.error = String(e.message).slice(0, 130); }
  await page.close().catch(() => {});
  return r;
}

(async () => {
  const out = [];
  let browser;
  try {
    browser = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    // ① いつもの（ログイン済み）
    out.push(await look(browser.contexts()[0], "logged-in"));
    // ② **新しいコンテキスト = cookie なし。第三者が見るのと同じ**
    try {
      const anon = await browser.newContext();
      out.push(await look(anon, "logged-out"));
      await anon.close().catch(() => {});
    } catch (e) { out.push({ view: "logged-out", error: String(e.message).slice(0, 130) }); }
  } catch (e) { out.push({ fatal: String(e.message).slice(0, 160) }); }
  console.log(JSON.stringify(out, null, 1));
  if (browser) await browser.close().catch(() => {});
})();
PROBEJS

{
echo "# 出し直した [2/2] の本当の URL を取る（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **利用者に渡していたリンクが古かった。** \`2102732550989115457\` は"
echo "> **1 回目に失敗したときの ID** で実在しない。出し直した返信は別の ID を持つ。"
echo "> **ログアウト状態でも見えるか**も一緒に見る。見えないなら第三者には出ていない。"
echo
echo '```json'
cd "$W" && "$NODE_BIN" "$PROBE" "$T1" "$ME" 2>&1 | head -60 | secrets
echo '```'
echo
echo "---"
echo
echo "## 読み方"
echo
echo "- \`logged-in\` と \`logged-out\` で **\`articles\` の数が違えば**、"
echo "  **第三者には返信が見えていない**（＝出ていないのと同じ）"
echo "- 2 件目の \`href\` が **本当の permalink**。\`https://x.com\` を前に付ける"
echo "- \`photos\` が 1 なら画像は付いている"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

rm -f "$PROBE"
[ -f "$OUT" ] && { secrets < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '"href"' "$OUT" 2>/dev/null; then
  echo "返信の permalink とログアウト時の見え方を取った / $(basename "$OUT")"
else
  echo "**取れていない。レポート全文を読むこと** / $(basename "$OUT")"
fi
