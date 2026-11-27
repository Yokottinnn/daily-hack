import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });
const p = await ctx.newPage();
const page = 'https://www.kotsu.metro.tokyo.jp/pickup_information/news/bus/2026/bus_i_2026112712926_h.html';
const src = 'https://www.kotsu.metro.tokyo.jp/pickup_information/news/i/2026/bus_i_2026112712926_h_01.png';
try {
  await p.goto(page, { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(2500);
  const r = await p.request.get(src, { headers: { referer: page } });
  const buf = await r.body();
  console.log(`- 画像: HTTP ${r.status()} / ${r.headers()['content-type']} / ${buf.length} bytes`);
  if (r.status() === 200 && buf.length > 1000 && buf[0] === 0x89) { fs.writeFileSync(process.env.IMG, buf); console.log(`- 保存: ${process.env.IMG}`); }
  else console.log('- ⚠️ PNG ではない／小さすぎる。保存しない');
} catch (e) { console.log(`- ⚠️ 失敗: ${String(e).slice(0, 160)}`); }
await ctx.close().catch(() => {});
process.exit(0);
