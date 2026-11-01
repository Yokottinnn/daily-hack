#!/usr/bin/env node
/**
 * main に入った記事の URL だけを IndexNow（Bing・Yandex ほか）に知らせる（2026-10-30・利用者が「IndexNow の自動通知を始める」を選んだ）。
 * ChatGPT の検索や Copilot は Bing の索引を使うので、AI の回答に載るまでが早くなる。
 *
 * 使い方: node scripts/indexnow-changed.mjs <変わった記事の slug ...>
 *   - 本番で 200 が返るまで待ってから送る（Cloudflare Pages の本番デプロイは main に入ってから数分かかる）
 *   - 記事のほか、湾岸ライフの一覧・llms.txt・サイトマップも一緒に送る
 *
 * 費用: AI 不使用。GitHub Actions の無料枠（公開リポジトリ）。1 回 $0・1 日 $0・1 か月 $0
 */
import fs from 'node:fs/promises';

const SITE = 'daily-hack.fieldbeside.com';
const slugs = process.argv.slice(2).filter(Boolean);
if (slugs.length === 0) {
  console.log('変わった記事なし。送らない');
  process.exit(0);
}

const keyFile = (await fs.readdir('./public')).find((f) => /^[a-f0-9]{32}\.txt$/.test(f));
if (!keyFile) {
  console.error('IndexNow の鍵ファイルが public/ に無い');
  process.exit(1);
}
const key = keyFile.replace('.txt', '');

const urls = [
  ...slugs.map((s) => `https://${SITE}/posts/${s}/`),
  `https://${SITE}/category/wangan-life/`,
  `https://${SITE}/llms.txt`,
  `https://${SITE}/sitemap-0.xml`,
];

// 本番に出るまで待つ（最長 15 分）。記事の URL が全部 200 になったら送る
const deadline = Date.now() + 15 * 60 * 1000;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
for (;;) {
  const codes = await Promise.all(
    slugs.map((s) =>
      fetch(`https://${SITE}/posts/${s}/`, { method: 'HEAD', redirect: 'manual' })
        .then((r) => r.status)
        .catch(() => 0),
    ),
  );
  const notYet = slugs.filter((_, i) => codes[i] !== 200);
  if (notYet.length === 0) break;
  if (Date.now() > deadline) {
    console.error(`15 分待っても本番で開けない: ${notYet.join(', ')}`);
    // 開けたものだけ送る
    for (const s of notYet) urls.splice(urls.indexOf(`https://${SITE}/posts/${s}/`), 1);
    break;
  }
  console.log(`本番待ち: ${notYet.length} 本`);
  await sleep(30_000);
}

const payload = { host: SITE, key, keyLocation: `https://${SITE}/${key}.txt`, urlList: urls };
console.log(`送る URL: ${urls.length} 件`);
urls.forEach((u) => console.log(`- ${u}`));

let ok = 0;
for (const ep of ['https://api.indexnow.org/IndexNow', 'https://www.bing.com/IndexNow', 'https://yandex.com/IndexNow']) {
  try {
    const res = await fetch(ep, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify(payload),
    });
    console.log(`${ep}: ${res.status}`);
    if (res.status === 200 || res.status === 202) ok++;
  } catch (e) {
    console.error(`${ep}: ${e.message}`);
  }
}
// Bing Webmaster の URL 送信 API（2026-11-01 利用者が「Bing の API キーで送る」を選んだ）。
// IndexNow の Bing 窓口が 403 を返し続けるため、Bing Webmaster Tools の API キーで直接送る。
// キーはリポジトリの Secrets「BING_WEBMASTER_API_KEY」。無ければこの段は飛ばす（出力に書く）
const bingKey = process.env.BING_WEBMASTER_API_KEY || '';
if (!bingKey) {
  console.log('Bing Webmaster API: キー（BING_WEBMASTER_API_KEY）が未登録なので送らない');
} else {
  try {
    const res = await fetch(`https://ssl.bing.com/webmaster/api.svc/json/SubmitUrlBatch?apikey=${encodeURIComponent(bingKey)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ siteUrl: `https://${SITE}/`, urlList: urls }),
    });
    const body = (await res.text()).slice(0, 300);
    console.log(`Bing Webmaster API SubmitUrlBatch: ${res.status} ${body}`);
    if (res.status === 200) ok++;
  } catch (e) {
    console.error(`Bing Webmaster API: ${e.message}`);
  }
}

// 1 つも受け付けなければ失敗にする（黙って成功に見せない）
process.exit(ok > 0 ? 0 : 1);
