#!/bin/bash
# **FUNDS の紹介投稿で「バズっているもの」を読む。読むだけ。費用 $0。**
#
# ## 指示（2026-10-05）
#
#   > Fundsの紹介投稿を作成して欲しい
#   > ありきたりだと誰も登録してくれないから、fundsの紹介投稿で最もバズってるものを参考にして作成して
#
# **見ずに書かない**（最上位ルール 20）。X を話題順で 5 つの言い方で検索し、
# 表示の多い順に並べる。上位 6 本は見た目を PNG で撮る（reports/funds-ref-*.png）。
# **1 本だけで型と呼ばない**（x130 / x132 の教訓）。何本に共通しているかを数える。
#
# 他人のハンドルと、他人の招待リンク（invy.jp/il/…）は伏せる（公開リポジトリに載る）。
# **投稿しない。リポストもいいねもしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
QJSON="$W/data/post_queue.json"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x250-read-$STAMP.js"
RAW="$W/.x250-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/funds-refs.md"

# **他人のハンドルは伏せる**（公開リポジトリに載る）。自分だけ残す
hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(invy\.jp/il/)[A-Za-z0-9_=+%-]+#\1<伏せ>#g; s#(x\.com/)[A-Za-z0-9_]{2,15}/#\1<伏せ>/#g"; }
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
// x250: FUNDS の紹介投稿を話題順で読む。$0（LLM 不使用）。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const OUTDIR = process.argv[2];
const ME = "heng_ji31590";
const QUERIES = ["FUNDS 招待", "FUNDS 特典", "ファンズ 招待", "FUNDS 貸付ファンド", "invy.jp"];
const BUDGET_MS = 255 * 1000;
const t0 = Date.now();

function parseLabel(s) {
  const pick = (re) => { const m = String(s || "").match(re); return m ? Number(m[1].replace(/,/g, "")) : null; };
  return { replies: pick(/([\d,]+)\s*件の返信/), reposts: pick(/([\d,]+)\s*件のリポスト/),
           likes: pick(/([\d,]+)\s*件のいいね/), views: pick(/([\d,]+)\s*件の表示/),
           bookmarks: pick(/([\d,]+)\s*件のブックマーク/) };
}
const readArticles = (p, max) => p.evaluate((max) => [...document.querySelectorAll("article")].slice(0, max).map((a, i) => {
  const link = [...a.querySelectorAll('a[href*="/status/"]')]
    .map((x) => (x.getAttribute("href") || "").match(/^\/([^/]+)\/status\/(\d+)/)).filter(Boolean)[0];
  const tx = a.querySelector('[data-testid="tweetText"]');
  const g = a.querySelector('[role="group"][aria-label]');
  const tm = a.querySelector("time");
  return {
    idx: i, author: link ? link[1] : null, id: link ? link[2] : null,
    at: tm ? tm.getAttribute("datetime") : null,
    text: tx ? tx.innerText : null,
    label: g ? g.getAttribute("aria-label") : null,
    images: a.querySelectorAll('img[src*="pbs.twimg.com/media"]').length,
    video: !!a.querySelector('[data-testid="videoPlayer"]'),
    repost: /さんがリポスト|reposted/i.test(a.innerText.slice(0, 80)),
  };
}), max);
const scrollRead = async (p, max, rounds) => {
  const seen = new Map();
  for (let r = 0; r < rounds && Date.now() - t0 < BUDGET_MS; r++) {
    for (const x of await readArticles(p, 40)) if (x.id && !seen.has(x.id)) seen.set(x.id, x);
    if (seen.size >= max) break;
    await p.evaluate(() => window.scrollBy(0, 2600));
    await p.waitForTimeout(1800);
  }
  const rows = [...seen.values()].slice(0, max);
  for (const r of rows) Object.assign(r, parseLabel(r.label));
  return rows;
};
const shot = async (p, id, path) => {
  try {
    await p.goto("https://x.com/i/status/" + id, { waitUntil: "domcontentloaded", timeout: 40000 });
    await p.waitForTimeout(5000);
    const a = await p.$("article");
    if (a) { await a.screenshot({ path }); return true; }
  } catch (e) {}
  return false;
};

(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log(JSON.stringify({ fatal: "context が無い" })); process.exit(0); }
  const p = await ctx.newPage();
  await p.setViewportSize({ width: 700, height: 1700 });
  const out = { me: {}, mine: [], search: {}, shots: [] };

  // ログインの確認だけ
  try {
    await p.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 45000 });
    await p.waitForTimeout(4000);
    if (/login|i\/flow/.test(p.url())) { console.log(JSON.stringify({ fatal: "ログインが切れている" })); process.exit(0); }
  } catch (e) {}

  // ④ 他アカウント（話題順）
  for (const q of QUERIES) {
    if (Date.now() - t0 > BUDGET_MS) break;
    try {
      await p.goto("https://x.com/search?q=" + encodeURIComponent(q) + "&src=typed_query&f=top", { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(6500);
      out.search[q] = (await scrollRead(p, 20, 4)).filter((r) => r.author && r.author !== ME);
    } catch (e) { out.search[q] = [{ error: String(e && e.message).slice(0, 160) }]; }
  }

  // 見た目: 自分の上位 2 本・他アカウントの上位 4 本
  const all = new Map();
  for (const rows of Object.values(out.search)) for (const r of rows) if (r.id && !r.error) all.set(r.id, r);
  const refTop = [...all.values()].sort((a, b) => (b.views || 0) - (a.views || 0)).slice(0, 6);
  let n = 0;
  for (const r of refTop) { if (Date.now() - t0 > BUDGET_MS) break; n++; if (await shot(p, r.id, OUTDIR + "/funds-ref-" + n + ".png")) out.shots.push({ file: "funds-ref-" + n + ".png", id: r.id }); }

  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(out));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

{
echo "# FUNDS の紹介投稿（話題順）（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。リポストもいいねもしない。キューを書き換えない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
[ "$CRC" -ne 0 ] && { echo '```'; rm -f "$RUNNER"; echo "**構文が通らない。走らせない。**"; exit 1; }
rm -f "$OUTDIR"/funds-ref-*.png
T0="$(date +%s)"
run_limited 285 "$RAW" node "$RUNNER" "$OUTDIR"; RC=$?
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
for f in "$OUTDIR"/funds-ref-*.png; do [ -s "$f" ] && printf '  見た目: %s（%s bytes）\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"; done
echo '```'
rm -f "$RUNNER"

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
    const shotOf = (id) => (j.shots || []).filter((s) => s.id === id).map((s) => "`" + s.file + "`").join(" ");

    console.log("\n## FUNDS の紹介投稿（話題順で検索）\n");
    const all = new Map();
    for (const [q, rows] of Object.entries(j.search || {})) {
      console.log("- 「" + q + "」: " + rows.length + " 本");
      for (const r of rows) if (r.id && !r.error) all.set(r.id, Object.assign({ q }, r));
    }
    const sorted = [...all.values()].sort((a, b) => (b.views || 0) - (a.views || 0));
    console.log("\n**重複を除いて " + sorted.length + " 本。表示の多い順。**\n");
    for (const r of sorted) {
      console.log("### 表示/いいね/RT/ブクマ/返信 " + num(r) + "  画像 " + r.images + " 枚" + (r.video ? "＋動画" : "") + "  重み " + w(r.text) + "  " + jst(r.at) + " " + shotOf(r.id) + "\n");
      console.log("```text\n" + (r.text || "(本文なし)") + "\n```\n");
    }
  ' "$RAW" 2>&1 | clean
else
  echo; echo "**出力が空。CDP か Chrome を確かめる**"
fi
rm -f "$RAW"

echo
echo "---"
echo
echo "**投稿していない。キューも書き換えていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$RUNNER" "$RAW"
if grep -aq 'FUNDS の紹介投稿（話題順で検索）' "$OUT" 2>/dev/null; then
  echo "FUNDS の紹介投稿を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
