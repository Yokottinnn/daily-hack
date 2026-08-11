#!/usr/bin/env node
// このコンテナ用の簡易レンダラ。scripts/render-html-image.mjs は Mac 固有の
// playwright パスを参照していて動かないため、グローバル導入分を使う。
import { createRequire } from 'module';
import path from 'node:path';

const require = createRequire('/opt/node22/lib/node_modules/playwright/');
const { chromium } = require('playwright');

const [, , inArg, outArg, wArg, hArg] = process.argv;
const W = parseInt(wArg || '1200', 10);
const H = parseInt(hArg || '1200', 10);

// PLAYWRIGHT_BROWSERS_PATH が設定済みなので実行ファイルは自動解決される。
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
await page.goto('file://' + path.resolve(inArg), { waitUntil: 'networkidle' });
await page.waitForTimeout(600);
await page.screenshot({ path: path.resolve(outArg), clip: { x: 0, y: 0, width: W, height: H } });
await browser.close();
console.log('rendered:', outArg);
