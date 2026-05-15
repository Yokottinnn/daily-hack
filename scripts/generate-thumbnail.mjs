#!/usr/bin/env node
// Generates a custom OGP thumbnail (1200x630 PNG) by compositing a title overlay
// onto a base photo. Usage:
//   node scripts/generate-thumbnail.mjs <slug>
// where the slug matches a frontmatter slug. The mapping below holds the title,
// subtitle and base image URL per slug.

import sharp from 'sharp';
import { writeFile, mkdir } from 'fs/promises';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const RECIPES = {
  'furusato-tax-beginner-guide-2026': {
    title: 'ふるさと納税の',
    titleLine2: '始め方',
    subtitle: '2026年最新版・初心者向け最短ルート',
    photo: 'https://images.unsplash.com/photo-1543353071-873f17a7a088?w=1600&q=85',
    overlayColor: 'rgba(168, 41, 89, 0.55)',
  },
  'credit-card-no-annual-fee-comparison-2026': {
    title: '年会費無料×高還元',
    titleLine2: 'クレカ比較',
    subtitle: '2026年版・本気で得する5枚を徹底解説',
    photo: 'https://images.unsplash.com/photo-1556742502-ec7c0e9f34b1?w=1600&q=85',
    overlayColor: 'rgba(168, 41, 89, 0.60)',
  },
  'qr-payment-comparison-2026': {
    title: '3大QR決済',
    titleLine2: '完全比較',
    subtitle: 'PayPay・楽天ペイ・d払い 2026年最新版',
    photo: 'https://images.unsplash.com/photo-1556742111-a301076d9d18?w=1600&q=85',
    overlayColor: 'rgba(214, 62, 118, 0.55)',
  },
};

function escapeXml(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function buildOverlaySvg({ title, titleLine2, subtitle, overlayColor }) {
  // Hiragino Sans / Noto Sans JP are commonly present; let the renderer pick the first available.
  const titleFont = '"Hiragino Maru Gothic ProN", "Hiragino Sans", "Noto Sans JP", "Yu Gothic", sans-serif';
  const accentFont = '"Hiragino Mincho ProN", "Yu Mincho", serif';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="grad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="rgba(0,0,0,0)" />
      <stop offset="55%" stop-color="rgba(0,0,0,0.35)" />
      <stop offset="100%" stop-color="rgba(0,0,0,0.65)" />
    </linearGradient>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="4" stdDeviation="6" flood-color="rgba(0,0,0,0.45)" />
    </filter>
  </defs>
  <rect width="1200" height="630" fill="${overlayColor}" />
  <rect width="1200" height="630" fill="url(#grad)" />
  <g filter="url(#shadow)">
    <text x="72" y="246" font-family='${titleFont}' font-size="116" font-weight="900" fill="#ffffff" letter-spacing="-1">${escapeXml(title)}</text>
    <text x="72" y="370" font-family='${titleFont}' font-size="116" font-weight="900" fill="#ffd1e2" letter-spacing="-1">${escapeXml(titleLine2)}</text>
  </g>
  <rect x="72" y="408" width="120" height="6" rx="3" fill="#ffd1e2" />
  <text x="72" y="466" font-family='${titleFont}' font-size="34" font-weight="600" fill="#ffffff" opacity="0.92">${escapeXml(subtitle)}</text>
  <g transform="translate(72,548)">
    <rect x="0" y="0" width="240" height="50" rx="25" fill="#ec5c90" />
    <text x="120" y="33" text-anchor="middle" font-family='${accentFont}' font-size="20" font-weight="700" fill="#ffffff">Daily Hack</text>
  </g>
  <text x="332" y="582" font-family='${titleFont}' font-size="18" font-weight="500" fill="#ffffff" opacity="0.78">お得を毎日、ハック。</text>
</svg>`;
}

async function generate(slug) {
  const recipe = RECIPES[slug];
  if (!recipe) {
    console.error(`Unknown slug: ${slug}. Add a recipe in scripts/generate-thumbnail.mjs.`);
    process.exit(1);
  }

  console.log(`[thumb] fetching base photo: ${recipe.photo}`);
  const res = await fetch(recipe.photo);
  if (!res.ok) throw new Error(`Failed to fetch photo (${res.status})`);
  const baseBuffer = Buffer.from(await res.arrayBuffer());

  console.log('[thumb] compositing overlay');
  const svg = buildOverlaySvg(recipe);
  const png = await sharp(baseBuffer)
    .resize(1200, 630, { fit: 'cover', position: 'attention' })
    .composite([{ input: Buffer.from(svg), top: 0, left: 0 }])
    .png({ quality: 90, compressionLevel: 9 })
    .toBuffer();

  const outDir = join(ROOT, 'public', 'images', 'eyecatch');
  await mkdir(outDir, { recursive: true });
  const outPath = join(outDir, `${slug}-thumb.png`);
  await writeFile(outPath, png);
  console.log(`[thumb] wrote ${outPath} (${png.length} bytes)`);
}

const slug = process.argv[2];
if (!slug) {
  console.error('Usage: node scripts/generate-thumbnail.mjs <slug>');
  console.error('Available slugs:', Object.keys(RECIPES).join(', '));
  process.exit(1);
}
generate(slug).catch((err) => {
  console.error('[thumb] failed:', err);
  process.exit(1);
});
