// 湾岸イベントマップの地点を、国土地理院の住所検索で緯度経度にする（2026-11-02・LLM 不使用・$0）。
// 記事の `event.address` と、地区名・目印の住所を引いて src/data/wangan-venues.json に足す（既にあるものは引き直さない）。
// 毎朝の湾岸ニュースで新しい会場が出たら `node scripts/wangan-map/geocode.mjs` を回す（docs/wangan-news-routine.md の 6-C）。
// 使い方: node scripts/wangan-map/geocode.mjs [--check]   --check は引かずに「足りない住所」があれば exit 1
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const OUT = path.join(ROOT, 'src/data/wangan-venues.json');
const CHECK = process.argv.includes('--check');

// 地区の名前の位置（ラベル用）と、地図に絵で描く目印。住所は一次情報（各施設の公式）の表記
export const AREAS = ['東京都中央区晴海', '東京都中央区勝どき', '東京都中央区月島', '東京都中央区佃', '東京都中央区豊海町', '東京都江東区豊洲', '東京都江東区有明', '東京都江東区東雲', '東京都江東区辰巳', '東京都江東区青海'];
export const LANDMARKS = [
  { key: 'market', name: '豊洲市場', address: '東京都江東区豊洲6-6-1' },
  { key: 'lalaport', name: 'ららぽーと豊洲', address: '東京都江東区豊洲2-4-9' },
  { key: 'ariake-arena', name: '有明アリーナ', address: '東京都江東区有明1-11-1' },
  { key: 'ariake-garden', name: '有明ガーデン', address: '東京都江東区有明2-1-8' },
  { key: 'bigsight', name: '東京ビッグサイト', address: '東京都江東区有明3-11-1' },
  { key: 'diversity', name: 'ダイバーシティ東京', address: '東京都江東区青海1-1-10' },
  { key: 'triton', name: '晴海トリトン', address: '東京都中央区晴海1-8' },
  { key: 'harumi-flag', name: '晴海フラッグ', address: '東京都中央区晴海5-3' },
  { key: 'monja', name: '月島もんじゃストリート', address: '東京都中央区月島3-8' },
  { key: 'bousai', name: '東京臨海広域防災公園', address: '東京都江東区有明3-8-35' },
];

function eventAddresses() {
  const dir = path.join(ROOT, 'src/content/posts');
  const out = new Set();
  for (const f of fs.readdirSync(dir).filter((x) => /\.mdx?$/.test(x))) {
    const s = fs.readFileSync(path.join(dir, f), 'utf8');
    const fm = s.split(/\n---\s*\n/)[0];
    if (!/\nevent:/.test(fm) || /\ndraft:\s*true/.test(fm)) continue;
    const m = fm.match(/\n {2}address:\s*"?([^"\n]+)"?/);
    if (m) out.add(m[1].trim());
  }
  return [...out];
}

async function geocode(q) {
  const r = await fetch(`https://msearch.gsi.go.jp/address-search/AddressSearch?q=${encodeURIComponent(q)}`, { signal: AbortSignal.timeout(20000) });
  const j = await r.json();
  if (!Array.isArray(j) || !j.length) return null;
  const [lon, lat] = j[0].geometry.coordinates;
  return { lat: +lat.toFixed(6), lon: +lon.toFixed(6), matched: j[0].properties.title };
}

const db = fs.existsSync(OUT) ? JSON.parse(fs.readFileSync(OUT, 'utf8')) : { _note: '', places: {} };
db._note = '湾岸イベントマップの地点。住所 → 緯度経度（国土地理院の住所検索）。scripts/wangan-map/geocode.mjs が足す。手で直したものは manual: true';
const want = [...AREAS, ...LANDMARKS.map((l) => l.address), ...eventAddresses()];
const missing = want.filter((a) => !db.places[a]);
if (CHECK) {
  if (missing.length) { console.log('位置の無い住所:', missing.join(' / ')); process.exit(1); }
  console.log('全部ある', want.length); process.exit(0);
}
for (const a of missing) {
  try { const g = await geocode(a); if (g) db.places[a] = g; console.log(a, '→', g ? `${g.lat},${g.lon}（${g.matched}）` : '見つからない'); }
  catch (e) { console.log(a, '→ 失敗', String(e.message || e)); }
  await new Promise((r) => setTimeout(r, 400));
}
db.landmarks = LANDMARKS;
db.areas = AREAS;
fs.writeFileSync(OUT, JSON.stringify(db, null, 1) + '\n');
console.log('地点', Object.keys(db.places).length, '件 →', path.relative(ROOT, OUT));
