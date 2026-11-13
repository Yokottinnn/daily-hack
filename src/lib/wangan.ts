/**
 * 湾岸ライフ（中央区・江東区の湾岸）の検索・AI 回答向けの共通部品（2026-10-30）。
 *
 * - 地区（タグ）の一覧と、その区
 * - フロントマターの `event:` から「これから・開催中」のイベントを選ぶ
 *
 * **港区・品川区は対象外**（docs/wangan-news-routine.md の「対象の範囲」）。地区の一覧にも入れない。
 * 日付の判定は**ビルドした日（日本時間）**で行う。湾岸ニュースは毎朝ビルドされるので、一覧は毎朝入れ替わる。
 */
import type { CollectionEntry } from 'astro:content';

type Post = CollectionEntry<'posts'>;

/** 対象の地区。並びは記事の多い順に近い形で固定（表示の順） */
// 2026-11-03 利用者「築地は湾岸エリアだと思うので追加して／湾岸ライフ自体のエリアのカテゴリーにも追加して」
// 2026-11-03 利用者「エリアの名前は青海じゃなくてお台場にして（検索ワード数が圧倒的に多い）」→ 札・地区ページは「お台場」。住所は江東区青海（`town`）
export const WANGAN_AREAS: { tag: string; ward: string; lead: string; town?: string }[] = [
  { tag: '豊洲', ward: '江東区', lead: 'ららぽーと豊洲・豊洲市場・千客万来・新豊洲のイベントと開業' },
  { tag: '有明', ward: '江東区', lead: '有明ガーデン・有明アリーナ・有明コロシアム・防災公園のイベント' },
  { tag: '晴海', ward: '中央区', lead: '晴海フラッグ・晴海トリトン・東京湾大華火祭の観覧会場' },
  { tag: '勝どき', ward: '中央区', lead: '勝どき駅まわりの開業・交通・暮らし' },
  { tag: '月島', ward: '中央区', lead: 'もんじゃの街・月島の暮らしとタワマン' },
  { tag: '築地', ward: '中央区', lead: '築地場外市場・築地本願寺のイベントと開業' },
  { tag: 'お台場', ward: '江東区', town: '青海', lead: 'ダイバーシティ東京・TOYOTA ARENA TOKYO（江東区青海）のイベントと開業' },
  { tag: '東雲', ward: '江東区', lead: '東雲の暮らしと開業' },
  { tag: '辰巳', ward: '江東区', lead: '辰巳の暮らしと開業' },
  { tag: '佃', ward: '中央区', lead: '佃の暮らし' },
  { tag: '豊海', ward: '中央区', lead: '豊海の暮らし' },
];

export const WANGAN_NEWS_TAG = '湾岸ニュース';

export function isWanganArea(tag: string): boolean {
  return WANGAN_AREAS.some((a) => a.tag === tag);
}

/** 日本時間の今日（YYYY-MM-DD） */
export function todayJst(now = new Date()): string {
  return new Date(now.getTime() + 9 * 3600 * 1000).toISOString().slice(0, 10);
}

/** `2026-11-21` や `2026-11-21T12:00:00+09:00` から日付だけ */
const day = (s: string) => s.slice(0, 10);

const WD = ['日', '月', '火', '水', '木', '金', '土'];
/** `2026-11-21` → `2026年11月21日（土）` */
export function jpDate(s: string): string {
  const [y, m, d] = day(s).split('-').map(Number);
  const w = WD[new Date(Date.UTC(y, m - 1, d)).getUTCDay()];
  return `${y}年${m}月${d}日（${w}）`;
}

/** 期間の表示。同じ日なら 1 つ */
export function jpRange(start: string, end?: string): string {
  if (!end || day(end) === day(start)) return jpDate(start);
  const sameYear = day(end).slice(0, 4) === day(start).slice(0, 4);
  return `${jpDate(start)}〜${sameYear ? jpDate(end).replace(/^\d+年/, '') : jpDate(end)}`;
}

export type UpcomingEvent = {
  post: Post;
  name: string;
  start: string;
  end: string;
  place: string;
  isFree: boolean;
  /** 今日が期間の中なら true */
  ongoing: boolean;
};

/** これから・開催中のイベント（終わったものは出さない）。開始が近い順 */
export function upcomingEvents(posts: Post[], today = todayJst()): UpcomingEvent[] {
  return posts
    .filter((p) => p.data.event)
    .map((p) => {
      const ev = p.data.event!;
      const start = day(ev.startDate);
      const end = day(ev.endDate ?? ev.startDate);
      return {
        post: p,
        name: ev.name,
        start,
        end,
        place: ev.locationName,
        isFree: !!ev.isFree,
        ongoing: start <= today && today <= end,
      };
    })
    .filter((e) => e.end >= today)
    .sort((a, b) => a.start.localeCompare(b.start) || a.end.localeCompare(b.end));
}

/** 住所を 都道府県・区・それ以降 に分ける（Event の構造化データ用） */
export function splitJpAddress(address: string): { region?: string; locality?: string; street: string } {
  const m = address.match(/^(東京都)?\s*([^\s]+?区)\s*(.*)$/);
  if (!m) return { street: address };
  return { region: m[1] ?? '東京都', locality: m[2], street: m[3] || address };
}

/** `YYYY-MM-DD` に日数を足す（日本時間の日付として扱う） */
export function addDays(s: string, n: number): string {
  const [y, m, d] = day(s).split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}

/** 今週末（土日）。今日が土曜なら今日と明日、日曜なら昨日と今日 */
export function thisWeekend(today = todayJst()): { sat: string; sun: string } {
  const [y, m, d] = today.split('-').map(Number);
  const w = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  const sat = w === 0 ? addDays(today, -1) : addDays(today, 6 - w);
  return { sat, sun: addDays(sat, 1) };
}

/**
 * 今日・明日・今週末に開いているイベント（2026-11-13 利用者がダイアログで「題名と見出しに今日・今週末」「今日・明日の節を足す」を選んだ）。
 * Google の検索候補で地区名＋「イベント 今日／明日／今週末」が多かったため。判定はビルドした日（日本時間）
 */
export function eventsByDay(events: UpcomingEvent[], today = todayJst()) {
  const tomorrow = addDays(today, 1);
  const { sat, sun } = thisWeekend(today);
  const on = (e: UpcomingEvent, a: string, b = a) => e.start <= b && a <= e.end;
  return {
    today,
    tomorrow,
    sat,
    sun,
    todayList: events.filter((e) => on(e, today)),
    tomorrowList: events.filter((e) => on(e, tomorrow)),
    weekendList: events.filter((e) => on(e, sat, sun)),
  };
}
