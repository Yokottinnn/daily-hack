#!/usr/bin/env node
// Daily Hack 画像アップロードスクリプト（OpenClaw用）
//
// 使い方:
//   node scripts/upload-image.js <ローカル画像パス> [<R2のキー>]
//
// 環境変数:
//   CLOUDFLARE_API_TOKEN  R2 Edit 権限のあるトークン
//   CLOUDFLARE_ACCOUNT_ID
//
// 例:
//   node scripts/upload-image.js /tmp/eyecatch.jpg posts/best-online-banks-2026/eyecatch.jpg
//
// → https://images.fieldbeside.com/posts/best-online-banks-2026/eyecatch.jpg

import { readFileSync } from 'node:fs';
import { basename, extname } from 'node:path';

const BUCKET = 'daily-hack-images';
const CDN_BASE = 'https://images.fieldbeside.com';

const apiToken = process.env.CLOUDFLARE_API_TOKEN;
const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;

if (!apiToken || !accountId) {
  console.error('CLOUDFLARE_API_TOKEN と CLOUDFLARE_ACCOUNT_ID を環境変数にセットしてください');
  console.error('例: source ~/.cloudflare-daily-hack.env');
  process.exit(1);
}

const [, , filePath, keyArg] = process.argv;
if (!filePath) {
  console.error('Usage: node scripts/upload-image.js <local-path> [<r2-key>]');
  process.exit(1);
}

const key = keyArg ?? basename(filePath);

const mimeMap = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.avif': 'image/avif',
  '.svg': 'image/svg+xml',
};
const ext = extname(filePath).toLowerCase();
const contentType = mimeMap[ext] ?? 'application/octet-stream';

const fileBuffer = readFileSync(filePath);

const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/r2/buckets/${BUCKET}/objects/${key}`;

console.log(`Uploading ${filePath} (${fileBuffer.length} bytes, ${contentType}) → r2://${BUCKET}/${key}`);

const res = await fetch(url, {
  method: 'PUT',
  headers: {
    'Authorization': `Bearer ${apiToken}`,
    'Content-Type': contentType,
    'Cache-Control': 'public, max-age=31536000, immutable',
  },
  body: fileBuffer,
});

if (!res.ok) {
  const errText = await res.text();
  console.error(`Upload failed: ${res.status} ${res.statusText}`);
  console.error(errText);
  process.exit(1);
}

const publicUrl = `${CDN_BASE}/${key}`;
console.log(`✓ Uploaded: ${publicUrl}`);
console.log(publicUrl);
