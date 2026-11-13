#!/usr/bin/env node
// 湾岸の会場（東京ビッグサイト・有明アリーナ・東京ガーデンシアター）の公式のイベント一覧を読み、
// src/data/venues/schedule.json に書く。LLM 不使用・$0。
//
// 2026-11-13 利用者がダイアログで「湾岸の会場の『今日』のページ」を選んだ。
// 検索候補に「東京ビッグサイト イベント 今日／明日」「有明アリーナ スケジュール 今日」が出ている。
//
// 毎朝のビルド（.github/workflows/test-build.yml の予約実行）の前に走る。
// **読めなかった会場は、前回のファイルの中身をそのまま残す**（ビルドは止めない）。
// 年が書かれていない会場（有明アリーナ・ガーデンシアター）は、読んだ月から年を決める。

import fs from 'node:fs';
import path from 'node:path';

const OUT = path.resolve('src/data/venues/schedule.json');
const UA = 'Mozilla/5.0 (compatible; DailyHackBot/1.0; +https://daily-hack.fieldbeside.com/)';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const decode = (s) =>
  s
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<[^>]+>/g, '')
    .replace(/&#8211;/g, '–')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
    .replace(/[ \t　]+/g, ' ')
    .replace(/\s*\n\s*/g, ' ')
    .trim();
const pad = (n) => String(n).padStart(2, '0');
const ymd = (y, m, d) => `${y}-${pad(m)}-${pad(d)}`;

function jstToday() {
  const d = new Date(Date.now() + 9 * 3600 * 1000);
  return { y: d.getUTCFullYear(), m: d.getUTCMonth() + 1, d: d.getUTCDate() };
}

async function get(url, headers = {}) {
  const res = await fetch(url, { headers: { 'user-agent': UA, ...headers }, signal: AbortSignal.timeout(20000) });
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  return { text: await res.text(), cookie: res.headers.get('set-cookie') || '' };
}

// ---- 東京ビッグサイト: 1 ページ 10 件・開始日の近い順。45 日先を超えたら止める ----
async function bigsight(today) {
  const limit = new Date(Date.UTC(today.y, today.m - 1, today.d + 45)).toISOString().slice(0, 10);
  const first = await get('https://www.bigsight.jp/visitor/event/');
  const cookie = first.cookie.split(',').map((c) => c.split(';')[0].trim()).filter(Boolean).join('; ');
  const events = [];
  for (let page = 1; page <= 12; page++) {
    const html = page === 1 ? first.text : (await get(`https://www.bigsight.jp/visitor/event/search.php?page=${page}`, { cookie })).text;
    const arts = html.split('<article class="lyt-event-01">').slice(1);
    if (!arts.length) break;
    let past = false;
    for (const a of arts) {
      const field = (k) => {
        const m = a.match(new RegExp(`<dt>${k}</dt>\\s*<dd>([\\s\\S]*?)</dd>`));
        return m ? decode(m[1]) : '';
      };
      const h3 = a.match(/<h3 class="hdg-01">([\s\S]*?)<\/h3>/);
      const name = h3 ? decode(h3[1].replace(/<title>[\s\S]*?<\/title>/g, '')) : '';
      const link = h3 && h3[1].match(/href="([^"]+)"/);
      const sub = (a.match(/<\/h3>\s*<p>([\s\S]*?)<\/p>/) || [])[1];
      const ds = [...field('開催期間').matchAll(/(\d{4})年(\d{1,2})月(\d{1,2})日/g)].map((m) => ymd(+m[1], +m[2], +m[3]));
      if (!name || !ds.length) continue;
      if (ds[0] > limit) past = true;
      events.push({
        name,
        sub: sub ? decode(sub) : '',
        start: ds[0],
        end: ds[ds.length - 1],
        hours: field('開催時間'),
        fee: field('料金'),
        place: field('利用施設'),
        kind: field('入場区分'),
        url: link ? decode(link[1]) : '',
      });
    }
    if (past) break;
    await sleep(600);
  }
  return events;
}

// 月だけ書かれた日付に年を付ける（読んだ月より前の月なら翌年）
function withYear(baseY, baseM, m, d) {
  const y = m < baseM - 6 ? baseY + 1 : m > baseM + 6 ? baseY - 1 : baseY;
  return ymd(y, m, d);
}

// ---- 有明アリーナ: /event/（今月）・/event/next/（来月）。li ごとに 開始・終了の日付 ----
async function ariakeArena(today) {
  const events = [];
  for (const p of ['', 'next/']) {
    const { text } = await get(`https://ariake-arena.tokyo/event/${p}`);
    for (const li of text.split(/<li id=detail-\d+>/).slice(1)) {
      const days = [...li.matchAll(/<span>(\d{1,2})\.(\d{1,2}) [A-Z]{3}<\/span>/g)].map((m) => withYear(today.y, today.m, +m[1], +m[2]));
      const name = (li.match(/<div class="event_name">\s*<p>([\s\S]*?)<\/p>/) || [])[1];
      const sub = (li.match(/<p class="sub_title">([\s\S]*?)<\/p>/) || [])[1];
      const row = (k) => {
        const m = li.match(new RegExp(`${k}</th>\\s*<td>([\\s\\S]*?)</td>`));
        return m ? decode(m[1]) : '';
      };
      const url = (li.match(/公式サイト<\/th>\s*<td><a href=["']?([^"' >]+)/) || [])[1] || '';
      if (!name || !days.length) continue;
      days.sort();
      events.push({ name: decode(name), sub: sub ? decode(sub) : '', start: days[0], end: days[days.length - 1], hours: row('公演時間'), fee: row('料金').slice(0, 120), place: 'メインアリーナ', kind: '', url });
    }
    await sleep(600);
  }
  return events;
}

// ---- 東京ガーデンシアター: ?date=YYYY-MM。ymd が 2 つなら開始と終了 ----
async function gardenTheater(today) {
  const events = [];
  for (let i = 0; i < 2; i++) {
    const dt = new Date(Date.UTC(today.y, today.m - 1 + i, 1));
    const y = dt.getUTCFullYear();
    const mo = dt.getUTCMonth() + 1;
    const { text } = await get(`https://www.shopping-sumitomo-rd.com/tokyo_garden_theater/schedule/?date=${y}-${pad(mo)}`);
    for (const li of text.split(/<li class="event_all[^"]*">/).slice(1)) {
      const days = [...li.matchAll(/<div class="m">(\d{1,2})<\/div>\s*<div class="d">(\d{1,2})<\/div>/g)].map((m) => withYear(y, mo, +m[1], +m[2]));
      const player = (li.match(/<div class="player"[^>]*>([\s\S]*?)<\/div>/) || [])[1];
      const title = (li.match(/<div class="title"[^>]*>([\s\S]*?)<\/div>/) || [])[1];
      const tag = (li.match(/<div class="tag">([\s\S]*?)<\/div>/) || [])[1];
      const url = (li.match(/<a href="([^"]+)"/) || [])[1] || '';
      if (!title || !days.length) continue;
      days.sort();
      events.push({ name: decode(title), sub: player ? decode(player) : '', start: days[0], end: days[days.length - 1], hours: '', fee: '', place: '', kind: tag ? decode(tag) : '', url });
    }
    await sleep(600);
  }
  return events;
}

const VENUES = [
  { key: 'bigsight', name: '東京ビッグサイト', area: '有明', source: 'https://www.bigsight.jp/visitor/event/', run: bigsight },
  { key: 'ariake-arena', name: '有明アリーナ', area: '有明', source: 'https://ariake-arena.tokyo/event/', run: ariakeArena },
  { key: 'garden-theater', name: '東京ガーデンシアター', area: '有明', source: 'https://www.shopping-sumitomo-rd.com/tokyo_garden_theater/schedule/', run: gardenTheater },
];

const prev = fs.existsSync(OUT) ? JSON.parse(fs.readFileSync(OUT, 'utf8')) : { venues: {} };
const today = jstToday();
const out = { generated: new Date().toISOString(), venues: {} };
let failed = 0;
for (const v of VENUES) {
  try {
    const events = await v.run(today);
    // 同じ名前・同じ開始日は 1 件にする（月をまたぐ公演が 2 ページに出る）
    const seen = new Set();
    const uniq = events.filter((e) => {
      const k = `${e.name}|${e.start}`;
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });
    if (!uniq.length) throw new Error('0 件（ページの作りが変わった可能性）');
    out.venues[v.key] = { name: v.name, area: v.area, source: v.source, fetched: out.generated, events: uniq };
    console.log(`✓ ${v.name}: ${uniq.length} 件`);
  } catch (e) {
    failed++;
    console.log(`⚠️ ${v.name}: 読めなかった（${e.message}）。前回の中身を残す`);
    if (prev.venues?.[v.key]) out.venues[v.key] = prev.venues[v.key];
  }
}
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out, null, 1) + '\n');
JSON.parse(fs.readFileSync(OUT, 'utf8'));
console.log(`対象 ${VENUES.length} 会場 / 読めた ${VENUES.length - failed} 会場`);
