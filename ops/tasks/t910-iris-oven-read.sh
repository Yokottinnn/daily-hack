#!/bin/bash
# **アイリスオーヤマのスチームオーブンレンジ・オーブンレンジの公式ページを読み、型番・仕様・製品写真を取る（t910）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして」。blog3 の oven-range-comparison-2026 の材料。
# irisohyama.co.jp はクラウドから 403 になるので、Mac の Chrome（CDP）で開く。Cookie の無い新しいコンテキストで開く（ログインの情報を持ち込まない・t688 の反省）。
# 結果: reports/t910-iris-oven.md（型番・仕様の本文の抜粋）、reports/t910/（ページ本文 .txt・画像）。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t910-iris-oven.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# アイリスオーヤマのオーブンレンジの公式ページ（t910・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **playwright-core がどちらにも無い。** ここで止める（推測で埋めない）。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: **\`$PWDIR\`** に在る" >> "$OUT"

VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** 新しく起動はしない。ここで止める。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"
echo "" >> "$OUT"

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

D="$RDIR/t910"; mkdir -p "$D"
SCRIPT="$RDIR/.t910.mjs"
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
async function save(url, name) {
  try {
    const r = await ctx.request.get(url, { timeout: 20000 });
    if (!r.ok()) { console.log(`  - 画像 ${name}: HTTP ${r.status()}`); return; }
    const buf = await r.body();
    const ct = r.headers()['content-type'] || '';
    const ext = /png/.test(ct) ? 'png' : /svg/.test(ct) ? 'svg' : /webp/.test(ct) ? 'webp' : 'jpg';
    fs.writeFileSync(`${D}/${name}.${ext}`, buf);
    console.log(`  - 画像 ${name}.${ext}: ${buf.length} bytes — ${url}`);
  } catch (e) { console.log(`  - 画像 ${name}: ${String(e).slice(0, 80)}`); }
}
// 1) カテゴリのページ
const CATS = ['https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/microwave-microwave-oven/steam-oven', 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/microwave-microwave-oven'];
const CAT = CATS[0];
let prods = [];
const seen = new Map();
let ci = 0;
for (const CATU of CATS) { ci++;
try {
  await p.goto(CATU, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await p.waitForTimeout(5000);
  await p.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await p.waitForTimeout(2000);
  const body = await p.evaluate(() => document.body ? document.body.innerText : '');
  fs.writeFileSync(`${D}/category${ci}.txt`, `TITLE: ${await p.title()}\nURL: ${p.url()}\n\n${body.slice(0, 40000)}`);
  console.log(`## カテゴリ「${await p.title()}」 ${body.length} 文字`);
  const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim() })));
  for (const l of links) {
    const u = l.h.split('#')[0];
    if (!/irisohyama\.co\.jp\/products\//.test(u) || CATS.includes(u.replace(/\/$/, ''))) continue;
    const isProd = /\/products\/.*(steam-oven|microwave-oven|oven)\/[^/?#]+/i.test(u) || /(MS|MO|IMB|MSO|MOF)-[A-Z0-9]{2,}/i.test(u + ' ' + l.t);
    if (!isProd || /部品|用品|角皿|レシピ|recipe|support/i.test(l.t + u)) continue;
    if (!seen.has(u) || (l.t.length > seen.get(u).length)) seen.set(u, l.t);
  }
  prods = [...seen.entries()];
  console.log(`- 製品らしいリンク ${prods.length} 件`);
  for (const [u, t] of prods.slice(0, 20)) console.log(`  - ${t.slice(0, 90)} — ${u}`);
  // 型番らしい語
  const codes = [...new Set((body.match(/[A-Z]{2,5}-[A-Z0-9]{2,8}(-[A-Z]{1,2})?/g) || []))].slice(0, 40);
  console.log(`- 本文の型番らしい語: ${codes.join(' / ')}`);
  // ロゴ（ヘッダー）
  const logo = await p.evaluate(() => { const i = [...document.querySelectorAll('header img, img[alt*="アイリス"], img[src*="logo"]')][0]; return i ? i.currentSrc || i.src : ''; });
  if (ci === 1) { if (logo) await save(logo, 'logo-iris'); else console.log('- ロゴの img が見つからない'); }
} catch (e) { console.log(`- ⚠️ カテゴリ: ${String(e).slice(0, 120)}`); }
}
// 2) 製品ページ（最大 6 件）
let k = 0;
for (const [u] of prods.slice(0, 7)) {
  if (left() < 25000) { console.log('- ⏱ 時間切れ'); break; }
  k++;
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3500);
    const ti = await p.title();
    const body = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/p${k}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${body.slice(0, 60000)}`);
    console.log(`\n## p${k}「${ti.slice(0, 80)}」 ${body.length} 文字\n- URL: ${p.url()}`);
    const pick = (re) => { const m = body.match(re); return m ? m[0].replace(/\s+/g, ' ').slice(0, 160) : '—'; };
    for (const [lab, re] of [['型番', /(型番|品番)[\s:：]*[A-Z0-9-]{4,20}/], ['容量', /(総庫内容量|庫内容量|容量)[^\n]{0,60}/], ['消費電力', /消費電力[^\n]{0,40}/], ['温度', /(オーブン温度|温度調節|最高温度)[^\n]{0,60}/], ['スチーム', /(スチーム|過熱水蒸気)[^\n]{0,60}/], ['設置', /(上方|cm以上|放熱|ピッタリ)[^\n]{0,60}/], ['メニュー', /(自動メニュー|メニュー数)[^\n]{0,50}/], ['寸法', /(外形寸法|サイズ)[^\n]{0,60}/], ['質量', /(質量|重量)[^\n]{0,30}/], ['発売', /発売[^\n]{0,40}/], ['価格', /(価格|税込)[^\n]{0,40}/]]) console.log(`- ${lab}: ${pick(re)}`);
    const og = await p.evaluate(() => (document.querySelector('meta[property="og:image"]') || {}).content || '');
    if (og) await save(og, `p${k}-og`);
    const imgs = await p.evaluate(() => [...document.images].filter((i) => i.naturalWidth >= 600 && i.naturalHeight >= 400).map((i) => ({ s: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, a: (i.alt || '').slice(0, 40) })).slice(0, 6));
    let j = 0;
    for (const im of imgs) { j++; console.log(`  - img${j} ${im.w}x${im.h} 「${im.a}」`); if (j <= 2) await save(im.s, `p${k}-img${j}`); }
  } catch (e) { console.log(`- ⚠️ p${k}: ${String(e).slice(0, 100)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t910-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
