import { createRequire } from 'node:module';
const { chromium } = createRequire(process.env.PW_DIR + '/x.js')('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();   // **閉じない**（利用者がこのタブでログインする）
await p.goto('https://affiliate.rakuten.co.jp/report/summary', { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
await p.bringToFront();
console.log(`- 開いた: ${p.url().slice(0, 80)}`);
console.log(`- 題名: ${await p.title()}`);
process.exit(0);
