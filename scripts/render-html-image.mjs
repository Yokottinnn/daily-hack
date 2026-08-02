#!/usr/bin/env node
/**
 * render-html-image.mjs — 任意HTMLを高解像(2x)で画像化する汎用レンダラ
 * sns-templates の playwright / fonts を借用。
 * Usage: node scripts/render-html-image.mjs <in.html> <out.jpg|png> <width> <height>
 */
import { createRequire } from 'module';
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

const SNS = '/Users/ny_taxa/projects/anta-baka-x/sns-templates';
const require = createRequire(SNS + '/');
const { chromium } = require('playwright');

const [, , inArg, outArg, wArg, hArg] = process.argv;
if (!inArg || !outArg) { console.error('usage: render-html-image.mjs <in.html> <out.jpg> <w> <h>'); process.exit(1); }
const W = parseInt(wArg || '1600', 10);
const H = parseInt(hArg || '900', 10);
const inAbs = path.resolve(inArg);
const outAbs = path.resolve(outArg);
const pngPath = outAbs.replace(/\.(jpg|jpeg)$/i, '.png');

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
await page.goto('file://' + inAbs, { waitUntil: 'networkidle' });
await page.waitForTimeout(700);
await page.screenshot({ path: pngPath, clip: { x: 0, y: 0, width: W, height: H } });
await browser.close();

if (/\.(jpg|jpeg)$/i.test(outAbs)) {
  execSync(`python3 -c "from PIL import Image; Image.open('${pngPath}').convert('RGB').resize((${W},${H}), Image.LANCZOS).save('${outAbs}', quality=92)"`);
  fs.rmSync(pngPath, { force: true });
}
console.log('wrote', fs.existsSync(outAbs) ? outAbs : pngPath);
