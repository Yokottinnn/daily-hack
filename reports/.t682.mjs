import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [["aeon", "https://chirashi.otoku.aeonsquare.net/pc/chirashi/blackfriday/"], ["aeonpoint", "https://chirashi.otoku.aeonsquare.net/pc/chirashi/point_stepup/"], ["nitori", "https://www.nitori-net.jp/ec/characteristic/campaign/hikitori/"], ["akachan", "https://chirashi.akachan.jp/chirashi/special/akatoku/"], ["owndays", "https://www.owndays.com/jp/ja/news/blackfriday"], ["zoff", "https://www.zoff.co.jp/shop/contents/blackfriday_store.aspx"], ["dennys", "https://www.dennys.jp/campaign/blackfriday/"], ["lalaport", "https://mitsui-shopping-park.com/lalaport/special/blackfriday_2026_11/"], ["mop", "https://mitsui-shopping-park.com/mop/special/2611_blackfriday/"], ["premium", "https://www.premiumoutlets.co.jp/"], ["premiumsale", "https://www.premiumoutlets.co.jp/sp/pos_202611/"], ["googlestore", "https://store.google.com/jp/?hl=ja"], ["gapjp", "https://www.gap.co.jp/news/post/?news_id=1400"], ["aoyamatop", "https://www.y-aoyama.jp/"], ["amazonbf", "https://www.amazon.co.jp/b?node=24216006051"]];
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(6000); await p.evaluate(()=>window.scrollTo(0,document.body.scrollHeight)).catch(()=>{}); await p.waitForTimeout(1500);
    const t = await p.evaluate(() => document.body ? document.body.innerText : '');
    const ti = await p.title();
    fs.writeFileSync(`${D}/${k}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${t}`);
    console.log(`- ${k}: ${t.length} 文字 「${ti.slice(0,60)}」 → ${p.url().slice(0,90)}`);
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0,100)}`); }
}
await p.close().catch(() => {});
process.exit(0);
