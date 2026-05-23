#!/usr/bin/env node
/**
 * SEO submit: sitemap の全 URL を IndexNow / Yandex / Bing にまとめて通知。
 * Google には Indexing API がペイロード単位でしか効かないので別スクリプト。
 *
 * Usage:
 *   node scripts/seo-submit.mjs          # 全 URL を ping
 *   node scripts/seo-submit.mjs --recent # publishDate >= today-7d のみ
 */
import { XMLParser } from 'fast-xml-parser';
import fs from 'node:fs/promises';

const SITE = 'daily-hack.fieldbeside.com';
const SITEMAP = `https://${SITE}/sitemap-0.xml`;

const keyFile = (await fs.readdir('./public')).find((f) => /^[a-f0-9]{32}\.txt$/.test(f));
if (!keyFile) {
  console.error('IndexNow key file not found in ./public/. Run `openssl rand -hex 16 > public/<key>.txt` first.');
  process.exit(1);
}
const indexNowKey = keyFile.replace('.txt', '');
console.log(`IndexNow key: ${indexNowKey}`);

const xml = await (await fetch(SITEMAP)).text();
const parser = new XMLParser();
const data = parser.parse(xml);
let urls = (data.urlset?.url ?? []).map((u) => (typeof u === 'string' ? u : u.loc));
console.log(`Sitemap URLs: ${urls.length}`);

const recentOnly = process.argv.includes('--recent');
if (recentOnly) {
  const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;
  urls = (data.urlset?.url ?? [])
    .filter((u) => {
      const lm = u.lastmod || u.lastModified;
      return lm ? new Date(lm).getTime() >= cutoff : true;
    })
    .map((u) => u.loc);
  console.log(`Filtered to recent: ${urls.length}`);
}

const payload = {
  host: SITE,
  key: indexNowKey,
  keyLocation: `https://${SITE}/${indexNowKey}.txt`,
  urlList: urls,
};

const endpoints = [
  { name: 'IndexNow (api.indexnow.org)', url: 'https://api.indexnow.org/IndexNow' },
  { name: 'Bing IndexNow', url: 'https://www.bing.com/IndexNow' },
  { name: 'Yandex IndexNow', url: 'https://yandex.com/IndexNow' },
];

for (const ep of endpoints) {
  try {
    const res = await fetch(ep.url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify(payload),
    });
    console.log(`${ep.name}: ${res.status} ${res.statusText}`);
  } catch (e) {
    console.error(`${ep.name}: ${e.message}`);
  }
}
