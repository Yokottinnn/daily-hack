/**
 * 湾岸エリアイベントマップのデータ（2026-11-02 利用者「湾岸ライフのページに湾岸エリアイベントマップを作成して」）。
 *
 * - 陸の輪郭: src/data/wangan-basemap.json（scripts/wangan-map/gen-basemap.py が国土地理院の淡色地図から作った）
 * - 地点の緯度経度: src/data/wangan-venues.json（scripts/wangan-map/geocode.mjs が国土地理院の住所検索で引いた）
 * - イベント: 記事のフロントマターの `event:`。終わったものは出さない（ビルドした日・日本時間で判定）
 * - ニュース: 湾岸ニュースの記事のうち `event:` が無いもの（直近 14 日）。地区の位置に出す
 *
 * **港区・品川区は対象外**（docs/wangan-news-routine.md）。地図の陸は描くが、地区の札とピンは出さない。
 */
import type { CollectionEntry } from 'astro:content';
import fs from 'node:fs';
import path from 'node:path';
import basemap from '../data/wangan-basemap.json';
import venues from '../data/wangan-venues.json';
import wide from '../data/wangan-basemap-wide.json';
import outer from '../data/wangan-outer-labels.json';
import { WANGAN_AREAS, WANGAN_NEWS_TAG, todayJst } from './wangan';

type Post = CollectionEntry<'posts'>;

type Place = { lat: number; lon: number };
const PLACES = (venues as { places: Record<string, Place> }).places;

/** 緯度経度 → 地図の座標（viewBox 0〜1000）。地理院タイルと同じ投影（Web メルカトル） */
export function project(lat: number, lon: number): { x: number; y: number } {
  const t = basemap.tile;
  const n = 2 ** t.z;
  const tx = ((lon + 180) / 360) * n;
  const rad = (lat * Math.PI) / 180;
  const ty = ((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) * n;
  return { x: +((tx - t.x0) * 256 * t.scale).toFixed(1), y: +((ty - t.y0) * 256 * t.scale).toFixed(1) };
}

const WARD_CODE: Record<string, string> = { '13101': '千代田区', '13102': '中央区', '13108': '江東区', '13103': '港区', '13109': '品川区' };

/** 地図の大きさ（横 1000・縦は範囲の比） */
export const MAP_W = basemap.viewBox;
export const MAP_H = (basemap as { viewBoxH?: number }).viewBoxH ?? basemap.viewBox;
export const MAP_LAND = basemap.land.map((l) => ({ d: l.d, ward: WARD_CODE[l.muni] ?? '' }));
export const MAP_SOURCE = basemap.source;
/** 地図の外側の陸（縮小したときに見える・2026-11-03）。本体と同じ座標で、負や 1000 超えになる */
export const MAP_WIDE = { extent: wide.extent as { x: number; y: number; w: number; h: number }, land: wide.land as string[] };
/** 縮小・移動できる範囲（本体の外へ 650 まで）。外側の陸があるのはこの内側 */
export const MAP_PAN = (() => { const e = MAP_WIDE.extent, m = 650; const x = Math.max(e.x, -m), y = Math.max(e.y, -m);
  return { x, y, w: Math.min(e.x + e.w, MAP_W + m) - x, h: Math.min(e.y + e.h, MAP_H + m) - y }; })();
const inMap = (x: number, y: number) => x > 0 && x < MAP_W && y > 0 && y < MAP_H;

/** 駅（OpenStreetMap で引いた位置） */
type Station = { key: string; name: string; lat: number; lon: number; minor?: boolean };
const STATIONS = ((venues as { stations?: Station[] }).stations ?? []);
export const MAP_STATIONS = STATIONS.map((s) => ({ key: s.key, name: s.name, minor: !!s.minor, ...project(s.lat, s.lon) })).filter((s) => inMap(s.x, s.y));
/** ゆりかもめの線（駅の並び）。地図に線を引き、車両を走らせる */
const LINES = ((venues as { lines?: Record<string, string[]> }).lines ?? {});
export const MAP_YURIKAMOME = (LINES.yurikamome ?? []).map((k) => MAP_STATIONS.find((s) => s.key === k)).filter((s): s is (typeof MAP_STATIONS)[number] => !!s);

/**
 * 地下鉄の線（2026-11-03 利用者「勝どき駅と月島駅が線路で繋がっていないので繋げて／何線かも重要な情報なので書いて」）。
 * 駅は地図に置いた駅の位置、地図の外へ続く先は駅の緯度経度（OpenStreetMap）で向きだけ出す。
 */
const off = (lat: number, lon: number) => project(lat, lon);
const st = (k: string) => { const s = MAP_STATIONS.find((x) => x.key === k); return s ? { x: s.x, y: s.y } : null; };
const line = (pts: ({ x: number; y: number } | null)[]) => pts.filter((p): p is { x: number; y: number } => !!p);
export const MAP_SUBWAYS = [
  // 都営大江戸線: 大門 → 汐留 → 築地市場 → 勝どき → 月島 → 門前仲町
  { key: 'oedo', name: '都営大江戸線', color: '#b6007a', pts: line([off(35.6564, 139.7546), st('汐留駅'), st('築地市場駅'), st('勝どき駅'), st('月島駅'), off(35.6717, 139.7963)]) },
  // 東京メトロ有楽町線: 銀座一丁目 → 新富町 → 月島 → 豊洲 → 辰巳
  { key: 'yurakucho', name: '東京メトロ有楽町線', color: '#b8955a', pts: line([off(35.6743, 139.7671), off(35.6706, 139.7735), st('月島駅'), st('豊洲駅'), off(35.6455, 139.8104)]) },
].filter((l) => l.pts.length > 2);

/** 地図の目印にする、湾岸の外の地名（銀座・新橋）。イベントの対象地域ではない（築地は 2026-11-03 に対象の地区へ） */
export const MAP_REF_AREAS = [
  { name: '銀座', ...project(35.6717, 139.7649) },
  { name: '新橋', ...project(35.6662, 139.7577) },
].filter((a) => inMap(a.x, a.y));

/**
 * 地図の外側（縮小したときに見える範囲）の駅と地名（2026-11-07 利用者「−ボタンで引いたとき、お台場エリア以外は一切表示されていないのが見栄えが悪い。
 * 湾岸エリア以外も地名や駅名くらいは表示させて」）。位置は OpenStreetMap（t569）。本体の枠の外で、縮小できる範囲（MAP_PAN）の中だけ。
 * 札が重ならないよう、乗り入れの多い駅から順に間を空けて選ぶ。地名は駅の札とも離す。
 */
const outsideCore = (x: number, y: number) => (x < -12 || x > MAP_W + 12 || y < -12 || y > MAP_H + 12)
  && x > MAP_PAN.x + 20 && x < MAP_PAN.x + MAP_PAN.w - 20 && y > MAP_PAN.y + 20 && y < MAP_PAN.y + MAP_PAN.h - 20;
const spaced = <T extends { x: number; y: number }>(list: T[], gap: number, avoid: { x: number; y: number }[] = [], avoidGap = 0) => {
  const out: T[] = [];
  for (const it of list) {
    if (out.some((o) => Math.hypot(o.x - it.x, o.y - it.y) < gap)) continue;
    if (avoid.some((o) => Math.hypot(o.x - it.x, o.y - it.y) < avoidGap)) continue;
    out.push(it);
  }
  return out;
};
type OuterPt = { name: string; lat: number; lon: number; count?: number };
export const MAP_OUTER_STATIONS = spaced(
  (outer.stations as OuterPt[]).map((s) => ({ name: s.name, count: s.count ?? 1, ...project(s.lat, s.lon) }))
    .filter((s) => outsideCore(s.x, s.y)).sort((a, b) => b.count - a.count || a.name.localeCompare(b.name)),
  95,
);
/** 名所（湾岸の外のものだけ。絵の札で出す）。すぐ近くの駅は名前を省いて点だけにする（札が重なるため） */
type OuterSpot = { name: string; icon: string; lat: number; lon: number };
export const MAP_OUTER_SPOTS = spaced(((outer as unknown as { spots?: OuterSpot[] }).spots ?? [])
  .map((sp) => ({ name: sp.name, icon: sp.icon, ...project(sp.lat, sp.lon) })).filter((sp) => outsideCore(sp.x, sp.y)), 70);

export const MAP_OUTER_STATION_NAMED = new Set(MAP_OUTER_STATIONS.filter((st) => !MAP_OUTER_SPOTS.some((sp) => Math.hypot(sp.x - st.x, sp.y - st.y) < 40)).map((st) => st.name));
export const MAP_OUTER_PLACES = spaced(
  (outer.places as OuterPt[]).map((p) => ({ name: p.name, ...project(p.lat, p.lon) })).filter((p) => outsideCore(p.x, p.y)),
  130, [...MAP_OUTER_STATIONS, ...MAP_OUTER_SPOTS], 55,
).filter((p, i, all) => all.findIndex((o) => o.name === p.name) === i);

/**
 * 鉄道の路線（2026-11-07 利用者「各駅の路線と、最低限の有名スポットだけはマッピングしたい」）。停車駅を順につないだ線。
 * 路線の名前の札は、湾岸の外で、ほかの札と重ならない駅の間に 1 つ置く。
 */
type OuterLine = { name: string; colour: string; pts: [number, number][] };
const OUTER_LINES_RAW = ((outer as unknown as { lines?: OuterLine[] }).lines ?? []);
export const MAP_OUTER_LINES = OUTER_LINES_RAW.map((l) => ({ name: l.name, colour: l.colour, pts: l.pts.map(([lat, lon]) => project(lat, lon)) }));
const lineLabelSpots: { x: number; y: number }[] = [];
export const MAP_OUTER_LINE_LABELS = MAP_OUTER_LINES.map((l) => {
  const mids = l.pts.slice(1).map((b, i) => { const a = l.pts[i]; return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, len: Math.hypot(b.x - a.x, b.y - a.y) }; })
    .filter((m) => m.len > 70 && outsideCore(m.x, m.y))
    .filter((m) => ![...MAP_OUTER_STATIONS, ...MAP_OUTER_PLACES].some((o) => Math.hypot(o.x - m.x, o.y - m.y) < 45))
    .filter((m) => !lineLabelSpots.some((o) => Math.hypot(o.x - m.x, o.y - m.y) < 110))
    .sort((a, b) => b.len - a.len);
  const m = mids[0]; if (!m) return null;
  lineLabelSpots.push(m);
  return { name: l.name, colour: l.colour, x: m.x, y: m.y };
}).filter((x): x is { name: string; colour: string; x: number; y: number } => !!x);
/** 地区の札（区の住所検索の位置） */
const AREA_ADDR: Record<string, string> = {
  晴海: '東京都中央区晴海', 勝どき: '東京都中央区勝どき', 月島: '東京都中央区月島', 佃: '東京都中央区佃', 豊海: '東京都中央区豊海町', 築地: '東京都中央区築地',
  豊洲: '東京都江東区豊洲', 有明: '東京都江東区有明', 東雲: '東京都江東区東雲', 辰巳: '東京都江東区辰巳', お台場: '東京都江東区青海', 青海: '東京都江東区青海',
};
/** 札の置き場所の微調整（住所検索の代表点は丁目の端に出ることがある。札が島から外れないよう寄せる） */
const AREA_NUDGE: Record<string, [number, number]> = { 晴海: [-50, 30], 佃: [6, -20], 月島: [-14, 6], 勝どき: [-30, 0] };

/** 札を島の真ん中に置く地区（住所検索の代表点が島の端に出るもの）。緯度経度で指定 */
const AREA_AT: Record<string, Place> = { 豊洲: { lat: 35.6505, lon: 139.7885 } };

export const MAP_AREAS = WANGAN_AREAS.map((a) => {
  const p = AREA_AT[a.tag] ?? PLACES[AREA_ADDR[a.tag]];
  if (!p) return null;
  const { x, y } = project(p.lat, p.lon);
  const [dx, dy] = AREA_NUDGE[a.tag] ?? [0, 0];
  return { tag: a.tag, ward: a.ward, x: x + dx, y: y + dy };
}).filter((a): a is { tag: string; ward: string; x: number; y: number } => !!a && inMap(a.x, a.y));

/** 地図に絵で描く目印 */
export const MAP_LANDMARKS = ((venues as { landmarks?: { key: string; name: string; address: string }[] }).landmarks ?? [])
  .map((l) => {
    const p = PLACES[l.address];
    return p ? { key: l.key, name: l.name, ...project(p.lat, p.lon) } : null;
  })
  .filter((l): l is { key: string; name: string; x: number; y: number } => !!l && inMap(l.x, l.y));

const day = (s: string) => s.slice(0, 10);

export type MapItem = {
  kind: 'event' | 'news';
  slug: string;
  title: string;
  /** 短い名前（ピンの札・キャラのせりふ） */
  short: string;
  start: string;
  end: string;
  place: string;
  area: string;
  isFree: boolean;
  img: string;
  /** 小窓に出す画像（640×360） */
  pop: string;
  /** 元の表紙（検索エンジン向けの情報に使う） */
  cover: string;
  x: number;
  y: number;
  lat?: number;
  lon?: number;
  address?: string;
};

function areaOf(p: Post): string {
  const t = (p.data.tags ?? []).find((t) => t in AREA_ADDR) ?? '';
  return t === '青海' ? 'お台場' : t;   // 青海は「お台場」の札にまとめる（2026-11-03）
}

function shorten(name: string): string {
  const s = name.replace(/[（(].*?[）)]/g, '').replace(/[｜|].*$/, '').trim();
  return s.length > 18 ? s.slice(0, 17) + '…' : s;
}

/** ピンと小窓の小さな画像（scripts/wangan-map/gen-thumbs.mjs が作る）。無ければ元の表紙 */
const small = (slug: string, kind: 'pin' | 'pop', orig: string) => {
  const rel = `/images/_wm/${slug}-${kind}.webp`;
  return fs.existsSync(path.join(process.cwd(), 'public', rel)) ? rel : orig;
};

/** マップに出すもの（イベント＋直近のニュース）。同じ場所に重なるピンは少しずつずらす */
export function mapItems(posts: Post[], today = todayJst()): MapItem[] {
  const out: MapItem[] = [];
  for (const p of posts) {
    const ev = p.data.event;
    const orig = p.data.eyecatchUrl ?? '';
    const img = orig ? small(p.id, 'pin', orig) : '';
    const pop = orig ? small(p.id, 'pop', orig) : '';
    if (ev) {
      const start = day(ev.startDate);
      const end = day(ev.endDate ?? ev.startDate);
      // 終わりの無い催し（常設の体験など）は、始まってから 60 日まで出す
      const showUntil = ev.endDate ? end : addDays(start, 60);
      if (showUntil < today) continue;
      const pl = PLACES[ev.address];
      if (!pl) continue;
      const { x, y } = project(pl.lat, pl.lon);
      if (!inMap(x, y)) continue;
      out.push({ kind: 'event', slug: p.id, title: ev.name, short: shorten(ev.name), start, end: ev.endDate ? end : '', place: ev.locationName, area: areaOf(p), isFree: !!ev.isFree, img, pop, cover: orig, x, y, lat: pl.lat, lon: pl.lon, address: ev.address });
    } else if ((p.data.tags ?? []).includes(WANGAN_NEWS_TAG)) {
      const pub = day(p.data.publishDate.toISOString());
      if (pub < addDays(today, -14)) continue;
      const area = areaOf(p);
      const a = MAP_AREAS.find((m) => m.tag === area);
      if (!a) continue;
      out.push({ kind: 'news', slug: p.id, title: p.data.title, short: shorten(p.data.title), start: pub, end: pub, place: area, area, isFree: false, img, pop, cover: orig, x: a.x, y: a.y + 26 });
    }
  }
  // 同じ点に重なるものを円く並べ直す
  const groups = new Map<string, MapItem[]>();
  for (const it of out) {
    const k = `${Math.round(it.x / 30)}:${Math.round(it.y / 30)}`;
    groups.set(k, [...(groups.get(k) ?? []), it]);
  }
  for (const g of groups.values()) {
    if (g.length < 2) continue;
    const r = 24 + g.length * 7;
    g.forEach((it, i) => {
      const a = (i / g.length) * Math.PI * 2 - Math.PI / 2;
      it.x = +(it.x + Math.cos(a) * r).toFixed(1);
      it.y = +(it.y + Math.sin(a) * r).toFixed(1);
    });
  }
  return out.sort((a, b) => a.start.localeCompare(b.start));
}

export function addDays(d: string, n: number): string {
  const t = new Date(d + 'T00:00:00Z');
  t.setUTCDate(t.getUTCDate() + n);
  return t.toISOString().slice(0, 10);
}

/** 記事の Event の構造化データに入れる緯度経度（会場の住所を引いてあれば） */
export function geoOf(address: string): Place | null {
  return PLACES[address] ?? null;
}

/** 期間の絞り込み（2026-11-03 利用者「今週・来週・今月・来月・今年くらいで選択式で」）。週は月曜はじまり */
export function periodRange(kind: 'week' | 'nextweek' | 'month' | 'nextmonth' | 'year', today = todayJst()): [string, string] {
  const [y, m, d] = today.split('-').map(Number);
  const dow = (new Date(Date.UTC(y, m - 1, d)).getUTCDay() + 6) % 7; // 月曜 0
  const mon = addDays(today, -dow);
  const pad = (n: number) => String(n).padStart(2, '0');
  const lastDay = (yy: number, mm: number) => new Date(Date.UTC(yy, mm, 0)).getUTCDate();
  switch (kind) {
    case 'week': return [mon, addDays(mon, 6)];
    case 'nextweek': return [addDays(mon, 7), addDays(mon, 13)];
    case 'month': return [`${y}-${pad(m)}-01`, `${y}-${pad(m)}-${pad(lastDay(y, m))}`];
    case 'nextmonth': { const ny = m === 12 ? y + 1 : y; const nm = m === 12 ? 1 : m + 1; return [`${ny}-${pad(nm)}-01`, `${ny}-${pad(nm)}-${pad(lastDay(ny, nm))}`]; }
    default: return [`${y}-01-01`, `${y}-12-31`];
  }
}

/** その期間に 1 日でも開かれているか */
export function overlaps(it: { start: string; end: string; kind: string }, from: string, to: string): boolean {
  const end = it.kind === 'news' ? it.start : it.end || addDays(it.start, 60);
  return it.start <= to && end >= from;
}

/** いちばん近い駅（直線距離）。会場の一覧に出す */
export function nearestStation(lat: number, lon: number): { name: string; meters: number } | null {
  let best: { name: string; meters: number } | null = null;
  for (const s of STATIONS) {
    const dy = (s.lat - lat) * 111_000;
    const dx = (s.lon - lon) * 111_000 * Math.cos((lat * Math.PI) / 180);
    const m = Math.round(Math.hypot(dx, dy) / 10) * 10;
    if (!best || m < best.meters) best = { name: `${s.name}駅`, meters: m };
  }
  return best;
}
