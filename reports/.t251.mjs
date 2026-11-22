import { createRequire } from 'node:module';
import fs from 'node:fs'; import path from 'node:path'; import os from 'node:os';
const d = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')].find((x) => fs.existsSync(path.join(x, 'playwright-core')));
const { chromium } = createRequire(path.join(d, 'x.js'))('playwright-core');
const b = await chromium.connectOverCDP('http://127.0.0.1:18810').catch((e) => { console.log('CDP につながらない: ' + e); process.exit(0); });
const ctx = b.contexts()[0];
console.log('## 2. 楽天の Cookie（値は出さない・名前と期限だけ）'); console.log('```text');
const now = Date.now() / 1000;
const cs = (await ctx.cookies()).filter((c) => /rakuten/.test(c.domain));
for (const c of cs.sort((a, z) => a.domain.localeCompare(z.domain))) {
  const exp = c.expires > 0 ? `${new Date(c.expires * 1000).toISOString().slice(0, 10)}（あと ${((c.expires - now) / 86400).toFixed(1)} 日）` : 'ブラウザを閉じるまで';
  console.log(`${c.domain}  ${c.name}  ${exp}`);
}
console.log(`（計 ${cs.length} 件）`); console.log('```');
// 手ログインしたタブがあれば、そのまま読む
const pages = ctx.pages();
console.log('## 3. 開いているタブ'); console.log('```text');
for (const p of pages) console.log(p.url().slice(0, 120));
console.log('```');
const p = await ctx.newPage();
console.log('## 4. 楽天アフィリエイトを開く'); console.log('```text');
for (const u of ['https://affiliate.rakuten.co.jp/', 'https://affiliate.rakuten.co.jp/report/summary']) {
  let ok = false;
  for (let i = 0; i < 3 && !ok; i++) {
    try { await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }); ok = true; }
    catch (e) { console.log(`試行${i + 1} 失敗: ${String(e).split('\n')[0]}`); await p.waitForTimeout(3000); }
  }
  if (!ok) continue;
  await p.waitForTimeout(3500);
  const s = await p.evaluate(() => {
    const t = document.body.innerText || '';
    return {
      url: location.href, title: document.title,
      pw: !!document.querySelector('input[type=password]'),
      logout: [...document.querySelectorAll('a,button')].some((el) => /ログアウト|logout/i.test(el.innerText || el.href || '')),
      loginCta: /ログインして|ログインする|楽天会員ログイン/.test(t),
      // アフィリエイト ID（公開リンクに必ず入る値。xxxxxxxx.xxxxxxxx.xxxxxxxx.xxxxxxxx の形）
      afid: (t.match(/[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}/) || (document.documentElement.innerHTML.match(/hgc\/([0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8})/) || [])[1] || [])[0] || (document.documentElement.innerHTML.match(/hgc\/([0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8})/) || [])[1] || '',
    };
  });
  console.log(JSON.stringify(s));
}
console.log('```');
await p.close();
