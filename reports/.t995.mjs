import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D, TMPD = process.env.TMPD;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 }).catch(() => {});
const t0 = Date.now();
const left = () => 210000 - (Date.now() - t0);
// 1) 公式の 18L のページ: MO-F1808-B の節の写真と取扱説明書
try {
  const url = 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/microwave-microwave-oven/steam-oven/steam-oven-18l';
  const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await p.waitForTimeout(3000);
  await p.evaluate(() => { for (const e of document.querySelectorAll('a,button,span,div')) if ((e.innerText || '').trim() === 'もっと読む' && e.children.length === 0) e.click(); });
  await p.waitForTimeout(1500);
  await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 700) { window.scrollTo(0, y); await new Promise((s) => setTimeout(s, 150)); } });
  const text = await p.evaluate(() => (document.querySelector('main') || document.body).innerText);
  fs.writeFileSync(`${D}/official-18l.txt`, `URL: ${p.url()}\nSTATUS: ${r ? r.status() : '?'}\n\n${text.slice(0, 60000)}`);
  console.log(`## 公式 18L（HTTP ${r ? r.status() : '?'}・本文 ${text.length} 字）`);
  const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((im) => ({ src: im.currentSrc || im.src, w: im.naturalWidth, h: im.naturalHeight, alt: (im.alt || '').slice(0, 60) })).filter((im) => im.src && /web-catalog/.test(im.src)));
  let k = 0;
  for (const im of [...new Map(imgs.map((x) => [x.src, x])).values()].slice(0, 10)) {
    try {
      const res = await ctx.request.get(im.src, { timeout: 15000 });
      const buf = await res.body();
      const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
      const name = `official-${String(++k).padStart(2, '0')}.${ext}`;
      fs.writeFileSync(`${D}/img/${name}`, buf);
      console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
    } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
  }
  // MO-F1808-B の JAN 4967576495301 の近くの PDF（ページの PDF を全部挙げ、順番で対応づける）
  const pdfs = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => /\.pdf(\?|$)/i.test(h)));
  console.log(`- PDF ${pdfs.length} 件: ${pdfs.join(' ')}`);
  // 495301 を含む画像の ID から、MO-F1808-B の取扱説明書を探す（無ければ 2 本目＝ページの順）
  for (const [j, pdf] of pdfs.slice(0, 3).entries()) {
    if (left() < 120000) break;
    const res = await ctx.request.get(pdf, { timeout: 60000 });
    const buf = await res.body();
    fs.writeFileSync(`${TMPD}/m${j}.pdf`, buf);
    console.log(`  - PDF m${j} ${buf.length}B（HTTP ${res.status()}）${pdf} → 手元だけ`);
  }
} catch (e) { console.log(`- ⚠️ 公式: ${String(e).slice(0, 140)}`); }
// 2) Amazon の商品ページ（題名・色）
for (const asin of ['B09572Y1QQ', 'B09PRHJQC1']) {
  if (left() < 30000) break;
  try {
    await p.goto(`https://www.amazon.co.jp/dp/${asin}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3000);
    const v = await p.evaluate(() => {
      const title = ((document.querySelector('#productTitle') || {}).innerText || '').trim();
      const colors = [...document.querySelectorAll('#variation_color_name li, #inline-twister-row-color_name li, [id^="color_name_"]')].map((li) => (li.getAttribute('title') || li.innerText || '').replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 8);
      const model = [...document.querySelectorAll('#productDetails_techSpec_section_1 tr, #productOverview_feature_div tr, #detailBullets_feature_div li')].map((x) => x.innerText.replace(/\s+/g, ' ').trim()).filter((t) => /型番|モデル|メーカー/.test(t)).slice(0, 6);
      return { title: title.slice(0, 150), colors, model, cart: /カートに入れる|今すぐ買う/.test(document.body.innerText) };
    });
    console.log(`\n## Amazon ${asin}\n- 題名: ${v.title}\n- 色: ${v.colors.join(' / ') || '—'}\n- 型番の行: ${v.model.join(' ／ ') || '—'}\n- カート: ${v.cart ? 'あり' : '無い'}`);
  } catch (e) { console.log(`- ⚠️ Amazon ${asin}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
