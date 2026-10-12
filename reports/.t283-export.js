const fs = require('fs'), path = require('path');
const W = path.join(process.env.HOME, '.openclaw/workspace/data');
const out = { generated: new Date().toISOString(), followers: [], posts: [], keys: {} };
// フォロワー数
const sd = path.join(W, 'follower-snapshots');
if (fs.existsSync(sd)) {
  const files = fs.readdirSync(sd).filter((f) => /^\d{4}-\d{2}-\d{2}\.json$/.test(f)).sort();
  for (const f of files) {
    try { const j = JSON.parse(fs.readFileSync(path.join(sd, f), 'utf8'));
      if (!out.keys.snapshot) out.keys.snapshot = Object.keys(j).slice(0, 20);
      const n = j.count ?? j.followers ?? null;
      if (typeof n === 'number' && n > 0) out.followers.push({ date: f.slice(0, 10), count: n, following: j.following ?? null, at: j.taken_at || null });
    } catch (e) { out.followers.push({ date: f.slice(0, 10), error: String(e.message).slice(0, 80) }); }
  }
}
// 投稿ごとの表示回数（同じ投稿は最後の行＝最新を採る）
const ip = path.join(W, 'x-impressions.jsonl');
if (fs.existsSync(ip)) {
  const lines = fs.readFileSync(ip, 'utf8').split('\n').filter(Boolean);
  out.impressionLines = lines.length;
  const by = {};
  for (const l of lines) { try { const j = JSON.parse(l); if (!out.keys.impression) out.keys.impression = Object.keys(j).slice(0, 30);
    const id = j.tweet_id || j.id || j.x_tweet_id || j.status_id; if (!id) continue;
    by[id] = Object.assign({}, by[id] || {}, j, { firstSeen: (by[id] && by[id].firstSeen) || j.at || j.captured_at || j.ts || null }); } catch {} }
  out.posts = Object.values(by);
}
fs.writeFileSync(process.argv[2], JSON.stringify(out, null, 1));
JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
console.log(`followers: ${out.followers.length} 日 / posts: ${out.posts.length} 本 / impression 行: ${out.impressionLines ?? '—'}`);
console.log('snapshot のキー: ' + JSON.stringify(out.keys.snapshot || null));
console.log('impression のキー: ' + JSON.stringify(out.keys.impression || null));
console.log('最新のフォロワー: ' + JSON.stringify(out.followers.slice(-3)));
console.log('投稿の 1 件目: ' + JSON.stringify(out.posts[0] || null).slice(0, 600));
