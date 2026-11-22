import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [["mofa", "https://www.mofa.go.jp/mofaj/kids/ranking/index.html"]];
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4500);
    for (const [w,h,n] of [[1280,900,'pc'],[390,844,'sp']]) { await p.setViewportSize({width:w,height:h}); await p.waitForTimeout(1200); await p.screenshot({path:`${D}/${k}-${n}.png`, fullPage:true}); }
    const t = await p.evaluate(() => document.body ? document.body.innerText : '');
    const ti = await p.title();
    fs.writeFileSync(`${D}/${k}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${t}`);
    console.log(`- ${k}: ${t.length} 文字 「${ti.slice(0,60)}」 → ${p.url().slice(0,90)}`);
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0,100)}`); }
}
await p.close().catch(() => {});
process.exit(0);
