#!/bin/bash
# **利用者が指定した参考投稿 5 本の画像（と GIF）を読む。読むだけ。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > 参考にして欲しい画像の構図の投稿をいくつか添付するね（4 本）
#   > こういうGIF画像も作れたらすごくいいかも。Grok Imagineで作ってるらしい（1 本）
#
# 投稿ごとに本文・数字・画像部分を撮る。動くもの（GIF・動画）は 1 秒おきに 4 コマ撮る。
#
# **投稿しない。リポストもいいねもしない。キューを書き換えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x205-read-$STAMP.js"
RAW="$W/.x205-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/user-design-refs.md"

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
// x205: 利用者が指定した参考投稿を読む。$0（LLM 不使用）。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const OUTDIR = process.argv[2];
const IDS = [
  ["u1", "2105766201133605154", "構図"],
  ["u2", "2103818619205640495", "構図"],
  ["u3", "2104030508716102123", "構図"],
  ["u4", "2104402968162496904", "構図"],
  ["u5", "2104813429634597159", "GIF"],
];
const t0 = Date.now();
const BUDGET_MS = 250 * 1000;
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
  await p.setViewportSize({ width: 900, height: 1800 });
  const out = [];
  for (const [tag, id, kind] of IDS) {
    if (Date.now() - t0 > BUDGET_MS) break;
    const r = { tag, id, kind, files: [] };
    try {
      await p.goto("https://x.com/i/status/" + id, { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(6500);
      if (/login|i\/flow/.test(p.url())) { console.log(JSON.stringify({ fatal: "ログインが切れている" })); process.exit(0); }
      const a = await p.$("article");
      if (!a) { r.error = "article が無い"; out.push(r); continue; }
      Object.assign(r, await a.evaluate((el) => {
        const tx = el.querySelector('[data-testid="tweetText"]');
        const g = el.querySelector('[role="group"][aria-label]');
        const tm = el.querySelector("time");
        return { text: tx ? tx.innerText : null, label: g ? g.getAttribute("aria-label") : null, at: tm ? tm.getAttribute("datetime") : null,
                 images: el.querySelectorAll('img[src*="pbs.twimg.com/media"]').length,
                 video: !!el.querySelector('video, [data-testid="videoPlayer"]') };
      }));
      Object.assign(r, parseLabel(r.label));
      await a.screenshot({ path: OUTDIR + "/" + tag + "-post.png" }); r.files.push(tag + "-post.png");
      const phs = await a.$$('[data-testid="tweetPhoto"]');
      let n = 0;
      for (const ph of phs.slice(0, 4)) { n++; try { await ph.screenshot({ path: OUTDIR + "/" + tag + "-img" + n + ".png" }); r.files.push(tag + "-img" + n + ".png"); } catch (e) {} }
      const vp = await a.$('[data-testid="videoPlayer"]') || await a.$("video");
      if (vp) {
        for (let f = 1; f <= 4; f++) {
          try { await vp.screenshot({ path: OUTDIR + "/" + tag + "-frame" + f + ".png" }); r.files.push(tag + "-frame" + f + ".png"); } catch (e) {}
          await p.waitForTimeout(1000);
        }
      }
    } catch (e) { r.error = String(e && e.message).slice(0, 160); }
    out.push(r);
  }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify({ rows: out }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

{
echo "# 利用者が指定した参考投稿（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
[ "$CRC" -ne 0 ] && { echo '```'; rm -f "$RUNNER"; echo "**構文が通らない。走らせない。**"; exit 1; }
rm -f "$OUTDIR"/u[1-5]-*.png
T0="$(date +%s)"
run_limited 285 "$RAW" node "$RUNNER" "$OUTDIR"; RC=$?
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
for f in "$OUTDIR"/u[1-5]-*.png; do [ -s "$f" ] && printf '  %s（%s bytes）\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"; done
echo '```'
rm -f "$RUNNER"
if [ -s "$RAW" ]; then
  node -e '
    const fs = require("fs");
    // **node -e では argv[1] が第 1 引数**
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("**JSON として読めない:**\n```\n" + fs.readFileSync(process.argv[1], "utf8").slice(0, 600) + "\n```"); process.exit(0); }
    if (j.fatal) { console.log("\n**止まった: " + j.fatal + "**"); process.exit(0); }
    for (const r of j.rows || []) {
      console.log("\n## " + r.tag + "（" + r.kind + "）  表示/いいね/RT/ブクマ/返信 " + [r.views, r.likes, r.reposts, r.bookmarks, r.replies].map((x) => x ?? "?").join(" / ") + "  画像 " + (r.images ?? "?") + " 枚" + (r.video ? "＋動き" : "") + (r.error ? "  **エラー: " + r.error + "**" : "") + "\n");
      console.log("撮ったもの: " + (r.files || []).join(" ") + "\n");
      console.log("```text\n" + (r.text || "(本文なし)") + "\n```");
    }
  ' "$RAW" 2>&1 | clean
else
  echo; echo "**出力が空。CDP か Chrome を確かめる**"
fi
rm -f "$RAW"
echo
echo "**投稿していない。キューも書き換えていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$RUNNER" "$RAW"
if grep -aq '^## u1' "$OUT" 2>/dev/null; then
  echo "参考投稿 5 本を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
