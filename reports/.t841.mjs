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
const CAT = 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/pressure-cooker/electric-pressure-cooker';
let prods = [];
try {
  await p.goto(CAT, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await p.waitForTimeout(5000);
  await p.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await p.waitForTimeout(2000);
  const body = await p.evaluate(() => document.body ? document.body.innerText : '');
  fs.writeFileSync(`${D}/category.txt`, `TITLE: ${await p.title()}\nURL: ${p.url()}\n\n${body.slice(0, 40000)}`);
  console.log(`## カテゴリ「${await p.title()}」 ${body.length} 文字`);
  const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim() })));
  const seen = new Map();
  for (const l of links) {
    const u = l.h.split('#')[0];
    if (!/irisohyama\.co\.jp\/products\//.test(u) || u.replace(/\/$/, '') === CAT) continue;
    const isProd = /\/products\/[^?#]*\/\d{5,}|\/products\/detail|(PMPC|KPC|PC-[A-Z])/i.test(u) || (/圧力鍋/.test(l.t) && /\d\.\dL|[A-Z]{2,5}-[A-Z0-9]{2,}/.test(l.t));
    if (!isProd || /パッキン|内なべ|内鍋|部品|用品/.test(l.t)) continue;
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
  if (logo) await save(logo, 'logo-iris'); else console.log('- ロゴの img が見つからない');
} catch (e) { console.log(`- ⚠️ カテゴリ: ${String(e).slice(0, 120)}`); }
// 2) 製品ページ（最大 6 件）
let k = 0;
for (const [u] of prods.slice(0, 6)) {
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
    for (const [lab, re] of [['型番', /(型番|品番)[\s:：]*[A-Z0-9-]{4,20}/], ['容量', /(満水容量|調理容量|容量)[^\n]{0,60}/], ['消費電力', /消費電力[^\n]{0,40}/], ['圧力', /(圧力|kPa)[^\n]{0,60}/], ['メニュー', /(自動メニュー|メニュー数)[^\n]{0,50}/], ['寸法', /(外形寸法|サイズ)[^\n]{0,60}/], ['質量', /(質量|重量)[^\n]{0,30}/], ['発売', /発売[^\n]{0,40}/], ['価格', /(価格|税込)[^\n]{0,40}/]]) console.log(`- ${lab}: ${pick(re)}`);
    const og = await p.evaluate(() => (document.querySelector('meta[property="og:image"]') || {}).content || '');
    if (og) await save(og, `p${k}-og`);
    const imgs = await p.evaluate(() => [...document.images].filter((i) => i.naturalWidth >= 600 && i.naturalHeight >= 400).map((i) => ({ s: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, a: (i.alt || '').slice(0, 40) })).slice(0, 6));
    let j = 0;
    for (const im of imgs) { j++; console.log(`  - img${j} ${im.w}x${im.h} 「${im.a}」`); if (j <= 3) await save(im.s, `p${k}-img${j}`); }
  } catch (e) { console.log(`- ⚠️ p${k}: ${String(e).slice(0, 100)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
