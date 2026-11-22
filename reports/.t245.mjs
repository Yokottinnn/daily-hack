import { createRequire } from 'node:module';
const { chromium } = createRequire(process.env.PW_DIR + '/x.js')('playwright-core');
const IDS = ['s00000023355003','s00000024441001','s00000026575004','s00000026575013','s00000015597014','s00000026575008','s00000026575010','s00000023297001','s00000013470008','s00000025908001','s00000017066001','s00000018660001','s00000020637001','s00000024400001','s00000027196001','s00000027505001','s00000021551001','s00000005350011'];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
console.log('| programId | 名前 | 提携方式 | 成果報酬（広告側） |\n| --- | --- | --- | --- |');
for (const id of IDS) {
  try {
    await p.goto(`https://media-console.a8.net/program/detail?programId=${id}`, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await p.waitForTimeout(2500);
    const r = await p.evaluate(() => {
      const t = document.body.innerText;
      const h = [...document.querySelectorAll('h1,h2,h3')].map((e) => e.innerText.trim()).filter((x) => x && !/A8|メニュー|プログラム検索/.test(x));
      const mode = /即時提携/.test(t) ? '即時提携' : (/審査/.test(t) ? '審査あり' : '不明');
      const rew = (t.match(/成果報酬[\s\S]{0,80}/) || [''])[0].replace(/\s+/g, ' ').slice(0, 80);
      return { title: document.title.replace(/｜.*$/, '').trim(), h: h.slice(0, 2).join(' / '), mode, rew, login: !!document.querySelector('input[type=password]') };
    });
    if (r.login) { console.log(`| ${id} | （未ログイン） | | |`); continue; }
    console.log(`| ${id} | ${(r.h || r.title).replace(/\|/g, '／').slice(0, 70)} | ${r.mode} | ${r.rew.replace(/\|/g, '／')} |`);
  } catch (e) { console.log(`| ${id} | 失敗 ${String(e).slice(0, 60)} | | |`); }
}
await p.close(); process.exit(0);
