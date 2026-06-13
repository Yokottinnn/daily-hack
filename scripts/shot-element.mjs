// 任意要素をスクショして視覚検証
// Usage: node scripts/shot-element.mjs <pageURL> <selector> <outPng> [nthIndex=0]
import { createRequire } from 'module';
const require = createRequire('/Users/ny_taxa/projects/anta-baka-x/sns-templates/');
const { chromium } = require('playwright');

const [url, selector, out, idxStr] = process.argv.slice(2);
const idx = parseInt(idxStr || '0', 10);

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 900, height: 1600 } });
await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
const els = await page.$$(selector);
if (!els.length) { console.log('NO element for', selector); await browser.close(); process.exit(1); }
const el = els[Math.min(idx, els.length - 1)];
await el.scrollIntoViewIfNeeded();
await page.waitForTimeout(700);
await el.screenshot({ path: out });
console.log('saved', out, '(', els.length, 'matched )');
await browser.close();
