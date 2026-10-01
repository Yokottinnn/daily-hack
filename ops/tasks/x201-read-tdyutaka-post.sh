#!/bin/bash
# **利用者に「これも投稿して欲しい」と渡された X 投稿を読む。読むだけ。費用 $0。**
#
#   https://x.com/tdyutaka/status/2104380946015457540
#
# クラウドからは x.com が egress で塞がれている（2026-10-01 に実測）。Mac で読む。
# **中身を見ずに「たぶんこういう投稿」で作らない**（最上位ルール 20）。
#
# ## 読むもの
#
#   ① 本文（改行そのまま）・画像の枚数・リンクカード・引用ポスト・数字
#   ② 同じ人の続き（スレッドになっているか）
#   ③ **投稿の見た目をそのまま撮る**（画像の中身はテキストで取れないので）
#      → `$OPS_REPORT_DIR/tdyutaka-post.png`（ops/heartbeat に push される）
#
# ## やらないこと
#
# **投稿しない。リポストもいいねもしない。何も書き換えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x201-read-$STAMP.js"
RAW="$W/.x201-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/read-tdyutaka.md"
PNG="$OUTDIR/tdyutaka-post.png"

keepers='tdyutaka|heng_ji31590'
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
// x201: 渡された X 投稿を読む。$0（LLM 不使用）。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const AUTHOR = "tdyutaka", ID = "2104380946015457540";
const PNG = process.argv[2];

function parseLabel(s) {
  const pick = (re) => { const m = String(s || "").match(re); return m ? Number(m[1].replace(/,/g, "")) : null; };
  return { replies: pick(/([\d,]+)\s*件の返信/), reposts: pick(/([\d,]+)\s*件のリポスト/),
           likes: pick(/([\d,]+)\s*件のいいね/), views: pick(/([\d,]+)\s*件の表示/),
           bookmarks: pick(/([\d,]+)\s*件のブックマーク/) };
}

(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log(JSON.stringify({ fatal: "context が無い" })); process.exit(0); }
  const p = await ctx.newPage();
  await p.setViewportSize({ width: 700, height: 1600 });
  const out = {};
  try {
    await p.goto("https://x.com/" + AUTHOR + "/status/" + ID, { waitUntil: "domcontentloaded", timeout: 45000 });
    await p.waitForTimeout(8000);
    if (/login|i\/flow/.test(p.url())) { console.log(JSON.stringify({ fatal: "ログインが切れている" })); process.exit(0); }
    out.articles = await p.evaluate(() => [...document.querySelectorAll("article")].slice(0, 8).map((a) => {
      const link = [...a.querySelectorAll('a[href*="/status/"]')]
        .map((x) => (x.getAttribute("href") || "").match(/^\/([^/]+)\/status\/(\d+)/)).filter(Boolean)[0];
      const tx = a.querySelector('[data-testid="tweetText"]');
      const g = a.querySelector('[role="group"][aria-label]');
      const card = a.querySelector('[data-testid="card.wrapper"]');
      const quote = a.querySelector('div[role="link"] [data-testid="tweetText"]');
      return {
        author: link ? link[1] : null, id: link ? link[2] : null,
        at: (a.querySelector("time") || {}).getAttribute ? a.querySelector("time").getAttribute("datetime") : null,
        text: tx ? tx.innerText : null,
        label: g ? g.getAttribute("aria-label") : null,
        images: [...a.querySelectorAll('img[src*="pbs.twimg.com/media"]')].map((i) => i.src.split("?")[0]),
        video: !!a.querySelector('[data-testid="videoPlayer"]'),
        card: card ? card.innerText.slice(0, 300) : null,
        quote: quote ? quote.innerText.slice(0, 400) : null,
        links: [...(tx ? tx.querySelectorAll("a[href]") : [])].map((x) => x.href).slice(0, 8),
      };
    }));
    for (const r of out.articles) Object.assign(r, parseLabel(r.label));
    // ③ 見た目をそのまま撮る（指定の投稿の article）
    const idx = out.articles.findIndex((r) => r.id === ID);
    const handles = await p.$$("article");
    if (idx >= 0 && handles[idx]) { await handles[idx].screenshot({ path: PNG }); out.png = true; }
  } catch (e) { out.error = String(e && e.message).slice(0, 200); }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(out, null, 1));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

{
echo "# 渡された X 投稿を読む（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> https://x.com/tdyutaka/status/2104380946015457540"
echo "> **投稿しない。リポストもいいねもしない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
[ "$CRC" -ne 0 ] && { echo '```'; rm -f "$RUNNER"; echo "**構文が通らない。走らせない。**"; exit 1; }
rm -f "$PNG"
T0="$(date +%s)"
run_limited 150 "$RAW" node "$RUNNER" "$PNG"; RC=$?
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
if [ -s "$PNG" ]; then printf '  見た目: tdyutaka-post.png（%s bytes）\n' "$(wc -c < "$PNG" | tr -d ' ')"; else echo "  **見た目は撮れていない**"; fi
echo '```'
rm -f "$RUNNER"
if [ -s "$RAW" ]; then
  node -e '
    const fs = require("fs");
    // **node -e では argv[1] が第 1 引数**
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("**JSON として読めない:**\n```\n" + fs.readFileSync(process.argv[1], "utf8").slice(0, 600) + "\n```"); process.exit(0); }
    if (j.fatal) { console.log("\n**止まった: " + j.fatal + "**"); process.exit(0); }
    if (j.error) console.log("\n**エラー: " + j.error + "**");
    const w = (s) => { let n = 0; for (const c of String(s || "")) n += c.codePointAt(0) < 0x80 ? 1 : 2; return n; };
    const jst = (s) => s ? new Date(new Date(s).getTime() + 9 * 3600e3).toISOString().slice(0, 16).replace("T", " ") + " JST" : "?";
    (j.articles || []).forEach((r, i) => {
      console.log("\n## " + (i + 1) + ". @" + r.author + " / " + r.id + (r.id === "2104380946015457540" ? "  ← **指定の投稿**" : "") + "\n");
      console.log("| | |\n| --- | --- |");
      console.log("| 投稿時刻 | " + jst(r.at) + " |");
      console.log("| 表示 / いいね / RT / ブクマ / 返信 | " + [r.views, r.likes, r.reposts, r.bookmarks, r.replies].map((x) => x ?? "?").join(" / ") + " |");
      console.log("| 画像 | " + r.images.length + " 枚" + (r.video ? " ＋ 動画" : "") + " |");
      console.log("| 重み | " + w(r.text) + " |");
      console.log("\n```text\n" + (r.text || "(本文なし)") + "\n```");
      if (r.links.length) console.log("\n**本文のリンク**\n```\n" + r.links.join("\n") + "\n```");
      if (r.card) console.log("\n**リンクカード**\n```text\n" + r.card + "\n```");
      if (r.quote) console.log("\n**引用ポスト**\n```text\n" + r.quote + "\n```");
      if (r.images.length) console.log("\n**画像の URL**\n```\n" + r.images.join("\n") + "\n```");
    });
  ' "$RAW" 2>&1 | clean
else
  echo; echo "**出力が空。CDP か Chrome を確かめる**"
fi
rm -f "$RAW"
echo
echo "---"
echo
echo "**投稿していない。リポストもいいねもしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$RUNNER" "$RAW"
if grep -aq '指定の投稿' "$OUT" 2>/dev/null; then
  echo "渡された投稿を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
