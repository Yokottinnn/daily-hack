#!/bin/bash
# **卓上食洗機の比較記事のために、アイリスオーヤマの食器洗い乾燥機の公式ページ（仕様・写真）を読む（t970）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして。記事の質は絶対に下げないで」。blog3 が書く countertop-dishwasher-comparison-2026 の材料。
# クラウドからはアイリスオーヤマの公式サイトが 403 で読めないので、Mac の Chrome（CDP）で開く。Cookie の無い新しいコンテキストで開く（ログインの情報をレポートに入れない・t688 の反省）。
# 一覧・検索のページから「食器洗い」の製品ページを拾い、最大 6 ページの本文を reports/t970/*.txt、写真を reports/t970/img/（横 500px 以上・1 ページ 8 枚まで）に置く。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t970-dishwasher-iris.md"
PORT="${CDP_PORT:-18810}"
D="$RDIR/t970"; mkdir -p "$D/img"

{
  echo "# 食器洗い乾燥機 アイリスオーヤマの公式ページ（t970・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **\`playwright-core\` が無い。ここで止める。**" >> "$OUT"; cat "$OUT"; exit 0
fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。ここで止める。**" >> "$OUT"; cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"

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

SCRIPT="$RDIR/.t970.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 220000 - (Date.now() - t0);
const START = [
  ['search', 'https://www.irisohyama.co.jp/search/?q=%E9%A3%9F%E5%99%A8%E6%B4%97%E3%81%84%E4%B9%BE%E7%87%A5%E6%A9%9F'],
  ['cat1', 'https://www.irisohyama.co.jp/products/electrical-appliances/kitchen-appliances/dishwasher/'],
  ['cat2', 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/dishwasher/'],
];
const found = new Map();
async function grab(key, url, wantImgs) {
  const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await p.waitForTimeout(3500);
  await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 900) { window.scrollTo(0, y); await new Promise((s) => setTimeout(s, 120)); } });
  await p.waitForTimeout(1000);
  const title = await p.title();
  const text = await p.evaluate(() => document.body ? document.body.innerText : '');
  fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${title}\nURL: ${p.url()}\nSTATUS: ${r ? r.status() : '?'}\n\n${text.slice(0, 90000)}`);
  const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80) })).filter((l) => /dishwasher|dish-washer|shokusen|食器洗|食洗/i.test(l.h + ' ' + l.t)));
  console.log(`\n### ${key}（HTTP ${r ? r.status() : '?'}・「${title.slice(0, 70)}」・本文 ${text.length} 字・食洗機らしいリンク ${links.length}）\n- URL: ${p.url()}`);
  for (const l of links.slice(0, 30)) console.log(`  - link ${l.t} — ${l.h}`);
  if (wantImgs) {
    const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((i) => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || '').slice(0, 60) })).filter((i) => i.src && i.w >= 500 && !/\/news\//.test(i.src)));
    let n = 0;
    for (const im of [...new Map(imgs.map((i) => [i.src, i])).values()].slice(0, 8)) {
      try {
        const res = await ctx.request.get(im.src, { timeout: 15000 });
        const buf = await res.body();
        const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
        const name = `${key}-${String(++n).padStart(2, '0')}.${ext}`;
        fs.writeFileSync(`${D}/img/${name}`, buf);
        console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
      } catch (e) { console.log(`  - img ⚠️ ${im.src} ${String(e).slice(0, 80)}`); }
    }
  }
  return links;
}
for (const [key, url] of START) {
  if (left() < 30000) break;
  try {
    const links = await grab(key, url, false);
    for (const l of links) if (/irisohyama\.co\.jp\/products\//.test(l.h) && !/support|manual|\.pdf/.test(l.h)) found.set(l.h, l.t);
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
console.log(`\n## 製品ページの候補 ${found.size} 件`);
let i = 0;
for (const [url] of [...found].slice(0, 6)) {
  if (left() < 25000) { console.log('- ⏱ 時間切れ'); break; }
  try { await grab(`p${++i}`, url, true); } catch (e) { console.log(`- ⚠️ p${i}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t970-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
