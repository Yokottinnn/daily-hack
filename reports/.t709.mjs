import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [
  ["disney", "https://store.disney.co.jp/special/black-friday-sale.html"],
  ["amazonbf", "https://www.amazon.co.jp/blackfriday"],
];
const KEEP = /(\d{1,2}\/\d{1,2}|\d{1,2}月\d{1,2}日|20\d\d年|〜|～|まで|期間|OFF|％|%|ブラックフライデー|BLACK ?FRIDAY|先行|セール|ポイント)/i;
const DROP = /(こんにちは|様|お届け先|アカウント|ログイン|サインイン|注文履歴|郵便番号|〒|カート)/;
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(6000);
    await p.evaluate(()=>window.scrollTo(0,document.body.scrollHeight)).catch(()=>{});
    await p.waitForTimeout(1500);
    const t = await p.evaluate(() => document.body ? document.body.innerText : '');
    const ti = await p.title();
    const lines = [...new Set(t.split('\n').map(s=>s.trim()).filter(s=>s && s.length<=160 && KEEP.test(s) && !DROP.test(s)))].slice(0,120);
    console.log(`\n## ${k}\n\n- タイトル: ${DROP.test(ti) ? '(省略)' : ti}\n- URL: ${p.url().slice(0,120)}\n- 本文 ${t.length} 文字のうち、日付・割引の行 ${lines.length} 行\n\n\`\`\`text\n${lines.join('\n')}\n\`\`\``);
  } catch (e) { console.log(`\n## ${k}\n\n- ⚠️ ${String(e).slice(0,160)}`); }
}
await p.close().catch(() => {});
process.exit(0);
