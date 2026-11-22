import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const L = JSON.parse(fs.readFileSync(process.env.LJSON, 'utf8'));
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const t0 = Date.now();
let n = 0;
for (const [key, url] of L) {
  if (Date.now() - t0 > 200000) { console.log('- ⏱ 時間切れ'); break; }
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3500);
    const r = await p.evaluate((k) => {
      const t = document.body ? document.body.innerText : '';
      const names = [...document.querySelectorAll('h2 a, [class*="title"] a, a h2, [data-testid*="title"]')].map((e) => e.textContent.trim()).filter((s) => s.length > 8 && s.includes(k)).slice(0, 3);
      return { title: document.title.slice(0, 80), hits: t.split(k).length - 1, names };
    }, key);
    const host = new URL(p.url()).host;
    const tagOk = /tag=dailyhack-22|scid=af_|sc_e=afvc|valuecommerce/.test(p.url()) ? '計測の印あり' : '計測の印なし';
    n++;
    console.log(`- **${key}** ${host} — 型番の出現 ${r.hits} 回 — ${tagOk}\n  - 着いた先: ${p.url().slice(0, 160)}\n  - 題名: ${r.title}\n  - 上位: ${r.names.map((s) => s.slice(0, 60)).join(' / ') || '（取れず）'}`);
  } catch (e) { console.log(`- **${key}** ⚠️ ${String(e).slice(0, 120)} ${url.slice(0, 100)}`); }
}
console.log(`\n対象 ${L.length} / 開けた ${n}`);
await p.close().catch(() => {});
process.exit(0);
