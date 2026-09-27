// hakkako-says ブロックをスクショして透過反映を視覚検証
// Usage: node scripts/shot-hakkako.mjs <pageURL> <outPng>
import { loadChromium, launch } from './lib/render-env.mjs';
// **パスの決め打ちをやめた**（2026-09-26）。解決は `scripts/lib/render-env.mjs`
const chromium = loadChromium();

const url = process.argv[2];
const out = process.argv[3] || '/tmp/hakkako.png';

const browser = await launch(chromium);
const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 900, height: 1400 } });
await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
const el = await page.$('.hakkako-says');
if (!el) { console.log('NO .hakkako-says found'); await browser.close(); process.exit(1); }
await el.scrollIntoViewIfNeeded();
await page.waitForTimeout(500);
await el.screenshot({ path: out });
console.log('saved', out);
await browser.close();
