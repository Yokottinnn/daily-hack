#!/bin/bash
# **フォロワー突破のお祝い投稿を、画像のデザインで幅広く集める。読むだけ。費用 $0。**
#
# ## 指示（2026-10-03・レビューページの画像へのコメント）
#
#   > 参考になるフォロワー突破のコメントを出している投稿をもっと幅広く分析して、
#   > ちゃんとデザインの調和が取れている投稿を探してきて、それを活用して
#
# x203 は 300 人の 3 語だけで、見た目は上位 4 本しか撮っていない。
# **人数を問わず 7 つの言い方で画像つきの投稿を集め、画像そのものを最大 28 枚 撮る。**
# 撮るのは検索結果の中の画像部分だけ（投稿を開き直さないので速い）。
#
# ## やらないこと
#
# **投稿しない。リポストもいいねもしない。キューを書き換えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x204-read-$STAMP.js"
RAW="$W/.x204-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/milestone-design-refs.md"

hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }
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
// x204: フォロワー突破の投稿を画像ごと集める。$0（LLM 不使用）。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const OUTDIR = process.argv[2];
const ME = "heng_ji31590";
const QUERIES = [
  "フォロワー 突破 ありがとう filter:images",
  "フォロワー 達成 感謝 filter:images",
  "フォロワー500人 filter:images",
  "フォロワー1000人 突破 filter:images",
  "フォロワー 突破 イラスト filter:images",
  "フォロワー300人 filter:images",
  "フォロワー 記念 ありがとう filter:images",
];
const MAX_SHOTS = 28;
const BUDGET_MS = 255 * 1000;
const t0 = Date.now();

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
  const rows = new Map();
  let shots = 0;

  for (const q of QUERIES) {
    if (Date.now() - t0 > BUDGET_MS) break;
    try {
      await p.goto("https://x.com/search?q=" + encodeURIComponent(q) + "&src=typed_query&f=top", { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(6000);
      if (/login|i\/flow/.test(p.url())) { console.log(JSON.stringify({ fatal: "ログインが切れている" })); process.exit(0); }
      for (let r = 0; r < 3 && Date.now() - t0 < BUDGET_MS; r++) {
        for (const a of await p.$$("article")) {
          const info = await a.evaluate((el) => {
            const link = [...el.querySelectorAll('a[href*="/status/"]')]
              .map((x) => (x.getAttribute("href") || "").match(/^\/([^/]+)\/status\/(\d+)/)).filter(Boolean)[0];
            const tx = el.querySelector('[data-testid="tweetText"]');
            const g = el.querySelector('[role="group"][aria-label]');
            const tm = el.querySelector("time");
            return { author: link ? link[1] : null, id: link ? link[2] : null, at: tm ? tm.getAttribute("datetime") : null,
                     text: tx ? tx.innerText : null, label: g ? g.getAttribute("aria-label") : null,
                     images: el.querySelectorAll('img[src*="pbs.twimg.com/media"]').length };
          }).catch(() => null);
          if (!info || !info.id || info.author === ME || rows.has(info.id)) continue;
          Object.assign(info, parseLabel(info.label), { q });
          if (info.images > 0 && shots < MAX_SHOTS && /フォロワ|follower/i.test(info.text || "")) {
            const ph = await a.$('[data-testid="tweetPhoto"]');
            if (ph) {
              try {
                await ph.scrollIntoViewIfNeeded(); await p.waitForTimeout(700);
                const f = "ms-" + String(shots + 1).padStart(2, "0") + ".png";
                await ph.screenshot({ path: OUTDIR + "/" + f }); info.shot = f; shots++;
              } catch (e) {}
            }
          }
          rows.set(info.id, info);
        }
        await p.evaluate(() => window.scrollBy(0, 2400));
        await p.waitForTimeout(1600);
      }
    } catch (e) {}
  }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify({ rows: [...rows.values()], shots }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

{
echo "# フォロワー突破の投稿・画像のデザイン（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。リポストもいいねもしない。キューを書き換えない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
[ "$CRC" -ne 0 ] && { echo '```'; rm -f "$RUNNER"; echo "**構文が通らない。走らせない。**"; exit 1; }
rm -f "$OUTDIR"/ms-*.png
T0="$(date +%s)"
run_limited 285 "$RAW" node "$RUNNER" "$OUTDIR"; RC=$?
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
NS=0; for f in "$OUTDIR"/ms-*.png; do [ -s "$f" ] && NS=$((NS + 1)); done
printf '  撮れた画像 %s 枚\n' "$NS"
echo '```'
rm -f "$RUNNER"

if [ -s "$RAW" ]; then
  node -e '
    const fs = require("fs");
    // **node -e では argv[1] が第 1 引数**
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("**JSON として読めない:**\n```\n" + fs.readFileSync(process.argv[1], "utf8").slice(0, 600) + "\n```"); process.exit(0); }
    if (j.fatal) { console.log("\n**止まった: " + j.fatal + "**"); process.exit(0); }
    const jst = (s) => s ? new Date(new Date(s).getTime() + 9 * 3600e3).toISOString().slice(0, 10) : "?";
    const num = (r) => [r.views, r.likes, r.reposts, r.bookmarks, r.replies].map((x) => x ?? "?").join(" / ");
    const shot = (j.rows || []).filter((r) => r.shot).sort((a, b) => (b.views || 0) - (a.views || 0));
    console.log("\n## 画像を撮った投稿（" + shot.length + " 本・表示の多い順）\n");
    console.log("集めた投稿は重複を除いて " + (j.rows || []).length + " 本。そのうちフォロワーの話で画像つきのものを撮った。\n");
    for (const r of shot) {
      console.log("### `" + r.shot + "`  表示/いいね/RT/ブクマ/返信 " + num(r) + "  画像 " + r.images + " 枚  " + jst(r.at) + "  （" + r.q.replace(/ filter:images/, "") + "）\n");
      console.log("```text\n" + String(r.text || "(本文なし)").slice(0, 300) + "\n```\n");
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
if grep -aq '画像を撮った投稿' "$OUT" 2>/dev/null; then
  echo "フォロワー突破の画像を集めた / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
