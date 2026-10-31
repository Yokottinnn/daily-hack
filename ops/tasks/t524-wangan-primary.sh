#!/bin/bash
# **湾岸ニュース（2026-11-01 朝）の一次情報を読む（t524）。Google ニュースの記事を開いて本文と、そこから張られた主催者・区のページを追って本文を出す（カヤック・おもちゃ病院・江東湾岸まつりのブルーシャークス出展）。読むだけ・LLM 不使用・$0。**
# 定期タスク「湾岸ニュースの毎朝の記事」（利用者が 2026-10-24 に選んだ）。クラウドから江東区のサイトが開けないため Mac で読む。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t524-wangan-primary.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 湾岸ニュースの一次情報（t524・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

# ── playwright-core を探す（**棚卸しに書いてある場所から**） ──
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  {
    echo "⚠️ **\`playwright-core\` がどちらにも無い。**"
    echo ""
    echo '```text'
    ls -d "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules" 2>&1
    echo '```'
    echo ""
    echo "**ここで止める。** 推測で埋めない（最上位ルール 20）。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: **\`$PWDIR\`** に在る" >> "$OUT"

# ── Chrome が CDP で上がっているか（**ポートの LISTEN では足りない**・ルール 13） ──
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  {
    echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** 新しく起動はしない（t174 と同じ）"
    echo ""
    echo "**ここで止める。** Chrome が戻ってから同じものを出し直す。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"
echo "" >> "$OUT"

# ── 描画して読む ──────────────────────────────────────────
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}

# **拡張子は保つ**（`.new` 等を付けると Node が弾く・最上位ルール 14）
SCRIPT="$RDIR/.t524-prices.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const fs = await import('node:fs');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 });
const DIR = process.env.SHOT_DIR; fs.mkdirSync(DIR, { recursive: true });
const U = JSON.parse(fs.readFileSync(process.env.UJSON, 'utf8'));
const t0 = Date.now();
const seen = new Set();
async function dump(u, label, depth) {
  if (Date.now() - t0 > 205000 || seen.has(u)) return;
  seen.add(u);
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch((e) => console.log(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`));
  await p.waitForTimeout(3500);
  const d = await p.evaluate(() => {
    const t = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter((x) => x && x.length < 300);
    const links = [...document.querySelectorAll('article a[href], main a[href], .content a[href], a[href]')].map((a) => [a.innerText.trim().slice(0, 40), a.href]).filter(([, h]) => /city\.koto|city\.chuo|kayak|hobie|toyosu|omocha|おもちゃ|prtimes|\.lg\.jp|shimizu|bluesharks|wanganmatsuri|koto-wangan/i.test(h)).slice(0, 25);
    const imgs = [...document.querySelectorAll('img')].filter((i) => i.naturalWidth >= 600).map((i) => `${i.naturalWidth}x${i.naturalHeight} ${i.currentSrc || i.src}`).slice(0, 8);
    return { title: document.title, url: location.href, t: t.slice(0, 110), links, imgs };
  }).catch(() => ({ title: '（読めない）', url: u, t: [], links: [], imgs: [] }));
  console.log(`\n## ${label}｜${d.title}\n- ${d.url}`);
  for (const x of d.t) console.log(`  - ${x}`);
  for (const [tx, h] of d.links) console.log(`  - リンク: ${tx} → ${h}`);
  for (const i of d.imgs) console.log(`  - 画像: ${i}`);
  if (depth > 0) for (const [, h] of d.links.filter(([, h]) => !/news\.google/.test(h)).slice(0, 2)) await dump(h, label + ' の先', depth - 1);
}
for (const [label, u] of U) await dump(u, label, 1);
await p.close().catch(() => {});
process.exit(0);
JS
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
git -C "$REPO" show origin/main:ops/data/wangan-t524-urls.json > "$RDIR/.t524-urls.json" 2>/dev/null || { echo "⚠️ URL の JSON が main に無い" >> "$OUT"; cat "$OUT"; exit 0; }
RES="$RDIR/.t524-res.txt"
UJSON="$RDIR/.t524-urls.json" SHOT_DIR="$RDIR/t524-shots" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
head -c 12000 "$OUT"
