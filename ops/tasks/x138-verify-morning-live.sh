#!/bin/bash
# **出した 2 本が X 上で本当にどうなっているかを見る。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# `x137` は `x_tweet_id` を返したが、**[2/2] に画像が付いているかはキューからは分からない。**
# `post-comment.js` は添付を確認してから送っているが、**確認したのは合成前の DOM** で、
# **X 側が実際にメディアを付けたかは別の話。**
#
# **一次情報は投稿 URL の実物**（最上位ルール 11）。だから見に行く。
#
# ## 見るもの
#
#   * 2 本とも実在するか（404 でないか）
#   * **[1/2] に画像が無いこと**（「↓↓」で切る形なので、付いていたら失敗）
#   * **[2/2] に画像が 1 枚 付いていること**
#   * スレッドとして繋がっているか
#
# **読むだけ。投稿しない。** LLM を呼ばない（$0）。ハンドルは伏せる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/verify-morning-live.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
HEALTH="$W/scripts/cdp-health.js"
T1="2102732457930064353"
T2="2102732550989115457"
PROBE="${TMPDIR:-/tmp}/.x138-probe.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

cat > "$PROBE" <<'PROBEJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
(async () => {
  const out = [];
  let browser;
  try {
    browser = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const ctx = browser.contexts()[0];
    for (const id of process.argv.slice(2)) {
      const page = await ctx.newPage();
      const r = { id, ok: false };
      try {
        await page.goto("https://x.com/heng_ji31590/status/" + id,
          { waitUntil: "domcontentloaded", timeout: 25000 });
        await page.waitForTimeout(5000);
        const art = await page.$('article[data-testid="tweet"]');
        if (!art) { r.error = "article が出ない（404 か読み込み失敗）"; out.push(r); await page.close(); continue; }
        r.ok = true;
        // **その投稿のメディアだけを数える。** 引用や他人の投稿を拾わないよう article 内に限る
        r.photos  = await art.$$eval('[data-testid="tweetPhoto"]', (n) => n.length).catch(() => -1);
        r.videos  = await art.$$eval('[data-testid="videoPlayer"]', (n) => n.length).catch(() => -1);
        const g = await art.$('[role="group"][aria-label]');
        r.metrics = g ? await g.getAttribute("aria-label") : null;
        const body = await art.$('[data-testid="tweetText"]');
        const t = body ? (await body.innerText()) : "";
        r.head = t.split("\n")[0].slice(0, 28);
        r.tail = t.trim().split("\n").pop().slice(0, 28);
      } catch (e) { r.error = String(e.message).slice(0, 120); }
      out.push(r);
      await page.close().catch(() => {});
    }
  } catch (e) { out.push({ fatal: String(e.message).slice(0, 160) }); }
  console.log(JSON.stringify(out, null, 1));
  if (browser) await browser.close().catch(() => {});
})();
PROBEJS

{
echo "# 出した 2 本を X 上で確かめる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** `x137` が返した tweet_id の実物を見る。"
echo "> **キューの数字では画像の有無は分からない**ので、DOM を見る。"
echo
echo "対象: \`$T1\`（[1/2]）／ \`$T2\`（[2/2]）"

echo
echo "## 1. Chrome は健全か（**口は 18810**）"
echo
echo '```'
if [ -f "$HEALTH" ]; then "$NODE_BIN" "$HEALTH" 2>&1 | clean; echo "(rc=$?)"; else echo "（cdp-health.js が無い）"; fi
echo '```'

echo
echo "## 2. 実物を見る"
echo
echo '```json'
cd "$W" && "$NODE_BIN" "$PROBE" "$T1" "$T2" 2>&1 | head -60 | clean
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 見るところ | 期待 |"
echo "| --- | --- |"
echo "| \`[1/2]\` の \`photos\` | **0**（「↓↓」で切る形。付いていたら失敗） |"
echo "| \`[2/2]\` の \`photos\` | **1**（ここが今回の本題） |"
echo "| 両方の \`ok\` | **true**（false なら 404 か読み込み失敗） |"
echo
echo "**\`[2/2]\` の photos が 0 なら、画像は付いていない。**"
echo "その場合は \`post-comment.js\` の添付確認が甘かったことになる（要 追加調査）。"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

rm -f "$PROBE"
[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '"photos"' "$OUT" 2>/dev/null; then
  echo "2 本の実物を見た。photos の数を確認すること / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
