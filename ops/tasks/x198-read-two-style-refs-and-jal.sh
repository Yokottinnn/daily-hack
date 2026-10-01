#!/bin/bash
# **参考の X 投稿 2 本 と JAL 公式キャンペーンを読む。読むだけ。費用 $0。**
#
# ## なぜ Mac に読ませるのか
#
# **クラウドセッションからは両方 egress で塞がれている**（2026-10-01 に実測）。
#
#   x.com            → EGRESS_BLOCKED
#   www.jal.co.jp    → EGRESS_BLOCKED
#
# **検索結果の要約は一次情報ではない**（`x-post-copy` スキル §4「まとめサイトを
# 根拠にした記述」は禁止）。公式ページの実物を読んでから数字を使う。
#
# ## 読むもの
#
#   ① https://x.com/futbol_kyo1129/status/2104530855901491453
#      → 利用者の指示「この投稿のスタイルもうまく取り入れて投稿の型のひとつにして」
#   ② https://x.com/rocomotion/status/2104403506161766723
#      → 利用者の指示「この投稿も参考にして」
#   ③ JAL Wellness & Travel 搭乗キャンペーン（公式）
#      → 「JAL の歩いてマイルキャンペーンでマイルをもらえること」の裏取り
#
# ## ① ② は「繰り返されている構造」まで見る
#
# **1 本だけ見て『型』と呼ばない**（`x130` / `x132` の教訓）。
# 同じ書き手の直近 6 本 も取って、**共通しているものだけ**を型として扱う。
# 表示回数は**同じアカウント内の順位しか読めない**（母数が違う）。
#
# ## ③ で確かめること
#
# 検索では「2026年9月1日〜10月31日・対象便に2回搭乗＋プロモコードで新規入会 →
# もれなく500マイル／抽選50名に最大10,000マイル」と出たが、**これは要約。**
# **期間・条件・マイル数・プロモコードを公式の本文から取る。**
#
# 記事（`walk-poikatsu-2026.md`）に在るのは次の 2 点だけなので、
# **キャンペーンの数字は公式が唯一の根拠になる。**
#
#   月額550円（税込）／**初回は入会日から翌月末まで無料**
#   実績 月300〜1,000マイル・歩数中心なら450〜600マイル／1マイル 3.7円 で割に合わない
#
# ## やらないこと
#
# **投稿しない。何も書き換えない。画像も作らない。LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
STAMP="$(date '+%Y%m%d-%H%M%S')"
# **拡張子は `.js` のまま保つ**（`.new` だと macOS の node が弾く・最上位ルール 14）
RUNNER="$S/.x198-read-$STAMP.js"
RAWJSON="$W/.x198-out-$STAMP.json"
JALHTML="$W/.x198-jal-$STAMP.html"
OUT="${OPS_REPORT_DIR:-/tmp}/style-refs-and-jal.md"

# **本文に出てくる他人のハンドルは伏せる**（公開リポジトリに載る）。
# 参考元の 2 アカウントはタスクの本文に書いてあるので伏せない
keepers='futbol_kyo1129|rocomotion|heng_ji31590'
hide() { sed -E "s/@($keepers)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    local victims p
    victims="$(descendants "$pid") $pid"
    # **`kill -TERM -$pid` は使わない**（呼び出し側のグループごと落ちる・最上位ルール 14）
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

cat > "$RUNNER" <<'JSEOF'
// x198: 参考投稿 2 本 を読む。$0（LLM 不使用）。
// **playwright-core**（`playwright` はこのワークスペースに無い）
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const TARGETS = [
  { author: "futbol_kyo1129", id: "2104530855901491453" },
  { author: "rocomotion", id: "2104403506161766723" },
];
const MAX_RECENT = 6;
const BUDGET_MS = 260 * 1000;
const t0 = Date.now();

// **x113 で確定した取り方。** textContent は数字が連結されるので使わない
function parseLabel(s) {
  const pick = (re) => { const m = String(s || "").match(re); return m ? Number(m[1].replace(/,/g, "")) : null; };
  return {
    replies: pick(/([\d,]+)\s*件の返信/),
    reposts: pick(/([\d,]+)\s*件のリポスト/),
    likes: pick(/([\d,]+)\s*件のいいね/),
    views: pick(/([\d,]+)\s*件の表示/),
    bookmarks: pick(/([\d,]+)\s*件のブックマーク/),
  };
}

(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) }, null, 1)); process.exit(0); }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log(JSON.stringify({ fatal: "context が無い" }, null, 1)); process.exit(0); }
  const p = await ctx.newPage();
  const out = { posts: [] };

  for (const t of TARGETS) {
    const row = { author: t.author, id: t.id };
    try {
      await p.goto("https://x.com/" + t.author + "/status/" + t.id,
        { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(7000);
      if (/login|i\/flow/.test(p.url())) { row.error = "ログインが切れている"; out.posts.push(row); continue; }
      const got = await p.evaluate(() => {
        const art = document.querySelector("article");
        if (!art) return { error: "article が無い" };
        const tx = art.querySelector('[data-testid="tweetText"]');
        const g = art.querySelector('[role="group"][aria-label]');
        return {
          // **innerText をそのまま。** 改行を潰さない（型は並べ方に出る）
          text: tx ? tx.innerText : null,
          label: g ? g.getAttribute("aria-label") : null,
          images: art.querySelectorAll('img[src*="media"]').length,
          hasVideo: !!art.querySelector('[data-testid="videoPlayer"]'),
        };
      });
      Object.assign(row, got);
      if (row.label) Object.assign(row, parseLabel(row.label));
    } catch (e) { row.error = String(e && e.message).slice(0, 160); }
    out.posts.push(row);
  }

  // 同じ書き手の直近。**繰り返されている構造だけが「型」**（x130 / x132 の教訓）
  out.recent = {};
  for (const t of TARGETS) {
    if (Date.now() - t0 > BUDGET_MS) { out.recent[t.author] = [{ error: "持ち時間を使い切った" }]; continue; }
    try {
      await p.goto("https://x.com/" + t.author, { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(6000);
      for (let i = 0; i < 3; i++) {
        if (Date.now() - t0 > BUDGET_MS) break;
        await p.evaluate(() => window.scrollBy(0, 2200));
        await p.waitForTimeout(2000);
      }
      const rows = await p.evaluate((max) => {
        const seen = new Set(); const acc = [];
        for (const a of document.querySelectorAll("article")) {
          const link = [...a.querySelectorAll('a[href*="/status/"]')]
            .map((x) => (x.getAttribute("href") || "").match(/status\/(\d+)/))
            .filter(Boolean).map((m) => m[1])[0];
          if (!link || seen.has(link)) continue;
          seen.add(link);
          const tx = a.querySelector('[data-testid="tweetText"]');
          const g = a.querySelector('[role="group"][aria-label]');
          acc.push({
            id: link,
            text: tx ? tx.innerText.slice(0, 600) : null,
            label: g ? g.getAttribute("aria-label") : null,
            images: a.querySelectorAll('img[src*="media"]').length,
          });
          if (acc.length >= max) break;
        }
        return acc;
      }, MAX_RECENT);
      for (const r of rows) Object.assign(r, parseLabel(r.label));
      out.recent[t.author] = rows;
    } catch (e) { out.recent[t.author] = [{ error: String(e && e.message).slice(0, 160) }]; }
  }

  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(out, null, 1));
  // **connectOverCDP は node を終わらせない。** b.close() は利用者の Chrome に触るので使わない
  process.exit(0);
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) }, null, 1));
  process.exit(0);
});
JSEOF

{
echo "# 参考投稿 2 本 と JAL 公式キャンペーン（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **クラウドからは x.com も jal.co.jp も egress で塞がれている。** だから Mac で読む。"
echo "> **検索結果の要約は一次情報ではない。** 公式の本文から数字を取る。"
echo "> **投稿しない。何も書き換えない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"

echo
echo "## 1. 構文検査（**置く名前で打つ**）"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -2 | cut -c1-140)"
if [ "$CRC" -ne 0 ]; then
  echo "  → **構文が通らない。走らせない。**"
  echo '```'
  rm -f "$RUNNER"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'

echo
echo "## 2. X の 2 投稿（**全文そのまま**）"
echo
echo '```'
T0="$(date +%s)"
run_limited 300 "$RAWJSON" node "$RUNNER"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **300 秒 で打ち切った**' || echo '← 自分で終わった' )"
echo '```'
rm -f "$RUNNER"
echo
if [ -s "$RAWJSON" ]; then
  node -e '
    const fs = require("fs");
    let j;
    try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) {
      console.log("```");
      console.log("  **JSON として読めない。生の出力の先頭 600 字:**");
      console.log(String(fs.readFileSync(process.argv[1], "utf8")).slice(0, 600));
      console.log("```");
      process.exit(0);
    }
    if (j.fatal) { console.log("```"); console.log("  **止まった: " + j.fatal + "**"); console.log("```"); process.exit(0); }
    const w = (s) => { let n = 0; for (const c of String(s || "")) n += c.codePointAt(0) < 0x80 ? 1 : 2; return n; };
    for (const pst of (j.posts || [])) {
      console.log("### @" + pst.author + " / " + pst.id);
      console.log("");
      if (pst.error) { console.log("**読めなかった: " + pst.error + "**"); console.log(""); continue; }
      console.log("| | |");
      console.log("| --- | --- |");
      console.log("| 表示 | **" + (pst.views ?? "?") + "** |");
      console.log("| いいね | " + (pst.likes ?? "?") + " |");
      console.log("| リポスト | " + (pst.reposts ?? "?") + " |");
      console.log("| ブックマーク | " + (pst.bookmarks ?? "?") + " |");
      console.log("| 返信 | " + (pst.replies ?? "?") + " |");
      console.log("| 画像 | **" + (pst.images ?? "?") + " 枚**" + (pst.hasVideo ? " ＋ 動画" : "") + " |");
      console.log("| 文字数 / 重み | " + String(pst.text || "").length + " 文字 / **重み " + w(pst.text) + "**" +
        (w(pst.text) > 280 ? "（**280 超＝Premium の長文**）" : "") + " |");
      console.log("");
      console.log("**本文（改行そのまま）**");
      console.log("");
      console.log("```text");
      console.log(pst.text || "(取れていない)");
      console.log("```");
      console.log("");
    }
    console.log("## 3. 同じ書き手の直近（**繰り返されている構造だけが「型」**）");
    console.log("");
    for (const [author, rows] of Object.entries(j.recent || {})) {
      console.log("### @" + author + " の直近 " + rows.length + " 本");
      console.log("");
      console.log("```text");
      const sorted = [...rows].sort((a, b) => (b.views || 0) - (a.views || 0));
      for (const r of sorted) {
        if (r.error) { console.log("  (読めなかった: " + r.error + ")"); continue; }
        const head = String(r.text || "").split("\n")[0].slice(0, 58);
        console.log(String(r.views ?? "?").padStart(8) + " 表示 / 画像 " + String(r.images ?? "?") +
          " / いいね " + String(r.likes ?? "?").padStart(4) + " / 重み " + String(w(r.text)).padStart(5) + "  " + head);
      }
      console.log("```");
      console.log("");
    }
  ' "$RAWJSON" 2>&1 | clean
else
  echo '```'
  echo "  **出力が空。CDP か Chrome を確かめる**"
  echo '```'
fi
rm -f "$RAWJSON"

echo
echo "## 4. JAL 公式キャンペーン（**要約ではなく本文**）"
echo
echo "検索では「2026年9月1日〜10月31日・対象便に2回搭乗＋プロモコードで新規入会 →"
echo "もれなく500マイル／抽選50名に最大10,000マイル」と出た。**これを公式で確かめる。**"
echo
echo '```'
U="https://www.jal.co.jp/jp/ja/jmb/wellness/campaign/2026/new-membership-autumn/index.html"
HC="$(curl -sS -o "$JALHTML" -w '%{http_code}' --max-time 25 \
  -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36' \
  "$U" 2>/dev/null)" || HC="err"
printf '  HTTP %s / %s bytes\n' "$HC" "$(wc -c < "$JALHTML" 2>/dev/null | tr -d ' ')"
echo '```'
if [ "$HC" = "200" ] && [ -s "$JALHTML" ]; then
  echo
  echo "**本文（タグを落として先頭 2,600 字）**"
  echo
  echo '```text'
  node -e '
    const fs = require("fs");
    let h = "";
    try { h = fs.readFileSync(process.argv[1], "utf8"); } catch (e) { console.log("読めない"); process.exit(0); }
    const t = h
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, "\n")
      .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
      .split("\n").map((s) => s.trim()).filter(Boolean).join("\n")
      .replace(/\n{3,}/g, "\n\n");
    console.log(t.slice(0, 2600));
  ' "$JALHTML" 2>&1
  echo '```'
  echo
  echo "**数字が書かれた行だけ抜く（マイル / 期間 / 2026年 / プロモーションコード）**"
  echo
  echo '```text'
  node -e '
    const fs = require("fs");
    const h = fs.readFileSync(process.argv[1], "utf8");
    const t = h.replace(/<script[\s\S]*?<\/script>/gi, " ").replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, "\n").replace(/&nbsp;/g, " ")
      .split("\n").map((s) => s.trim()).filter(Boolean);
    const seen = new Set();
    for (const l of t) {
      if (!/(マイル|キャンペーン期間|2026年|プロモーションコード|抽選|搭乗|月額|無料)/.test(l)) continue;
      if (l.length < 4 || l.length > 220) continue;
      if (seen.has(l)) continue;
      seen.add(l);
      console.log("  " + l);
      if (seen.size >= 45) break;
    }
  ' "$JALHTML" 2>&1
  echo '```'
else
  echo
  echo "**公式ページが取れなかった（HTTP $HC）。**"
  echo "**数字は使えない。** 記事に在る「月額550円（税込）／初回は入会日から翌月末まで無料」だけで書く。"
fi
rm -f "$JALHTML"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 出方 | 次 |"
echo "| --- | --- |"
echo "| §2 に本文が出た | **2 本 の共通点だけを型にする。** 片方にしか無いものは型と呼ばない |"
echo "| §3 で同じ構造が繰り返されている | その構造が本物の型 |"
echo "| §2 が \`ログインが切れている\` | **人が X に入り直す。** 自動では戻せない |"
echo "| §4 が HTTP 200 | **キャンペーンの数字を公式から引ける** |"
echo "| §4 が 200 以外 | **キャンペーンの数字は書かない。** 記事の 550 円・初月無料だけで書く |"
echo
echo "**投稿していない。何も書き換えていない。画像も作っていない。**"
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$RUNNER" "$RAWJSON" "$JALHTML"

if grep -aq 'JAL 公式キャンペーン' "$OUT" 2>/dev/null; then
  echo "参考投稿 2 本 と JAL 公式を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
