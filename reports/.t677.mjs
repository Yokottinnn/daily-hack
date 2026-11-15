import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [['metro','https://www.tokyometro.jp/corporate/enterprise/passenger_rail/transportation/passengers/index.html'],['toei','https://www.kotsu.metro.tokyo.jp/subway/kanren/passengers.html']];
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(6000);
    const html = await p.content();
    fs.writeFileSync(`${D}/${k}.html`, html);
    console.log(`- ${k}: ${html.length} 文字 「${(await p.title()).slice(0,60)}」`);
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map(a => [a.href, a.textContent.replace(/\s+/g,' ').trim().slice(0,60)]).filter(([h]) => /\.(pdf|xlsx?|csv)(\?|$)/i.test(h)));
    console.log(`  ファイルのリンク ${links.length} 本`);
    for (const [h,t] of links.slice(0,40)) console.log(`  ${h} | ${t}`);
    let n=0;
    for (const [h] of links.slice(0,6)) {
      try {
        const b64 = await p.evaluate(async (url) => { const r = await fetch(url, {credentials:'include'}); const a = new Uint8Array(await r.arrayBuffer()); let s=''; for (let i=0;i<a.length;i+=32768) s+=String.fromCharCode.apply(null, a.subarray(i,i+32768)); return [r.status, btoa(s)]; }, h);
        const ext = (h.match(/\.(pdf|xlsx?|csv)/i)||['','bin'])[1];
        const buf = Buffer.from(b64[1], 'base64'); fs.writeFileSync(`${D}/${k}-${n}.${ext}`, buf);
        console.log(`  保存 ${k}-${n}.${ext} ← ${h} → ${b64[0]} ${buf.length} bytes ${buf.slice(0,5).toString('latin1').replace(/[^A-Za-z%<!-]/g,'')}`); n++;
      } catch (e) { console.log(`  ⚠️ 取れない ${h}: ${String(e).slice(0,100)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${k} を開けない: ${String(e).slice(0,120)}`); }
}
await p.close().catch(() => {});
process.exit(0);
