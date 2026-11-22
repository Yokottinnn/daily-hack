import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [["aeonretail", "https://aeonretail.com/Page/p-bf_advance.aspx"], ["dyson", "https://www.dyson.co.jp/deals"], ["mistore", "https://www.mistore.jp/shopping/feature/shops_f3/blackfriday_sp"], ["hanayashiki", "https://www.hanayashiki.net/events/event/BlackFriday2026/"], ["his", "https://www.his-j.com/campaign/blackfriday/kanto.html"], ["hands", "https://hands.net/season/black-friday/"], ["aoyama", "https://www.y-aoyama.jp/ec/shop/"], ["jal", "https://www.jal.co.jp/jp/ja/campaign/blackflyday/"], ["babiesrus", "https://www.babiesrus.co.jp/ja-jp/promotions/blackfriday-baby/"], ["toysrus", "https://www.toysrus.co.jp/ja-jp/promotions/blackfriday-toy/"], ["disney", "https://store.disney.co.jp/special/black-friday-sale.html"], ["uniqlo", "https://www.uniqlo.com/jp/ja/special-feature/kanshasai"], ["gu", "https://www.gu-global.com/jp/ja/feature/special/women"], ["hm", "https://www2.hm.com/ja_jp/seasonal/black-friday.html"], ["fujiya", "https://www.fujiya-peko.co.jp/cake/sougyousai/"], ["tower", "https://tower.jp/article/feature_item/2026/11/05/0104"], ["rakutencard", "https://www.rakuten-card.co.jp/campaign/spt/googlepay_touch/"], ["rakuten", "https://event.rakuten.co.jp/campaign/blackfriday/"], ["amazon", "https://www.amazon.co.jp/blackfriday"], ["welcia", "https://m.e-welcia.com/drug/202610_blackfriday_cp_app"], ["playstation", "https://store.playstation.com/ja-jp/pages/latest"], ["linegift", "https://gift.line.me/"]];
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4500);
    const t = await p.evaluate(() => document.body ? document.body.innerText : '');
    const ti = await p.title();
    fs.writeFileSync(`${D}/${k}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${t}`);
    console.log(`- ${k}: ${t.length} 文字 「${ti.slice(0,60)}」 → ${p.url().slice(0,90)}`);
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0,100)}`); }
}
await p.close().catch(() => {});
process.exit(0);
