import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1280, height: 900 } });
const p = await ctx.newPage();
const qs = ['HF3030JBK', 'HF3030', 'ブラウン ノンフライヤー HF3030JBK', 'ブラウン ノンフライヤー', 'ブラウン マルチフライ3', 'BRAUN ノンフライヤー'];
for (const q of qs) {
  try {
    await p.goto(`https://shopping.yahoo.co.jp/search?p=${encodeURIComponent(q)}`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3500);
    const r = await p.evaluate(() => {
      const names = [...document.querySelectorAll('a[href*="store.shopping.yahoo.co.jp"], a[href*="paypaymall"]')].map((a) => (a.innerText || '').replace(/\s+/g, ' ').trim()).filter((t) => t.length > 15);
      const hit = [...new Set(names.filter((t) => /HF3030/i.test(t)))];
      const none = /該当する商品が見つかりませんでした|一致する商品はありません|見つかりませんでした/.test(document.body.innerText);
      return { n: names.length, hit: hit.slice(0, 5), none };
    });
    console.log(`- 「${q}」: 商品名 ${r.n} 件・HF3030 を含む ${r.hit.length} 件${r.none ? '・該当なしの表示' : ''}`);
    for (const h of r.hit) console.log(`  - ${h.slice(0, 120)}`);
  } catch (e) { console.log(`- 「${q}」: ⚠️ ${String(e).slice(0, 100)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
