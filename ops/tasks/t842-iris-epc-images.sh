#!/bin/bash
# **アイリスオーヤマの電気圧力鍋 4.0L（KPC-MB4-B）の製品写真を公式ページから取る（t842）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして」。t841 で取れたのは 200px の og 画像だけだったので、製品ページの中の大きい画像を取り直す。
# irisohyama.co.jp はクラウドから 403 なので、Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開く。結果は reports/t842-iris-img.md と reports/t842/。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t842-iris-img.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{
  echo "# アイリスオーヤマ 電気圧力鍋の製品写真（t842・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then echo "⚠️ playwright-core が無い。ここで止める。" >> "$OUT"; cat "$OUT"; exit 0; fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then echo "⚠️ Chrome が CDP（$PORT）で応答しない。ここで止める。" >> "$OUT"; cat "$OUT"; exit 0; fi

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

D="$RDIR/t842"; mkdir -p "$D"
SCRIPT="$RDIR/.t842.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();
const p = await ctx.newPage();
async function save(url, name) {
  try {
    const r = await ctx.request.get(url, { timeout: 20000 });
    if (!r.ok()) { console.log(`  - ${name}: HTTP ${r.status()}`); return; }
    const buf = await r.body(); const ct = r.headers()['content-type'] || '';
    const ext = /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : 'jpg';
    fs.writeFileSync(`${D}/${name}.${ext}`, buf);
    console.log(`  - 保存 ${name}.${ext}: ${buf.length} bytes — ${url}`);
  } catch (e) { console.log(`  - ${name}: ${String(e).slice(0, 80)}`); }
}
const PAGES = [
  ['iris4', 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/pressure-cooker/electric-pressure-cooker/electric-pressure-cooker-4.0l'],
  ['plaza', 'https://www.irisplaza.co.jp/index.php?KB=SEARCH&SEARCH_WORD=KPC-MB4-B'],
];
for (const [key, url] of PAGES) {
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    for (let i = 1; i <= 6; i++) { await p.evaluate((y) => window.scrollTo(0, document.body.scrollHeight * y / 6), i); await p.waitForTimeout(600); }
    console.log(`\n## ${key}「${(await p.title()).slice(0, 70)}」\n- URL: ${p.url()}`);
    const imgs = await p.evaluate(() => {
      const out = [];
      for (const i of document.images) {
        const s = i.currentSrc || i.src || i.getAttribute('data-src') || '';
        if (!s || /\/news\//.test(s)) continue;
        out.push({ s, w: i.naturalWidth, h: i.naturalHeight, a: (i.alt || '').slice(0, 50) });
      }
      for (const el of document.querySelectorAll('[style*="background-image"]')) {
        const m = (el.getAttribute('style') || '').match(/url\(["']?([^"')]+)/); if (m) out.push({ s: new URL(m[1], location.href).href, w: 0, h: 0, a: 'bg' });
      }
      return out;
    });
    const seen = new Set(); const cand = [];
    for (const im of imgs) { if (seen.has(im.s)) continue; seen.add(im.s); if (/logo|icon|sns|btn|arrow|banner/i.test(im.s)) continue; if (im.w && im.w < 400) continue; cand.push(im); }
    console.log(`- 候補 ${cand.length} 枚（全 ${imgs.length}）`);
    let j = 0;
    for (const im of cand.slice(0, 14)) { j++; console.log(`  - ${key}-${j} ${im.w}x${im.h} 「${im.a}」 ${im.s}`); if (j <= 8) await save(im.s, `${key}-${j}`); }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 120)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t842-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 12000 "$OUT"
