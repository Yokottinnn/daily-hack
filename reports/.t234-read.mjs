import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
const URLS = [
  ['jal', 'https://www.jal.co.jp/jp/ja/jmb/wellness/'],
  ['jal-news', 'https://www.jal.co.jp/jp/ja/jmb/wellness/news/'],
  ['jal-faq', 'https://www.jal.co.jp/jp/ja/jmb/wellness/faq/'],
  ['dhc', 'https://health.docomo.ne.jp/'],
  ['dhc-premium', 'https://health.docomo.ne.jp/premium/'],
  ['every', 'https://every-point.jp/'],
  ['poisura', 'https://poisura.com/'],
  ['stella', 'https://stellarwalk.jp/'],
  ['healthree', 'https://healthree.io/'],
  ['cokeon-walk', 'https://c.cocacola.co.jp/app/walk/'],
  ['rakuten-hc', 'https://healthcare.rakuten.co.jp/'],
  ['arucoin', 'https://arucoin.jp/'],
];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
for (const [k, u] of URLS) {
  if (Date.now() - T0 > 200000) { console.log(`## ${k}\n\n（時間切れで読んでいない）\n`); continue; }
  console.log(`## ${k}\n\n- URL: ${u}`);
  try {
    const r = await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await p.waitForTimeout(2500);
    console.log(`- 状態: ${r ? r.status() : '?'} / 最終 URL: ${p.url()}\n`);
    let t = await p.evaluate(() => document.body ? document.body.innerText : '');
    t = t.split('\n').map(s => s.trim()).filter(Boolean).join('\n');
    console.log('```text\n' + t.slice(0, 7000) + '\n```\n');
  } catch (e) {
    console.log(`- ⚠️ 失敗: ${String(e).slice(0, 200)}\n`);
  }
}
await p.close();
process.exit(0);
