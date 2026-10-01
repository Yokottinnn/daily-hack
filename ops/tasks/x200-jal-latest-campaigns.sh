#!/bin/bash
# **JAL Wellness & Travel の「いま やっている最新のキャンペーン」を全部 読む。読むだけ。費用 $0。**
#
# ## 指示（2026-10-01）
#
#   > 今やってる最新のキャンペーンっていうのがどれか、お前がそもそも調べろよ。
#
# `x199` で公式トップから辿れたが、**3 本 しか開いていない**（ログイン画面・一覧・ホノルル）。
# **開いていないページに答えが在る。** 推測で埋めない（最上位ルール 20）。
#
# ## 読むもの
#
#   ① 公式のキャンペーンページ（**x199 で公式トップのリンクから拾ったもの＋検索で出た公式 URL**）
#      - campaign/miles/                    ← **「マイル2倍」の常設ページらしい。本命**
#      - campaign/2026/new-membership-autumn/ ← 搭乗 2 回で 500 マイル。**終了日をまだ取っていない**
#      - campaign/2026/check-in/
#      - campaign/2026/whisky/
#   ② X 上の最新の「2倍」の話（**アプリ内のお知らせで出るので、公式サイトに載らない**）
#      - 検索「JAL Wellness 2倍」の最新順
#      - 参考に出された rocomotion さんの直近
#
# **②は一次情報ではない。** 公式ページで裏が取れなかったときに「いつ・何が」出ていたかの
# 手がかりとして使う。数字は公式の表記だけを使う。
#
# ## やらないこと
#
# **投稿しない。ログインが要るページに入らない。何も書き換えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x200-jal-$STAMP.js"
RAW="$W/.x200-out-$STAMP.json"
OUT="${OPS_REPORT_DIR:-/tmp}/jal-latest-campaigns.md"

keepers='rocomotion|heng_ji31590'
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
// x200: JAL W&T の最新キャンペーンを読む。$0（LLM 不使用）。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const PAGES = [
  "https://www.jal.co.jp/jp/ja/jmb/wellness/campaign/miles/",
  "https://www.jal.co.jp/jp/ja/jmb/wellness/campaign/2026/new-membership-autumn/",
  "https://www.jal.co.jp/jp/ja/jmb/wellness/campaign/2026/check-in/",
  "https://www.jal.co.jp/jp/ja/jmb/wellness/campaign/2026/whisky/",
];
const BUDGET_MS = 240 * 1000;
const t0 = Date.now();

function parseLabel(s) {
  const pick = (re) => { const m = String(s || "").match(re); return m ? Number(m[1].replace(/,/g, "")) : null; };
  return { likes: pick(/([\d,]+)\s*件のいいね/), views: pick(/([\d,]+)\s*件の表示/) };
}
const readTweets = (p, max) => p.evaluate((max) => {
  const seen = new Set(); const acc = [];
  for (const a of document.querySelectorAll("article")) {
    const link = [...a.querySelectorAll('a[href*="/status/"]')]
      .map((x) => (x.getAttribute("href") || "").match(/^\/([^/]+)\/status\/(\d+)/)).filter(Boolean)[0];
    if (!link || seen.has(link[2])) continue;
    seen.add(link[2]);
    const tx = a.querySelector('[data-testid="tweetText"]');
    const tm = a.querySelector("time");
    const g = a.querySelector('[role="group"][aria-label]');
    acc.push({ author: link[1], id: link[2], at: tm ? tm.getAttribute("datetime") : null,
               text: tx ? tx.innerText.slice(0, 500) : null, label: g ? g.getAttribute("aria-label") : null });
    if (acc.length >= max) break;
  }
  return acc;
}, max);

(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log(JSON.stringify({ fatal: "context が無い" })); process.exit(0); }
  const p = await ctx.newPage();
  const out = { pages: [], search: [], roco: [] };

  // ① 公式
  for (const u of PAGES) {
    if (Date.now() - t0 > BUDGET_MS) { out.pages.push({ url: u, error: "持ち時間を使い切った" }); continue; }
    const row = { url: u };
    try {
      const r = await p.goto(u, { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(3500);
      row.status = r ? r.status() : null;
      row.final = p.url();
      row.title = await p.title();
      row.text = await p.evaluate(() => document.body ? document.body.innerText.replace(/\n{3,}/g, "\n\n").slice(0, 5000) : null);
    } catch (e) { row.error = String(e && e.message).slice(0, 180); }
    out.pages.push(row);
  }

  // ② X の最新（**手がかり。一次情報ではない**）
  try {
    if (Date.now() - t0 < BUDGET_MS) {
      await p.goto("https://x.com/search?q=" + encodeURIComponent("JAL Wellness 2倍") + "&f=live",
        { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(7000);
      if (/login|i\/flow/.test(p.url())) out.searchError = "ログインが切れている";
      else { out.search = await readTweets(p, 12); for (const r of out.search) Object.assign(r, parseLabel(r.label)); }
    }
  } catch (e) { out.searchError = String(e && e.message).slice(0, 160); }
  try {
    if (Date.now() - t0 < BUDGET_MS) {
      await p.goto("https://x.com/rocomotion", { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(6000);
      for (let i = 0; i < 2; i++) { await p.evaluate(() => window.scrollBy(0, 2200)); await p.waitForTimeout(1800); }
      out.roco = await readTweets(p, 12);
      for (const r of out.roco) Object.assign(r, parseLabel(r.label));
    }
  } catch (e) { out.rocoError = String(e && e.message).slice(0, 160); }

  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(out, null, 1));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

{
echo "# JAL Wellness & Travel のいま やっているキャンペーン（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **x199 で開いていなかった公式ページ 4 本 ＋ X 上の最新の「2倍」の話。**"
echo "> **X の投稿は一次情報ではない。** 数字は公式の表記だけを使う。"
echo "> **投稿しない。ログインが要るページに入らない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
[ "$CRC" -ne 0 ] && { echo '```'; rm -f "$RUNNER"; echo "**構文が通らない。走らせない。**"; exit 1; }
T0="$(date +%s)"
run_limited 290 "$RAW" node "$RUNNER"; RC=$?
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
echo '```'
rm -f "$RUNNER"
if [ -s "$RAW" ]; then
  node -e '
    const fs = require("fs");
    // **node -e では argv[1] が第 1 引数**
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("**JSON として読めない:**\n```\n" + fs.readFileSync(process.argv[1], "utf8").slice(0, 600) + "\n```"); process.exit(0); }
    if (j.fatal) { console.log("**止まった: " + j.fatal + "**"); process.exit(0); }
    const jst = (s) => s ? new Date(new Date(s).getTime() + 9 * 3600e3).toISOString().slice(0, 16).replace("T", " ") : "?";

    console.log("\n## 1. 公式のキャンペーンページ（**一次情報**）\n");
    for (const pg of j.pages || []) {
      console.log("### " + (pg.title || pg.url) + "\n");
      console.log("```\n  " + pg.url + "\n  → " + (pg.final || "?") + "\n  HTTP " + (pg.status ?? "?") + (pg.error ? " / " + pg.error : "") + "\n```\n");
      if (!pg.text) continue;
      const lines = pg.text.split("\n").map((s) => s.trim()).filter(Boolean);
      // ナビとフッターを落とす（「ホーム」から「シェア」まで＝本文）
      const st = Math.max(0, lines.findIndex((l) => /^ホーム/.test(l)));
      let en = lines.findIndex((l, i) => i > st && /^(シェア|JALマイレージバンクとは)/.test(l));
      if (en < 0) en = lines.length;
      console.log("**本文（ナビとフッターを除く）**\n\n```text");
      console.log(lines.slice(st, en).join("\n").slice(0, 2600));
      console.log("```\n");
    }

    console.log("## 2. X で「JAL Wellness 2倍」の最新順（**手がかり。一次情報ではない**）\n");
    if (j.searchError) console.log("**読めなかった: " + j.searchError + "**\n");
    console.log("```text");
    for (const r of j.search || []) console.log("  " + jst(r.at) + " JST  @" + r.author + "  表示 " + (r.views ?? "?") + "\n    " + String(r.text || "").replace(/\n+/g, " / ").slice(0, 200));
    if (!(j.search || []).length) console.log("  （0 件）");
    console.log("```\n");

    console.log("## 3. rocomotion さんの直近（**参考に出された人**）\n");
    if (j.rocoError) console.log("**読めなかった: " + j.rocoError + "**\n");
    console.log("```text");
    for (const r of j.roco || []) console.log("  " + jst(r.at) + " JST  表示 " + (r.views ?? "?") + "\n    " + String(r.text || "").replace(/\n+/g, " / ").slice(0, 220));
    console.log("```");
  ' "$RAW" 2>&1 | clean
else
  echo; echo "**出力が空。CDP か Chrome を確かめる**"
fi
rm -f "$RAW"
echo
echo "---"
echo
echo "**読み方**: §1 の本文に **期間・条件・マイル数** が在るものだけが「いま やっている」と言える。"
echo "§2 §3 は**いつ何が出ていたかの手がかり**で、数字の根拠にはしない。"
echo
echo "**投稿していない。何も書き換えていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$RUNNER" "$RAW"
if grep -aq '公式のキャンペーンページ' "$OUT" 2>/dev/null; then
  echo "JAL の最新キャンペーンを読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
