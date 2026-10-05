import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
const URLS = [
  ['A8.net', 'https://pub.a8.net/'],
  ['A8.net（提携中）', 'https://pub.a8.net/a8v2/media/partnerProgramListAction.do'],
  ['もしもアフィリエイト', 'https://af.moshimo.com/'],
  ['もしも（提携中）', 'https://af.moshimo.com/af/shop/promotion/list'],
  ['バリューコマース', 'https://aff.valuecommerce.ne.jp/'],
  ['バリューコマース（提携中）', 'https://aff.valuecommerce.ne.jp/report/ad'],
];
const KW = /提携|プログラム|プロモーション|広告|リンク|検索|案件|ショップ|セルフ/;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
for (const [k, u] of URLS) {
  if (Date.now() - T0 > 180000) { console.log(`## ${k}\n\n（時間切れ）\n`); continue; }
  console.log(`## ${k}\n\n- 開いた URL: ${u}`);
  try {
    const r = await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3000);
    const info = await p.evaluate((kw) => {
      const re = new RegExp(kw);
      const pw = !!document.querySelector('input[type=password]');
      const links = [...document.querySelectorAll('a')]
        .map(a => [(a.innerText || a.title || '').replace(/\s+/g, ' ').trim().slice(0, 40), a.href])
        .filter(([t, h]) => t && h && h.startsWith('http') && re.test(t));
      const seen = new Set(); const uniq = [];
      for (const l of links) { const key = l[0] + l[1]; if (!seen.has(key)) { seen.add(key); uniq.push(l); } }
      return { title: document.title.slice(0, 80), pw, links: uniq.slice(0, 40) };
    }, KW.source);
    console.log(`- 状態: ${r ? r.status() : '?'} / 最終 URL: ${p.url()}`);
    console.log(`- 題名: ${info.title}`);
    console.log(`- **パスワード欄: ${info.pw ? 'あり（＝ログインしていない可能性）' : 'なし'}**\n`);
    if (info.links.length) {
      console.log('| メニュー | URL |\n| --- | --- |');
      for (const [t, h] of info.links) console.log(`| ${t.replace(/\|/g, '／')} | ${h} |`);
    } else console.log('（該当するメニューのリンクなし）');
    console.log('');
  } catch (e) {
    console.log(`- ⚠️ 失敗: ${String(e).slice(0, 200)}\n`);
  }
}
await p.close();
process.exit(0);
