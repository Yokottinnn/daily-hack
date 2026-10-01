#!/bin/bash
# **投稿スタイルを体系化するための材料を読む。読むだけ。費用 $0。**
#
# ## 指示（2026-10-02）
#
#   > これらの記事の投稿スタイルを参考にして、これからXに投稿する際のスキルとして
#   > しっかり吸収し、いくつかパターンとして保存しておいて。
#   > まずは既存の投稿スタイルにどんなものがあるかを洗い出した上で、…
#
# 参考に渡された 5 本（クラウドからは x.com が塞がれているので Mac で読む）。
#   https://x.com/zomi1023/status/2105654970448220300
#   https://x.com/oimachi_toriko/status/2105206513593885008
#   https://x.com/MURA_mal/status/2105175906239353162
#   https://x.com/ruka_affi/status/2104326018710577218
#   https://x.com/shupeiman/status/2104088742374101138
#
# **1 本だけ見て「型」と呼ばない**（x130 / x132 の教訓）。書き手ごとに直近 6 本 も取り、
# **繰り返されている構造だけ**を型として扱う。表示回数は同じアカウント内でしか比べない。
# **画像の中身はテキストで取れないので、各投稿の見た目を PNG で撮る**（reports/ref-<書き手>.png）。
#
# あわせて **既存の投稿スタイルの洗い出し**のため、キューから**実際に出た告知
# （`blog-promo-` かつ `tweet_id` が在るもの）の本文**を出す。リポジトリの posts.json には
# 承認済みの 5 セットしか無く、それ以前に出た告知の文面が残っていないため。
#
# ## やらないこと
#
# **投稿しない。リポストもいいねもしない。キューを書き換えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
QJSON="$W/data/post_queue.json"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x202-read-$STAMP.js"
RAW="$W/.x202-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/style-refs-5-and-posted.md"

keepers='zomi1023|oimachi_toriko|MURA_mal|ruka_affi|shupeiman|heng_ji31590'
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
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

cat > "$RUNNER" <<'JSEOF'
// x202: 参考投稿 5 本 と書き手の直近を読む。$0（LLM 不使用）。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const OUTDIR = process.argv[2];
const TARGETS = [
  ["zomi1023", "2105654970448220300"],
  ["oimachi_toriko", "2105206513593885008"],
  ["MURA_mal", "2105175906239353162"],
  ["ruka_affi", "2104326018710577218"],
  ["shupeiman", "2104088742374101138"],
];
const RECENT = 6;
const BUDGET_MS = 250 * 1000;
const t0 = Date.now();

function parseLabel(s) {
  const pick = (re) => { const m = String(s || "").match(re); return m ? Number(m[1].replace(/,/g, "")) : null; };
  return { replies: pick(/([\d,]+)\s*件の返信/), reposts: pick(/([\d,]+)\s*件のリポスト/),
           likes: pick(/([\d,]+)\s*件のいいね/), views: pick(/([\d,]+)\s*件の表示/),
           bookmarks: pick(/([\d,]+)\s*件のブックマーク/) };
}
const readArticles = (p, max) => p.evaluate((max) => [...document.querySelectorAll("article")].slice(0, max).map((a) => {
  const link = [...a.querySelectorAll('a[href*="/status/"]')]
    .map((x) => (x.getAttribute("href") || "").match(/^\/([^/]+)\/status\/(\d+)/)).filter(Boolean)[0];
  const tx = a.querySelector('[data-testid="tweetText"]');
  const g = a.querySelector('[role="group"][aria-label]');
  const tm = a.querySelector("time");
  const card = a.querySelector('[data-testid="card.wrapper"]');
  const quote = a.querySelector('div[role="link"] [data-testid="tweetText"]');
  return {
    author: link ? link[1] : null, id: link ? link[2] : null,
    at: tm ? tm.getAttribute("datetime") : null,
    text: tx ? tx.innerText : null,
    label: g ? g.getAttribute("aria-label") : null,
    images: a.querySelectorAll('img[src*="pbs.twimg.com/media"]').length,
    video: !!a.querySelector('[data-testid="videoPlayer"]'),
    card: card ? card.innerText.slice(0, 200) : null,
    quote: quote ? quote.innerText.slice(0, 300) : null,
  };
}), max);

(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log(JSON.stringify({ fatal: "context が無い" })); process.exit(0); }
  const p = await ctx.newPage();
  await p.setViewportSize({ width: 700, height: 1700 });
  const out = { refs: [] };

  for (const [author, id] of TARGETS) {
    const row = { author, id };
    if (Date.now() - t0 > BUDGET_MS) { row.error = "持ち時間を使い切った"; out.refs.push(row); continue; }
    try {
      await p.goto("https://x.com/" + author + "/status/" + id, { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(7000);
      if (/login|i\/flow/.test(p.url())) { row.error = "ログインが切れている"; out.refs.push(row); continue; }
      const arts = await readArticles(p, 6);
      for (const r of arts) Object.assign(r, parseLabel(r.label));
      const idx = arts.findIndex((r) => r.id === id);
      row.target = idx >= 0 ? arts[idx] : null;
      // **同じ書き手の続き（スレッド）**＝指定の投稿の直後に並ぶ同じ書き手の投稿
      row.thread = idx >= 0 ? arts.slice(idx + 1).filter((r) => r.author === author) : [];
      const hs = await p.$$("article");
      if (idx >= 0 && hs[idx]) { await hs[idx].screenshot({ path: OUTDIR + "/ref-" + author + ".png" }); row.png = true; }
    } catch (e) { row.error = String(e && e.message).slice(0, 180); }
    // 書き手の直近（**繰り返されている構造だけが型**）
    try {
      if (Date.now() - t0 < BUDGET_MS) {
        await p.goto("https://x.com/" + author, { waitUntil: "domcontentloaded", timeout: 45000 });
        await p.waitForTimeout(5500);
        await p.evaluate(() => window.scrollBy(0, 2400));
        await p.waitForTimeout(1800);
        const rec = await readArticles(p, RECENT + 2);
        for (const r of rec) Object.assign(r, parseLabel(r.label));
        row.recent = rec.filter((r) => r.author === author).slice(0, RECENT);
      }
    } catch (e) { row.recentError = String(e && e.message).slice(0, 160); }
    out.refs.push(row);
  }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(out));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

{
echo "# 投稿スタイルの材料: 参考 5 本 ＋ 実際に出た告知（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。リポストもいいねもしない。キューを書き換えない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
[ "$CRC" -ne 0 ] && { echo '```'; rm -f "$RUNNER"; echo "**構文が通らない。走らせない。**"; exit 1; }
rm -f "$OUTDIR"/ref-*.png
T0="$(date +%s)"
run_limited 280 "$RAW" node "$RUNNER" "$OUTDIR"; RC=$?
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
for f in "$OUTDIR"/ref-*.png; do [ -s "$f" ] && printf '  見た目: %s（%s bytes）\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"; done
echo '```'
rm -f "$RUNNER"

echo
echo "# A. 参考 5 本"
if [ -s "$RAW" ]; then
  node -e '
    const fs = require("fs");
    // **node -e では argv[1] が第 1 引数**
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("**JSON として読めない:**\n```\n" + fs.readFileSync(process.argv[1], "utf8").slice(0, 600) + "\n```"); process.exit(0); }
    if (j.fatal) { console.log("\n**止まった: " + j.fatal + "**"); process.exit(0); }
    const w = (s) => { let n = 0; for (const c of String(s || "")) n += c.codePointAt(0) < 0x80 ? 1 : 2; return n; };
    const jst = (s) => s ? new Date(new Date(s).getTime() + 9 * 3600e3).toISOString().slice(0, 16).replace("T", " ") : "?";
    const num = (r) => [r.views, r.likes, r.reposts, r.bookmarks, r.replies].map((x) => x ?? "?").join(" / ");
    for (const r of j.refs || []) {
      console.log("\n## @" + r.author + " / " + r.id + "\n");
      if (r.error) console.log("**読めなかった: " + r.error + "**\n");
      const t = r.target;
      if (t) {
        console.log("| | |\n| --- | --- |");
        console.log("| 投稿時刻 | " + jst(t.at) + " JST |");
        console.log("| 表示 / いいね / RT / ブクマ / 返信 | " + num(t) + " |");
        console.log("| 画像 | " + t.images + " 枚" + (t.video ? " ＋ 動画" : "") + " |");
        console.log("| 文字数 / 重み | " + String(t.text || "").length + " / " + w(t.text) + (w(t.text) > 280 ? "（**280 超＝長文**）" : "") + " |");
        console.log("| 見た目 | " + (r.png ? "`ref-" + r.author + ".png`" : "撮れていない") + " |");
        console.log("\n```text\n" + (t.text || "(本文なし)") + "\n```");
        if (t.card) console.log("\n**リンクカード**\n```text\n" + t.card + "\n```");
        if (t.quote) console.log("\n**引用ポスト**\n```text\n" + t.quote + "\n```");
      } else if (!r.error) console.log("**指定の投稿が見つからない**");
      if ((r.thread || []).length) {
        console.log("\n**続き（同じ書き手のスレッド）**");
        r.thread.forEach((c, i) => console.log("\n```text\n[" + (i + 2) + "] " + (c.text || "") + "\n```  画像 " + c.images + " 枚"));
      }
      console.log("\n**同じ書き手の直近（表示の多い順）**\n```text");
      const rec = [...(r.recent || [])].sort((a, b) => (b.views || 0) - (a.views || 0));
      for (const c of rec) console.log(String(c.views ?? "?").padStart(9) + " 表示 / 画像 " + c.images + " / 重み " + String(w(c.text)).padStart(5) + "  " + String(c.text || "").replace(/\n+/g, " / ").slice(0, 70));
      if (!rec.length) console.log("  （取れていない" + (r.recentError ? ": " + r.recentError : "") + "）");
      console.log("```");
    }
  ' "$RAW" 2>&1 | clean
else
  echo; echo "**出力が空。CDP か Chrome を確かめる**"
fi
rm -f "$RAW"

echo
echo "# B. 実際に出た告知の本文（キューの \`blog-promo-\` かつ \`tweet_id\` が在るもの・新しい順 14 件）"
echo
echo "**一次情報はキューの \`tweet_id\`**（最上位ルール 11）。本文のフィールド名は決め打ちせず、文字列のものを全部 拾う。"
echo
if [ -f "$QJSON" ]; then
  node -e '
    const fs = require("fs");
    let q; try { q = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { console.log("**キューが読めない: " + e.message + "**"); process.exit(0); }
    const arr = Array.isArray(q) ? q : (q.queue || q.items || Object.values(q));
    const TXT = ["text", "content", "tweet_text", "body", "draft", "draft_text", "copy"];
    const pickText = (o) => { if (!o || typeof o !== "object") return null; for (const k of TXT) if (typeof o[k] === "string" && o[k].trim()) return o[k]; return null; };
    const rows = arr.filter((e) => e && typeof e === "object" && String(e.id || "").startsWith("blog-promo-") && (e.x_tweet_id || e.tweet_id))
      .sort((a, b) => String(b.posted_at || "").localeCompare(String(a.posted_at || ""))).slice(0, 14);
    console.log("出た告知: " + rows.length + " 件（表示上限 14）\n");
    for (const e of rows) {
      console.log("## " + e.id + "\n");
      console.log("```\n  tweet_id " + (e.x_tweet_id || e.tweet_id) + " / posted_at " + (e.posted_at || "?") + " / kind " + (e.kind || "?") + "\n```");
      const parts = [pickText(e), ...((Array.isArray(e.thread_chain) ? e.thread_chain : []).map(pickText))].filter(Boolean);
      if (!parts.length) { console.log("\n**本文が取れない。** 在るキー: " + Object.keys(e).join(", ")); continue; }
      parts.forEach((t, i) => console.log("\n```text\n[" + (i + 1) + "/" + parts.length + "]\n" + t + "\n```"));
      console.log("");
    }
  ' "$QJSON" 2>&1 | clean
else
  echo "**キューが無い: $QJSON**"
fi

echo
echo "---"
echo
echo "**投稿していない。キューも書き換えていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$RUNNER" "$RAW"
if grep -aq '実際に出た告知' "$OUT" 2>/dev/null; then
  echo "スタイルの材料を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
