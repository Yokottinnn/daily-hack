/**
 * 湾岸の会場のスケジュール（2026-11-13 利用者がダイアログで「湾岸の会場の『今日』のページ」を選んだ）。
 * 中身は scripts/fetch-venue-schedules.mjs が公式の一覧から毎朝書く src/data/venues/schedule.json。
 */
import data from '../data/venues/schedule.json';
import { addDays, thisWeekend, todayJst } from './wangan';

export type VenueEvent = {
  name: string;
  sub: string;
  start: string;
  end: string;
  hours: string;
  fee: string;
  place: string;
  kind: string;
  url: string;
};
export type Venue = { key: string; name: string; area: string; source: string; fetched: string; events: VenueEvent[] };

/** 会場ごとのページの文言。検索候補（2026-11-13 取得）に合わせた題名 */
export const VENUE_META: Record<string, { short: string; query: string; access: string; lead: string }> = {
  bigsight: {
    short: 'ビッグサイト',
    query: '東京ビッグサイトのイベント',
    access: 'ゆりかもめ「東京ビッグサイト駅」から徒歩約3分、りんかい線「国際展示場駅」から徒歩約7分（公式サイトの交通案内。2026年11月13日に確認）',
    lead: '展示会・同人誌即売会・フリーマーケットなど、国内最大級の展示場で開かれるイベント。一般の人が入れるものと、仕事の人だけの商談のものがあるので、入場区分も並べたわ。',
  },
  'ariake-arena': {
    short: '有明アリーナ',
    query: '有明アリーナのスケジュール',
    access: 'ゆりかもめ「新豊洲駅」「有明テニスの森駅」から徒歩約8分、りんかい線「国際展示場駅」「東雲駅」から徒歩約17分（公式サイトの交通案内。2026年11月13日に確認）',
    lead: 'コンサートとスポーツの大きな会場。開場・開演の時刻は公式サイトの表記のまま載せているわ。',
  },
  'garden-theater': {
    short: 'ガーデンシアター',
    query: '東京ガーデンシアターのスケジュール',
    access: 'ゆりかもめ「有明駅」2B出口から徒歩4分、「有明テニスの森駅」2A出口から徒歩5分、りんかい線「国際展示場駅」A出口から徒歩7分（公式サイトの交通案内。2026年11月13日に確認）',
    lead: '有明ガーデンの中にある劇場型のホール。コンサート・舞台が中心よ。',
  },
};

export const venues: Venue[] = Object.entries((data as { venues: Record<string, Omit<Venue, 'key'>> }).venues).map(([key, v]) => ({ key, ...v }));
export const generated: string = (data as { generated: string }).generated;

const on = (e: VenueEvent, a: string, b = a) => e.start <= b && a <= e.end;

/** 今日・明日・今週末・これから（30 日）に分ける。判定はビルドした日（日本時間） */
export function venueDays(events: VenueEvent[], today = todayJst()) {
  const tomorrow = addDays(today, 1);
  const { sat, sun } = thisWeekend(today);
  const until = addDays(today, 30);
  return {
    today,
    tomorrow,
    sat,
    sun,
    todayList: events.filter((e) => on(e, today)),
    tomorrowList: events.filter((e) => on(e, tomorrow)),
    weekendList: events.filter((e) => on(e, sat, sun)),
    upcoming: events.filter((e) => e.end >= today && e.start <= until).sort((a, b) => a.start.localeCompare(b.start)),
  };
}
