#!/bin/bash
# **投稿の「表示回数」がどこから取れるかを見るだけ。測る側。費用 $0（DOM を読むだけ）。**
#
# ## なぜ先に見るのか
#
# 2026-09-20 に「時間帯ごとの伸びを記録する」と決めた。
# **だが、いまの手元に時間帯別の実測は 1 件も無い。** 記録する仕組みを作るには、
# まず **X のどこに表示回数が出ているか**を知る必要がある。
#
# **推測でセレクタを書かない。** `x108` で `a[role="link"][href^="/"]` が広すぎて
# **X 自身のサイドバー**を拾い、結果を丸ごと捨てた。同じことをしない。
#
# ## 測る対象
#
# 2 時間 前に出した歩いてポイ活の [1/2]（一次情報＝キューの `x_tweet_id`）。
#
#   2101694599215599678  https://x.com/heng_ji31590/status/2101694599215599678
#
# ## 何を出すか
#
# **候補を全部 ダンプする。** どれが正解かはレポートを見てから決める。
#
#   * `[data-testid="app-text-transition-container"]` の中身（数字が入る器）
#   * `aria-label` に「表示」「views」を含む要素
#   * `/analytics` へのリンクの近傍テキスト
#   * 記事下の `role="group"` の中のテキスト全部
#
# ## やらないこと
#
# **投稿しない。フォローしない。記録の仕組みも作らない（次のタスク）。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/probe-impressions.md"
RUNNER="$S/.x113-probe.js"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

# **拡張子は `.js` のまま。** `.new` を付けると macOS の node が弾く（最上位ルール 14）
cat > "$RUNNER" <<'JSEOF'
// x113: 表示回数がどこから取れるかを見る。$0。
// **playwright-core**（`playwright` はこのワークスペースに無い・契約書 §1）
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const URL = "https://x.com/heng_ji31590/status/2101694599215599678";

(async () => {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.goto(URL, { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForTimeout(6000);

  const out = await p.evaluate(() => {
    const clip = (s) => String(s || "").replace(/\s+/g, " ").trim().slice(0, 120);
    const r = {};

    // ① 数字が入る器
    r.transition = [...document.querySelectorAll('[data-testid="app-text-transition-container"]')]
      .map((e) => clip(e.textContent)).slice(0, 12);

    // ② aria-label に「表示」「views」
    r.ariaViews = [...document.querySelectorAll("[aria-label]")]
      .map((e) => e.getAttribute("aria-label"))
      .filter((a) => a && /表示|views|View/i.test(a))
      .map(clip).slice(0, 12);

    // ③ /analytics へのリンクとその近傍
    r.analytics = [...document.querySelectorAll('a[href*="/analytics"]')]
      .map((a) => ({ href: a.getAttribute("href"), text: clip(a.textContent),
                     parent: clip(a.parentElement && a.parentElement.textContent) }))
      .slice(0, 6);

    // ④ 本文下のボタン群
    r.groups = [...document.querySelectorAll('[role="group"]')]
      .map((e) => ({ label: clip(e.getAttribute("aria-label")), text: clip(e.textContent) }))
      .slice(0, 6);

    // ⑤ 最初の tweet の全文（どの数字がどこに出ているか見当を付ける）
    const art = document.querySelector("article");
    r.article = art ? clip(art.innerText).slice(0, 400) : "(article が無い)";
    r.articleCount = document.querySelectorAll("article").length;
    return r;
  });

  await p.close(); await b.close();
  console.log(JSON.stringify(out, null, 1));
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) }, null, 1));
  process.exit(1);
});
JSEOF

{
echo "# 表示回数はどこから取れるか（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 「時間帯ごとの伸びを記録する」と決めたが、**取り方が分かっていない。**"
echo "> **推測でセレクタを書かない**（x108 で X のサイドバーを拾って結果を捨てた）。"
echo "> まず候補を全部 ダンプして、どれが正解かをレポートで決める。"
echo
echo "測る対象は 2 時間 前に出した歩いてポイ活の \`[1/2]\`。"
echo "\`2101694599215599678\`（一次情報＝キューの \`x_tweet_id\`）"

echo
echo "## 1. Chrome は健全か（**口は 18810**）"
echo
echo '```'
if [ -f "$S/cdp-health.js" ]; then "$NODE_BIN" "$S/cdp-health.js" 2>&1; echo "(rc=$?)"; else echo "（cdp-health.js が無い）"; fi
echo '```'

echo
echo "## 2. 候補のダンプ"
echo
echo '```json'
if ! "$NODE_BIN" --check "$RUNNER" >/dev/null 2>&1; then
  echo "  **構文エラーなので走らせない。**"
else
  RES="${TMPDIR:-/tmp}/.x113-result.json"
  ( cd "$S" && "$NODE_BIN" "$(basename "$RUNNER")" ) > "$RES" 2>&1
  echo "  rc=$? （**rc は証拠にならない。中身を見る**）"
  head -c 4000 "$RES"
  echo
  rm -f "$RES" 2>/dev/null || true
fi
echo '```'

echo
echo "## 3. 読み方"
echo
echo "- **\`transition\` に数字の並びが出ていれば、そこが返信・リポスト・いいね・表示の器。**"
echo "  並び順は X の実装依存なので、**数の意味は \`ariaViews\` か \`groups\` の"
echo "  \`aria-label\` と突き合わせて決める**"
echo "- **\`analytics\` にリンクが在れば、そこが「表示回数」の入口。**"
echo "  ただし押すとページ遷移するので、次のタスクでは**開かずに数だけ取る**ほうを選ぶ"
echo "- **どれも空なら、ログアウトしているか、まだ描画が終わっていない。**"
echo "  その場合は待ち時間を伸ばして取り直す"
echo
echo "**この結果を見てから、記録の仕組み（次のタスク）を書く。**"
echo "測るものと直すものを同じタスクに入れない（最上位ルール 15）。"

echo
echo "## 4. 費用"
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
echo "表示回数の取り方を見る / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
