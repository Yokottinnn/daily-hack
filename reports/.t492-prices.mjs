import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const fs = await import('node:fs');
const DIR = process.env.LOGO_DIR; fs.mkdirSync(DIR, { recursive: true });
const man = {};
for (const [key, brand, u] of [['yourmystar', 'ユアマイスター', 'https://yourmystar.jp/'], ['duskin', 'ダスキン（ナックダスキン）', 'https://nac-duskin.com/duskin-acclean/'], ['kireiyu', 'キレイユ', 'https://kireiyu.com/'], ['migxl', 'ミガクる', 'https://migxl.com/']]) {
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
  await p.waitForTimeout(3000);
  const cands = await p.evaluate(() => [...document.querySelectorAll('img, link[rel*=icon], meta[property="og:image"]')].map((e) => ({ src: e.currentSrc || e.src || e.href || e.content || '', alt: e.alt || '', cls: (e.className || '') + ' ' + (e.parentElement?.className || ''), w: e.naturalWidth || 0, h: e.naturalHeight || 0, tag: e.tagName })).filter((x) => x.src && /logo|ロゴ|icon|og:image/i.test(x.src + ' ' + x.alt + ' ' + x.cls + ' ' + x.tag)).slice(0, 6));
  console.log(`\n## ${brand}\n- ${p.url()}`);
  let i = 0;
  for (const c of cands) {
    i++;
    const r = await p.request.get(c.src).catch(() => null);
    if (!r || !r.ok()) { console.log(`- ⚠️ 取れない ${c.src}`); continue; }
    const body = await r.body();
    const ext = (/\.svg/i.test(c.src) || body.slice(0, 200).toString().includes('<svg')) ? 'svg' : (/\.webp/i.test(c.src) ? 'webp' : (/\.jpe?g/i.test(c.src) ? 'jpg' : 'png'));
    const name = `${key}-${i}.${ext}`;
    fs.writeFileSync(`${DIR}/${name}`, body);
    man[name] = { brand, src: c.src, page: p.url(), alt: c.alt, fetched: new Date().toISOString().slice(0, 10), task: 'ops/tasks/t492-cleaning-logos-duskin.sh' };
    console.log(`- ${name} ${body.length} bytes ${c.w}x${c.h} alt=${c.alt} ${c.src}`);
  }
}
fs.writeFileSync(`${DIR}/_manifest.json`, JSON.stringify(man, null, 2));
for (const u of ['https://nac-duskin.com/duskin-bathcleaning/', 'https://nac-duskin.com/duskin-kitchencleaning/', 'https://nac-duskin.com/duskin-acclean/']) {
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
  await p.waitForTimeout(3000);
  const t = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean));
  const idx = t.map((x, i) => (/円|税込|料金|価格|台|㎡|m2|プラン|セット|対象エリア|対応エリア/.test(x) ? i : -1)).filter((i) => i >= 0);
  const keep = [...new Set(idx.flatMap((i) => [i - 1, i, i + 1]))].filter((i) => i >= 0 && i < t.length).sort((a, b) => a - b);
  const alts = await p.evaluate(() => [...document.querySelectorAll('img[alt]')].map((i) => i.alt.trim()).filter((a) => /円|料金|価格/.test(a)));
  console.log(`\n## 本文 ${u}\n`, ...keep.slice(0, 80).map((i) => `\n  - ${t[i].slice(0, 140)}`), ...alts.slice(0, 20).map((a) => `\n  - 画像の alt: ${a.slice(0, 140)}`));
}
await p.close().catch(() => {});
process.exit(0);
