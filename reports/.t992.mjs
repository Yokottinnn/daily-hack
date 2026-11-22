import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 }).catch(() => {});
const t0 = Date.now();
const left = () => 200000 - (Date.now() - t0);
const MODEL = /(MS|MO|KMO)-?F?S?\d{4}(-?[A-Z])?/i;
const SEARCHES = [
  ['rakuten', 'MS-F2601', 'https://search.rakuten.co.jp/search/mall/MS-F2601/'],
  ['rakuten', 'JAN 4967576535052', 'https://search.rakuten.co.jp/search/mall/4967576535052/'],
  ['rakuten', 'アイリスオーヤマ スチームオーブンレンジ', 'https://search.rakuten.co.jp/search/mall/%E3%82%A2%E3%82%A4%E3%83%AA%E3%82%B9%E3%82%AA%E3%83%BC%E3%83%A4%E3%83%9E+%E3%82%B9%E3%83%81%E3%83%BC%E3%83%A0%E3%82%AA%E3%83%BC%E3%83%96%E3%83%B3%E3%83%AC%E3%83%B3%E3%82%B8/'],
  ['yahoo', 'MS-F2601-B', 'https://shopping.yahoo.co.jp/search?p=MS-F2601-B'],
  ['yahoo', 'アイリスオーヤマ スチームオーブンレンジ', 'https://shopping.yahoo.co.jp/search?p=%E3%82%A2%E3%82%A4%E3%83%AA%E3%82%B9%E3%82%AA%E3%83%BC%E3%83%A4%E3%83%9E+%E3%82%B9%E3%83%81%E3%83%BC%E3%83%A0%E3%82%AA%E3%83%BC%E3%83%96%E3%83%B3%E3%83%AC%E3%83%B3%E3%82%B8'],
];
for (const [store, label, url] of SEARCHES) {
  if (left() < 50000) { console.log('- ⏱ 時間切れ'); break; }
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3500);
    await p.evaluate(async () => { for (let y = 0; y < 6000; y += 900) { window.scrollTo(0, y); await new Promise((s) => setTimeout(s, 150)); } });
    const items = await p.evaluate((store) => {
      const re = store === 'rakuten' ? /^https:\/\/item\.rakuten\.co\.jp\/[^/]+\/[^/?#]+\/?/ : /^https:\/\/store\.shopping\.yahoo\.co\.jp\/[^/]+\/[^/?#]+\.html/;
      const seen = new Map();
      for (const a of document.querySelectorAll('a[href]')) {
        const m = a.href.match(re); if (!m) continue;
        const t = (a.getAttribute('title') || a.innerText || '').replace(/\s+/g, ' ').trim();
        if (t.length < 8) continue;
        if (!seen.has(m[0]) || seen.get(m[0]).length < t.length) seen.set(m[0], t.slice(0, 160));
      }
      return [...seen].map(([u, t]) => ({ u, t }));
    }, store);
    const iris = items.filter((x) => /アイリス|IRIS/i.test(x.t) && /レンジ/.test(x.t) && !/専用|部品|交換|トレー|角皿|パーツ/.test(x.t));
    console.log(`\n## ${store}「${label}」（HTTP ${r ? r.status() : '?'}・商品 ${items.length} 件・アイリスのレンジ ${iris.length} 件）`);
    for (const x of iris.slice(0, 20)) console.log(`- ${(x.t.match(MODEL) || ['型番なし'])[0]}｜${x.t.slice(0, 110)}｜${x.u}`);
  } catch (e) { console.log(`- ⚠️ ${store} ${label}: ${String(e).slice(0, 140)}`); }
}
// 公式通販（アイリスプラザ）で MS-F2601-B の写真
if (left() > 40000) {
  try {
    await p.goto('https://www.irisplaza.co.jp/index.php?KB=SEARCH&q=MS-F2601-B', { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3500);
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80) })).filter((l) => /SHOHIN_ID|\/products?\/|KB=SHOSAI/i.test(l.h)));
    console.log(`\n## アイリスプラザ 検索（${p.url()}・商品らしいリンク ${links.length}）`);
    for (const l of links.slice(0, 12)) console.log(`- ${l.t}｜${l.h}`);
    const hit = links.find((l) => /2601/.test(l.t + l.h)) || null;
    if (hit) {
      await p.goto(hit.h, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await p.waitForTimeout(3500);
      const title = await p.title();
      const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((i) => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || '').slice(0, 60) })).filter((i) => i.src && i.w >= 500));
      console.log(`- 開いた: ${title.slice(0, 100)}｜${p.url()}｜大きい画像 ${imgs.length}`);
      let k = 0;
      for (const im of [...new Map(imgs.map((i) => [i.src, i])).values()].slice(0, 8)) {
        try {
          const res = await ctx.request.get(im.src, { timeout: 15000 });
          const buf = await res.body();
          const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
          const name = `plaza-ms-f2601-${String(++k).padStart(2, '0')}.${ext}`;
          fs.writeFileSync(`${D}/img/${name}`, buf);
          console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
        } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
      }
    }
  } catch (e) { console.log(`- ⚠️ アイリスプラザ: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
