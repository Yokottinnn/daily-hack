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
import basemap from '../data/wangan-basemap.json';
import venues from '../data/wangan-venues.json';
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

const WARD_CODE: Record<string, string> = { '13102': '中央区', '13108': '江東区', '13103': '港区', '13109': '品川区' };

export const MAP_LAND = basemap.land.map((l) => ({ d: l.d, ward: WARD_CODE[l.muni] ?? '' }));
export const MAP_SOURCE = basemap.source;

/** 地区の札（区の住所検索の位置） */
const AREA_ADDR: Record<string, string> = {
  晴海: '東京都中央区晴海', 勝どき: '東京都中央区勝どき', 月島: '東京都中央区月島', 佃: '東京都中央区佃', 豊海: '東京都中央区豊海町',
  豊洲: '東京都江東区豊洲', 有明: '東京都江東区有明', 東雲: '東京都江東区東雲', 辰巳: '東京都江東区辰巳', 青海: '東京都江東区青海',
};
/** 札の置き場所の微調整（住所検索の代表点は丁目の端に出ることがある。札が島から外れないよう寄せる） */
const AREA_NUDGE: Record<string, [number, number]> = { 晴海: [-60, 10], 佃: [0, -12], 月島: [-8, 6] };

/** 札を島の真ん中に置く地区（住所検索の代表点が島の端に出るもの）。緯度経度で指定 */
const AREA_AT: Record<string, Place> = { 豊洲: { lat: 35.6505, lon: 139.7885 } };

export const MAP_AREAS = WANGAN_AREAS.map((a) => {
  const p = AREA_AT[a.tag] ?? PLACES[AREA_ADDR[a.tag]];
  if (!p) return null;
  const { x, y } = project(p.lat, p.lon);
  const [dx, dy] = AREA_NUDGE[a.tag] ?? [0, 0];
  return { tag: a.tag, ward: a.ward, x: x + dx, y: y + dy };
}).filter((a): a is { tag: string; ward: string; x: number; y: number } => !!a && a.x > 0 && a.x < 1000 && a.y > 0 && a.y < 1000);

/** 地図に絵で描く目印 */
export const MAP_LANDMARKS = ((venues as { landmarks?: { key: string; name: string; address: string }[] }).landmarks ?? [])
  .map((l) => {
    const p = PLACES[l.address];
    return p ? { key: l.key, name: l.name, ...project(p.lat, p.lon) } : null;
  })
  .filter((l): l is { key: string; name: string; x: number; y: number } => !!l);

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
  x: number;
  y: number;
  lat?: number;
  lon?: number;
  address?: string;
};

function areaOf(p: Post): string {
  return (p.data.tags ?? []).find((t) => t in AREA_ADDR) ?? '';
}

function shorten(name: string): string {
  const s = name.replace(/[（(].*?[）)]/g, '').replace(/[｜|].*$/, '').trim();
  return s.length > 18 ? s.slice(0, 17) + '…' : s;
}

/** マップに出すもの（イベント＋直近のニュース）。同じ場所に重なるピンは少しずつずらす */
export function mapItems(posts: Post[], today = todayJst()): MapItem[] {
  const out: MapItem[] = [];
  for (const p of posts) {
    const ev = p.data.event;
    const img = p.data.eyecatchUrl ?? '';
    if (ev) {
      const start = day(ev.startDate);
      const end = day(ev.endDate ?? ev.startDate);
      // 終わりの無い催し（常設の体験など）は、始まってから 60 日まで出す
      const showUntil = ev.endDate ? end : addDays(start, 60);
      if (showUntil < today) continue;
      const pl = PLACES[ev.address];
      if (!pl) continue;
      const { x, y } = project(pl.lat, pl.lon);
      if (x < 0 || x > 1000 || y < 0 || y > 1000) continue;
      out.push({ kind: 'event', slug: p.id, title: ev.name, short: shorten(ev.name), start, end: ev.endDate ? end : '', place: ev.locationName, area: areaOf(p), isFree: !!ev.isFree, img, x, y, lat: pl.lat, lon: pl.lon, address: ev.address });
    } else if ((p.data.tags ?? []).includes(WANGAN_NEWS_TAG)) {
      const pub = day(p.data.publishDate.toISOString());
      if (pub < addDays(today, -14)) continue;
      const area = areaOf(p);
      const a = MAP_AREAS.find((m) => m.tag === area);
      if (!a) continue;
      out.push({ kind: 'news', slug: p.id, title: p.data.title, short: shorten(p.data.title), start: pub, end: pub, place: area, area, isFree: false, img, x: a.x, y: a.y + 26 });
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
