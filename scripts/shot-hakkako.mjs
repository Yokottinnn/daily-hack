// hakkako-says ブロックをスクショして透過反映を視覚検証
// Usage: node scripts/shot-hakkako.mjs <pageURL> <outPng>
import { createRequire } from 'module';
const require = createRequire('/Users/ny_taxa/projects/anta-baka-x/sns-templates/');
const { chromium } = require('playwright');

const url = process.argv[2];
const out = process.argv[3] || '/tmp/hakkako.png';

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 900, height: 1400 } });
await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
const el = await page.$('.hakkako-says');
if (!el) { console.log('NO .hakkako-says found'); await browser.close(); process.exit(1); }
await el.scrollIntoViewIfNeeded();
await page.waitForTimeout(500);
await el.screenshot({ path: out });
console.log('saved', out);
await browser.close();
