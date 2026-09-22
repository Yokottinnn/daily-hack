#!/bin/bash
# **バズっている投稿の本文と、同じ書き手の直近投稿を取る。測るだけ。費用 $0。**
#
# ## なぜ
#
# 2026-09-22 に指定された。
#
#   「あと別件でこの投稿スタイルも参考にしてね」
#     https://x.com/monchi06241/status/2102380091112300565
#
# **クラウドからは x.com に出られない**（プロキシが遮断）。Mac の Chrome で読む。
#
# ## 1 投稿だけでは型か偶然か分からない
#
# **同じ書き手の直近投稿も取る。** 繰り返されている構造だけが「型」であって、
# 1 本の当たりは再現できない。
#
#   * 指定された投稿の**全文**（改行を残す）
#   * 同じ書き手の**直近 10 本**の本文と数字
#   * それぞれの **いいね / リポスト / 返信 / 表示**
#
# ## 数字の取り方は確定している（推測しない）
#
# `x113` で確定した。**`role="group"` の `aria-label` に 4 つの数が全部 入っている。**
# `textContent` は `"112"` と連結されて出るので使わない。
#
# ## やらないこと
#
# **投稿しない。いいねしない。フォローしない。LLM を呼ばない。**
# 文面を書くのは次（人間が承認してから）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/viral-post-structure-2.md"
RUNNER="$S/.x132-viral.js"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }

# **拡張子は `.js` のまま**（`.new` を付けると macOS の node が弾く・最上位ルール 14）
cat > "$RUNNER" <<'JSEOF'
// x132: バズ投稿の構造を読む。$0。
// **playwright-core**（`playwright` はこのワークスペースに無い）
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const AUTHOR = "monchi06241";
const TARGET = "2102380091112300565";
const MAX_RECENT = 10;
const BUDGET_MS = 230 * 1000;
const t0 = Date.now();

// **x113 で確定した取り方。** textContent は数字が連結されるので使わない
function parseLabel(s) {
  const pick = (re) => { const m = String(s || "").match(re); return m ? Number(m[1].replace(/,/g, "")) : null; };
  return {
    replies: pick(/([\d,]+)\s*件の返信/),
    reposts: pick(/([\d,]+)\s*件のリポスト/),
    likes:   pick(/([\d,]+)\s*件のいいね/),
    views:   pick(/([\d,]+)\s*件の表示/),
  };
}

(async () => {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const out = {};

  // ① 指定された投稿を全文で取る
  await p.goto("https://x.com/" + AUTHOR + "/status/" + TARGET,
    { waitUntil: "domcontentloaded", timeout: 45000 });
  await p.waitForTimeout(7000);
  out.target = await p.evaluate(() => {
    const art = document.querySelector("article");
    if (!art) return { error: "article が無い" };
    const tx = art.querySelector('[data-testid="tweetText"]');
    const g = art.querySelector('[role="group"][aria-label]');
    return {
      // **innerText をそのまま。** 改行を潰さない
      text: tx ? tx.innerText : null,
      label: g ? g.getAttribute("aria-label") : null,
      images: art.querySelectorAll('img[src*="media"]').length,
      hasVideo: !!art.querySelector('[data-testid="videoPlayer"]'),
    };
  });
  if (out.target && out.target.label) Object.assign(out.target, parseLabel(out.target.label));

  // ② 同じ書き手の直近投稿。**繰り返されている構造だけが「型」**
  out.recent = [];
  try {
    await p.goto("https://x.com/" + AUTHOR, { waitUntil: "domcontentloaded", timeout: 45000 });
    await p.waitForTimeout(6000);
    // 少しスクロールして本数を稼ぐ
    for (let i = 0; i < 4; i++) {
      if (Date.now() - t0 > BUDGET_MS) break;
      await p.evaluate(() => window.scrollBy(0, 2200));
      await p.waitForTimeout(2200);
    }
    out.recent = await p.evaluate((max) => {
      const seen = new Set(); const rows = [];
      for (const a of document.querySelectorAll("article")) {
        const link = [...a.querySelectorAll('a[href*="/status/"]')]
          .map((x) => (x.getAttribute("href") || "").match(/status\/(\d+)/))
          .filter(Boolean).map((m) => m[1])[0];
        if (!link || seen.has(link)) continue;
        seen.add(link);
        const tx = a.querySelector('[data-testid="tweetText"]');
        const g = a.querySelector('[role="group"][aria-label]');
        rows.push({
          id: link,
          text: tx ? tx.innerText : null,
          label: g ? g.getAttribute("aria-label") : null,
          images: a.querySelectorAll('img[src*="media"]').length,
        });
        if (rows.length >= max) break;
      }
      return rows;
    }, MAX_RECENT);
    for (const r of out.recent) Object.assign(r, parseLabel(r.label));
  } catch (e) { out.recentError = String(e && e.message).slice(0, 160); }

  await p.close(); await b.close();
  console.log(JSON.stringify(out, null, 1));
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) }, null, 1));
  process.exit(1);
});
JSEOF

{
echo "# 参考にする投稿スタイル その2（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 「このトークスクリプトみたいな X でバズってる投稿の文章の書き方を学習して」"
echo "> と指定された（2026-09-22）。**クラウドからは x.com に出られない**ので Mac で読む。"
echo ">"
echo "> **1 投稿だけでは型か偶然か分からない。** 同じ書き手の直近投稿も取る。"
echo "> **繰り返されている構造だけが「型」**であって、1 本の当たりは再現できない。"

echo
echo "## 1. Chrome は健全か（**口は 18810**）"
echo
echo '```'
if [ -f "$S/cdp-health.js" ]; then "$NODE_BIN" "$S/cdp-health.js" 2>&1 | secrets; echo "(rc=$?)"; else echo "（cdp-health.js が無い）"; fi
echo '```'
echo
echo "**ログインしていないと本文が取れない。** 上が OK でなければ以降は空になる。"

echo
echo "## 2. 指定された投稿と、同じ書き手の直近 10 本"
echo
echo "**数字の取り方は \`x113\` で確定済み**（\`role=\"group\"\` の \`aria-label\`）。"
echo "\`textContent\` は \`\"112\"\` と連結されて出るので使わない。"
echo
echo '```json'
if ! "$NODE_BIN" --check "$RUNNER" >/dev/null 2>&1; then
  echo "  **構文エラーなので走らせない**"
  "$NODE_BIN" --check "$RUNNER" 2>&1 | head -4
else
  RES="${TMPDIR:-/tmp}/.x130-result.json"
  ( cd "$S" && "$NODE_BIN" "$(basename "$RUNNER")" ) > "$RES" 2>&1
  echo "  rc=$? （**rc は証拠にならない。中身を見る**）"
  head -c 14000 "$RES" | secrets
  echo
  rm -f "$RES" 2>/dev/null || true
fi
echo '```'

echo
echo "## 3. 読むときに見るところ"
echo
echo "**「バズった」という結果ではなく、毎回やっている作り**を探す。"
echo
echo "| 見るところ | 何が分かるか |"
echo "| --- | --- |"
echo "| **1 行目**（フックの形） | 数字か／問いか／否定か。**何文字で刺しているか** |"
echo "| 改行の入れ方 | 1 行の長さ、空行の頻度。スマホでの見え方 |"
echo "| **箇条書きの有無と行数** | 3 行 か 5 行 か。記号（・／→／✅） |"
echo "| 締めの形 | 命令形／問いかけ／保存の促し |"
echo "| 画像の有無 | \`images\` の数。**無しで伸びているなら文だけで勝っている** |"
echo "| **返信 / リポスト / いいね の比** | 返信が多い＝議論を呼ぶ型。いいねが多い＝共感型 |"
echo
echo "**直近 10 本 と比べて、当たった 1 本だけに在るものは「型」ではない。**"
echo "**10 本 すべてに在るものが型。**"

echo
echo "## 3-B. 1 本目（@ryo_ryo_1008）と比べる"
echo
echo "**x130 で取った 1 本目の型**（`x-post-copy` スキル §3-B に記録済み）。"
echo
echo "| # | 型 | 実測 |"
echo "| --- | --- | --- |"
echo "| ① | 1 行目に肩書きを埋める | 10 本 中 5 本 |"
echo "| ② | **末尾を矢印で切る** | 切った 4 本が上位 4 本と一致 |"
echo "| ③ | 否定列挙 | 12,247 表示 |"
echo "| ④ | 箇条書きは 3 行 | 上位 2 本の両方 |"
echo "| — | 2 本目は **15〜20%** しか読まれない | 4 組で一致 |"
echo
echo "**同じなら型が裏づけられる。違うなら、別の型として両方 残す。**"
echo "**片方にしか無いものを「型」と呼ばない。**"
echo
echo "## 4. このあと（**このタスクでは文面を書かない**）"
echo
echo "型を writing のスキルへ落とす。**\`x-post-copy\` スキルの §3（組み立て）に追記する。**"
echo "文面そのものは、**承認をもらってから出す**（最上位ルール 4）。"
echo
echo "**真似してはいけないもの**も一緒に控える。"
echo
echo "- **記事に無い数字・固有名詞**（バズ投稿が使っていても、こちらは書けない）"
echo "- **煽りの強さ**。返信に持ち込むと絡みになる（\`x-reply-style\` §6）"
echo "- **キャラの芯を崩す言い回し**。一人称「アタシ」は固定"

echo
echo "## 5. 費用"
echo
echo "**DOM を読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

rm -f "$RUNNER" 2>/dev/null || true
echo "参考スタイル 2 本目を読んだ / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
