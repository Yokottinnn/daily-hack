#!/usr/bin/env node
/**
 * Cloudflare DNS に TXT レコードを 1 行で追加する。
 *
 * 必要 env:
 *   CLOUDFLARE_API_TOKEN  (Zone DNS Edit を含む token)
 *
 * Usage:
 *   CLOUDFLARE_API_TOKEN=xxx node scripts/cf-set-txt.mjs \
 *     --zone fieldbeside.com \
 *     --name daily-hack.fieldbeside.com \
 *     --content "google-site-verification=abcXYZ..."
 */
const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, cur, i, arr) => {
    if (cur.startsWith('--') && arr[i + 1]) acc.push([cur.slice(2), arr[i + 1]]);
    return acc;
  }, []),
);

const token = process.env.CLOUDFLARE_API_TOKEN;
const zoneName = args.zone || 'fieldbeside.com';
const recordName = args.name || 'daily-hack.fieldbeside.com';
const content = args.content;

if (!token) { console.error('Set CLOUDFLARE_API_TOKEN env var.'); process.exit(1); }
if (!content) { console.error('--content required.'); process.exit(1); }

const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

const zonesRes = await fetch(`https://api.cloudflare.com/client/v4/zones?name=${zoneName}`, { headers });
const zonesJson = await zonesRes.json();
if (!zonesJson.success || !zonesJson.result?.[0]) {
  console.error('Zone lookup failed:', JSON.stringify(zonesJson, null, 2));
  process.exit(1);
}
const zoneId = zonesJson.result[0].id;
console.log(`Zone ID: ${zoneId}`);

const existingRes = await fetch(
  `https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records?type=TXT&name=${recordName}`,
  { headers },
);
const existing = await existingRes.json();
const dupes = (existing.result ?? []).filter((r) => r.content.includes('google-site-verification'));
for (const d of dupes) {
  console.log(`Removing existing TXT: ${d.content}`);
  await fetch(`https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records/${d.id}`, { method: 'DELETE', headers });
}

const createRes = await fetch(`https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records`, {
  method: 'POST',
  headers,
  body: JSON.stringify({ type: 'TXT', name: recordName, content, ttl: 1, proxied: false }),
});
const createJson = await createRes.json();
if (!createJson.success) {
  console.error('Create failed:', JSON.stringify(createJson, null, 2));
  process.exit(1);
}
console.log(`✓ TXT created: ${recordName} -> ${content}`);
