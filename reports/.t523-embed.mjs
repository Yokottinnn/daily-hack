import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const Q = JSON.parse(fs.readFileSync(process.env.QJSON, 'utf8'));
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const t0 = Date.now();
const res = {};
for (const it of Q) {
  if (Date.now() - t0 > 215000) { console.log(`- ⏱ 時間切れ（${it.slug} 以降は次の回）`); break; }
  const r = res[it.slug] = { x: [], yt: [] };
  console.log(`\n## ${it.slug}`);
  let ids = [];
  for (const q of it.x) {
    try {
      await p.goto(`https://x.com/search?q=${encodeURIComponent(q + ' since:2025-10-01 -filter:replies lang:ja')}&src=typed_query&f=top`, { waitUntil: 'domcontentloaded', timeout: 25000 });
      await p.waitForTimeout(6000);
      const got = await p.evaluate(() => document.querySelectorAll('article').length);
      if (!got) console.log(`- ⚠️ X の結果が 0 件（${q}）: ${(await p.evaluate(() => document.body.innerText.replace(/\s+/g, ' ').slice(0, 160)))}`);
      ids.push(...await p.evaluate(() => [...document.querySelectorAll('article')].slice(0, 6).map((a) => ([...a.querySelectorAll('a[href*="/status/"]')].map((x) => x.getAttribute('href')).find((h) => /\/status\/\d+$/.test(h)) || '').split('/status/')[1]).filter(Boolean)));
      await p.waitForTimeout(20000);
    } catch (e) { console.log(`- ⚠️ X 検索失敗 ${q}: ${String(e).slice(0, 100)}`); }
  }
  for (const id of [...new Set(ids)].slice(0, 9)) {
    try {
      const j = await (await fetch(`https://cdn.syndication.twimg.com/tweet-result?id=${id}&lang=ja&token=a`)).json();
      const o = { id, name: j.user?.name, sn: j.user?.screen_name, blue: !!(j.user?.is_blue_verified || j.user?.verified), at: j.created_at, likes: j.favorite_count ?? null, text: (j.text || '').replace(/\s+/g, ' ').slice(0, 300), media: !!(j.mediaDetails?.length) };
      r.x.push(o);
      console.log(`- X ${id} @${o.sn} ${o.blue ? '✔' : ''} ${o.at?.slice(0, 10)} ♥${o.likes} ${o.text.slice(0, 90)}`);
    } catch (e) { console.log(`- X ${id} ⚠️ syndication 失敗`); }
  }
  if (it.yt) try {
    await p.goto(`https://www.youtube.com/results?search_query=${encodeURIComponent(it.yt)}`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4000);
    const vids = await p.evaluate(() => [...document.querySelectorAll('ytd-video-renderer')].slice(0, 6).map((v) => ({ id: (v.querySelector('a#thumbnail')?.href || '').match(/v=([\w-]{11})/)?.[1], title: v.querySelector('#video-title')?.textContent.trim(), ch: v.querySelector('ytd-channel-name a')?.textContent.trim(), meta: v.querySelector('#metadata-line')?.innerText.replace(/\s+/g, ' ') })).filter((v) => v.id));
    for (const v of vids) {
      try {
        const o = await (await fetch(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${v.id}&format=json`)).json();
        r.yt.push({ ...v, oTitle: o.title, oAuthor: o.author_name });
        console.log(`- YT ${v.id} 「${o.title.slice(0, 70)}」 / ${o.author_name} / ${v.meta}`);
      } catch { console.log(`- YT ${v.id} ⚠️ oEmbed で照合できない（埋め込み不可の可能性）`); }
    }
  } catch (e) { console.log(`- ⚠️ YouTube 検索失敗: ${String(e).slice(0, 100)}`); }
}
fs.writeFileSync(process.env.RES_JSON, JSON.stringify(res, null, 1));
console.log(`\n---\n対象 ${Q.length} / 読めた ${Object.keys(res).length}`);
await p.close().catch(() => {});
process.exit(0);
