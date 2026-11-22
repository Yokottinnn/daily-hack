import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [
  ["marche-dmenu", "https://news.google.com/rss/articles/CBMigwFBVV95cUxOZ0tNUmFqWm5IOXRieUVKT29SOW1yZWlZS29kRDdiYWVoMXd4M0NqcUxWZjc5N0ZqYlp0cVlvdU1KZ0V2eTlleDhpOWQ1T1N5ZUJEV3Q0WkNua21MYVI3Yl8tOERDU0J4LVJMZEZ4V1huU01CNkxvUEktTXhrRVQxZHZpQdIBgwFBVV95cUxOZ0tNUmFqWm5IOXRieUVKT29SOW1yZWlZS29kRDdiYWVoMXd4M0NqcUxWZjc5N0ZqYlp0cVlvdU1KZ0V2eTlleDhpOWQ1T1N5ZUJEV3Q0WkNua21MYVI3Yl8tOERDU0J4LVJMZEZ4V1huU01CNkxvUEktTXhrRVQxZHZpQQ?oc=5"],
  ["yoga-walker", "https://news.google.com/rss/articles/CBMiW0FVX3lxTE5pLWFOT1FYaDdDNHIxYUpFWXJ0azBfcnlDdHRvTFBydEpjeEJuQUVXeDZBT1dYMUpKWWdONUh4VUYwT3gtWHZDN3l5SFQyTnZNa052QjZUX3lvOVk?oc=5"],
  ["scsk-ref", "https://news.google.com/rss/articles/CBMibEFVX3lxTE84Nktva3BKUjg2ZjFGX1dfa2xXMEs1V1NGWUkyd3BDY0Q2UFJIVUJyTi1Bckszby1aNkpOUzA2SlpaYnJoRGNzd2ZwV3JpbWNTWWM5WXl1SHhoZ1Q5N1BFTDVKTzlpN2E4SWRQbQ?oc=5"],
];
const KEEP = /(20\d\d年|\d{1,2}月\d{1,2}日|\d{1,2}\/\d{1,2}|時|分|円|無料|会場|場所|住所|主催|共催|後援|定員|先着|申込|締切|対象|豊洲|晴海|江東区|中央区|マルシェ|ヨガ|こよみ|SCSK|三陸|常磐|試食|販売|出店|雨天|中止|持ち物|問い合わせ|URL|http)/;
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 30000 });
    for (let i = 0; i < 10 && /news\.google\.com/.test(p.url()); i++) await p.waitForTimeout(1500);
    await p.waitForTimeout(4000);
    const d = await p.evaluate(() => {
      const main = document.querySelector('article') || document.querySelector('main') || document.body;
      const links = [...main.querySelectorAll('a[href]')].map(a => [a.href, (a.textContent||'').trim().slice(0,60)]).filter(([h]) => /^https?:/.test(h) && !/twitter\.com\/intent|facebook\.com\/share|line\.me\/R|google|doubleclick/.test(h));
      const imgs = [...main.querySelectorAll('img')].map(i => [i.currentSrc || i.src, i.naturalWidth, i.naturalHeight, (i.alt||'').slice(0,60)]).filter(x => x[1] >= 300);
      const og = document.querySelector('meta[property="og:image"]')?.content || '';
      return { t: main.innerText || '', links, imgs, og, title: document.title };
    });
    const lines = [...new Set(d.t.split('\n').map(s=>s.trim()).filter(s=>s && s.length<=220 && KEEP.test(s)))].slice(0,110);
    console.log(`\n## ${k}\n\n- タイトル: ${d.title}\n- 行き先: ${p.url()}\n- og:image: ${d.og}\n- 本文 ${d.t.length} 文字のうち、日付・場所・料金の行 ${lines.length} 行\n\n\`\`\`text\n${lines.join('\n')}\n\`\`\`\n\n### リンク（本文の中・上位 40）\n\n\`\`\`text\n${[...new Map(d.links.map(x=>[x[0],x])).values()].slice(0,40).map(x=>x.join(' | ')).join('\n')}\n\`\`\`\n\n### 画像（幅 300 以上）\n\n\`\`\`text\n${d.imgs.slice(0,15).map(x=>x.join(' | ')).join('\n')}\n\`\`\``);
  } catch (e) { console.log(`\n## ${k}\n\n- ⚠️ ${String(e).slice(0,160)}`); }
}
await p.close().catch(() => {});
process.exit(0);
