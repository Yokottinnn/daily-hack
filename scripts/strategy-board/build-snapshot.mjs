#!/usr/bin/env node
// 収益化作戦室（https://claude.ai/artifact/9KWGybrAHF7LtbQdVpw9YN）に載せる数字と所見を、手元の一次データから作る。
// LLM 不使用・$0。毎週のルーティン（docs/strategy-board-routine.md）がクラウドで走らせ、
// 出力の JSON を ArtifactData でサイトの db（snapshot/latest と snapshots/<日付>）に書く。
//
//   node scripts/strategy-board/build-snapshot.mjs --out /tmp/snapshot.json [--hist <db の snapshot/hist の JSON>] [--results <db の results/latest の JSON>]
//   --hist を付けると、その日の数字を 1 行足した <out>.hist.json も書く（作戦室の全体像の「前週・前月との差」・2026-11-19）
//
// 読むもの（すべて git の参照から。ネットワークに出ない）:
//   origin/ops/heartbeat : reports/board/gsc-weekly.json（無ければ最新の gsc-monthly-*.json → t205-gsc-full.json）
//                          reports/board/asp-probe/a8partnered.json / reports/board/mac-weekly-status.json
//                          reports/asp-sync/status.json
//   origin/ops/pv-archive: data/<YYYY-MM>.json（日ごとの訪問。human がボット除外の数）
//   作業ツリー           : src/content/posts/*.md（記事数・PR 表記・成果リンクの有無）
//                          ops/data/board/manual.json（審査中の申請など、データから取れない事実）
//
// **数字に無いことは書かない。** 所見は下の RULES の条件に当たったものだけ。推測で埋めない（最上位ルール 11・20）。
import { buildInventory } from './aff-inventory.mjs';
import { entryOf, addDay, jstDate } from './home-hist.mjs';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const args = Object.fromEntries(process.argv.slice(2).map((a, i, all) => a.startsWith('--') ? [a.slice(2), all[i + 1]] : null).filter(Boolean));
const OUT = args.out || '/tmp/strategy-board-snapshot.json';
const git = (...a) => { try { return execFileSync('git', ['-C', ROOT, ...a], { encoding: 'utf8', maxBuffer: 64 << 20, stdio: ['ignore', 'pipe', 'ignore'] }); } catch { return null; } };
const show = (ref, file) => git('show', `${ref}:${file}`);
const json = (txt) => { try { return txt ? JSON.parse(txt) : null; } catch { return null; } };
const lastTouched = (ref, file) => (git('log', '-1', '--format=%cI', ref, '--', file) || '').trim() || null;
for (const b of ['ops/heartbeat', 'ops/pv-archive']) git('fetch', '-q', 'origin', `${b}:refs/remotes/origin/${b}`);
const HB = 'origin/ops/heartbeat', PV = 'origin/ops/pv-archive';
const today = new Date();
const iso = (d) => d.toISOString().slice(0, 10);
const daysAgo = (s) => s ? Math.round((today - new Date(s)) / 864e5) : null;

// ---------- 記事 ----------
const POSTS_DIR = path.join(ROOT, 'src/content/posts');
const AFF = /a8mat=|px\.a8\.net|hb\.afl\.rakuten\.co\.jp|r10\.to\/|af\.moshimo\.com|moshimo\.com\/af|valuecommerce\.(com|ne\.jp)\/(servlet|resolve)|ck\.jp\.ap\.valuecommerce|rel="[^"]*sponsored/g;
const posts = {};
for (const f of fs.readdirSync(POSTS_DIR).filter((x) => x.endsWith('.md'))) {
  const src = fs.readFileSync(path.join(POSTS_DIR, f), 'utf8');
  const fm = (src.match(/^---\n([\s\S]*?)\n---/) || [])[1] || '';
  const get = (k) => ((fm.match(new RegExp(`^${k}:\\s*"?(.*?)"?\\s*$`, 'm')) || [])[1] || '').trim();
  if (get('draft') === 'true') continue;
  const slug = f.replace(/\.md$/, '');
  posts[slug] = { slug, title: get('title'), isPR: get('isPR') === 'true', updated: get('updatedDate') || get('publishDate'), published: (get('publishDate') || '').slice(0, 10), updatedOnly: (get('updatedDate') || '').slice(0, 10), aff: (src.match(AFF) || []).length,
    cats: ((fm.match(/^category:\s*(.*)$/m) || [])[1] || '').match(/[a-z-]+/g) || [] };
}
const postList = Object.values(posts);

// ---------- 検索（GSC） ----------
let gscFile = 'reports/board/gsc-weekly.json';
let gsc = json(show(HB, gscFile));
if (!gsc) {
  const monthly = (git('ls-tree', '-r', '--name-only', HB, 'reports/') || '').split('\n').filter((x) => /reports\/gsc-monthly-\d{4}-\d{2}\.json$/.test(x)).sort();
  gscFile = monthly.pop() || 'reports/t205-gsc-full.json';
  gsc = json(show(HB, gscFile));
}
const slugOf = (url) => (url.match(/\/posts\/([^/]+)\//) || [])[1] || null;
const sum = (rows, k) => (rows || []).reduce((a, r) => a + (r[k] || 0), 0);
const wavg = (rows) => { const i = sum(rows, 'i'); return i ? (rows || []).reduce((a, r) => a + r.p * r.i, 0) / i : null; };
const gscWin = (k) => {
  const rows = gsc?.data?.[k] || [];
  const c = sum(rows, 'c'), i = sum(rows, 'i');
  return { from: gsc?.windows?.[k]?.[0] || null, to: gsc?.windows?.[k]?.[1] || null, clicks: c, impressions: i, ctr: i ? +(c / i * 100).toFixed(2) : null, position: wavg(rows) && +wavg(rows).toFixed(1) };
};
const gscCur = gscWin('pages_cur'), gscPrev = gscWin('pages_prev'), gsc90 = gscWin('pages_90d');
const pages90 = (gsc?.data?.pages_90d || []).map((r) => ({ slug: slugOf(r.keys[0]), url: r.keys[0], c: r.c, i: r.i, p: r.p })).filter((r) => r.slug);
const topPages = pages90.sort((a, b) => b.i - a.i).slice(0, 15).map((r) => ({ ...r, title: posts[r.slug]?.title || r.slug, aff: posts[r.slug]?.aff || 0 }));
const pos4to10 = pages90.filter((r) => r.p >= 4 && r.p <= 10.9);
const queries = (gsc?.data?.queries_90d || []).sort((a, b) => b.i - a.i).slice(0, 15).map((r) => ({ q: r.keys[0], c: r.c, i: r.i, p: r.p }));
// 記事×検索語（90 日）。作戦室の「2 ページ目までに入っている語と記事」（2026-10-24・利用者のコメント）。
// Search Console は表示の少ない語を伏せるので、ここに出るのは伏せられなかった語だけ。
const pq = (gsc?.data?.pq_90d || []).map((r) => ({ slug: slugOf(r.keys[0]), q: r.keys[1], c: r.c, i: r.i, p: r.p })).filter((r) => r.slug);   // 題名は articles から引く
// 日ごとの表示・クリックを週にまとめる（推移グラフ用）
const weekly = {};
for (const r of gsc?.data?.dates_90d || []) {
  const d = new Date(r.keys[0]); const monday = new Date(d); monday.setDate(d.getDate() - ((d.getDay() + 6) % 7));
  const k = iso(monday); weekly[k] = weekly[k] || { week: k, clicks: 0, impressions: 0, days: 0 };
  weekly[k].clicks += r.c; weekly[k].impressions += r.i; weekly[k].days++;
}
const gscWeekly = Object.values(weekly).sort((a, b) => a.week.localeCompare(b.week));
// 月ごと（2026-11-03 利用者のコメント）。dates_16m が無い間は 90 日分から作る。full = その月の日がそろっている
const monthlyG = {};
for (const r of gsc?.data?.dates_16m || gsc?.data?.dates_90d || []) {
  const k = r.keys[0].slice(0, 7); monthlyG[k] = monthlyG[k] || { month: k, clicks: 0, impressions: 0, days: 0 };
  monthlyG[k].clicks += r.c; monthlyG[k].impressions += r.i; monthlyG[k].days++;
}
const gscMonthly = Object.values(monthlyG).sort((a, b) => a.month.localeCompare(b.month))
  .map((m) => ({ ...m, full: m.days >= new Date(Date.UTC(+m.month.slice(0, 4), +m.month.slice(5, 7), 0)).getUTCDate() }));
// 最初の月は窓の途中から始まるので、日がそろっていなければ落とす
if (gscMonthly.length > 1 && !gscMonthly[0].full) gscMonthly.shift();

// ---------- 読者（Cloudflare・ボット除外） ----------
const months = [...new Set([0, 1, 2, 3].map((k) => { const d = new Date(today); d.setMonth(d.getMonth() - k, 1); return iso(d).slice(0, 7); }))];
const daily = {};
for (const m of months) Object.assign(daily, json(show(PV, `data/${m}.json`)) || {});
const days = Object.keys(daily).sort();
const lastDay = days[days.length - 1] || null;
const in28 = days.filter((d) => lastDay && (new Date(lastDay) - new Date(d)) / 864e5 < 28);
const inPrev28 = days.filter((d) => lastDay && (new Date(lastDay) - new Date(d)) / 864e5 >= 28 && (new Date(lastDay) - new Date(d)) / 864e5 < 56);
const pvSum = (ds, k) => ds.reduce((a, d) => a + (daily[d]?.[k] || 0), 0);
const pathVisits = {};
for (const d of in28) for (const t of daily[d]?.top || []) { const s = slugOf('https://x' + t.path); if (s) pathVisits[s] = (pathVisits[s] || 0) + (t.v || 0); }
const readTop = Object.entries(pathVisits).sort((a, b) => b[1] - a[1]).slice(0, 20).map(([slug, v]) => ({ slug, v, title: posts[slug]?.title || slug, aff: posts[slug]?.aff || 0 }));

// ---------- 記事ごとの表（作戦室の「記事を調べる」と、流入元の説明に使う） ----------
// 訪問 v は Cloudflare の記事別の数で **ボットを含む**（pv-archive の top は記事別にボットを分けていない）。
// ボット除外の訪問と参照元は、pv-archive の posts（2026-10-12 に足した）がある日だけ取れる。
const in90 = days.filter((d) => lastDay && (new Date(lastDay) - new Date(d)) / 864e5 < 90);
const visitsIn = (ds) => { const m = {}; for (const d of ds) for (const t of daily[d]?.top || []) { const s = slugOf('https://x' + t.path); if (s) m[s] = (m[s] || 0) + (t.v || 0); } return m; };
const v28 = visitsIn(in28), v90 = visitsIn(in90);
const refDays28 = in28.filter((d) => daily[d]?.posts);
const human28 = {}, refs28 = {};
for (const d of refDays28) for (const [p, x] of Object.entries(daily[d].posts || {})) {
  const s = slugOf('https://x' + p); if (!s) continue;
  human28[s] = (human28[s] || 0) + (x.human || 0);
  const r = (refs28[s] = refs28[s] || {});
  for (const [h, n] of Object.entries(x.ref || {})) r[h] = (r[h] || 0) + n;
}
// 参照元ホストを読み手の言葉にまとめる
const refGroup = (h) => /(^|\.)(t\.co|x\.com|twitter\.com)$/.test(h) ? 'X' : /google\./.test(h) ? 'Google' : /yahoo\./.test(h) ? 'Yahoo!' : /bing\.com$/.test(h) ? 'Bing' : /daily-hack\.fieldbeside\.com$/.test(h) ? 'サイト内' : h === '(なし)' ? '参照元なし（アプリ・ブックマーク等）' : 'その他';
const groupRefs = (r) => { const g = {}; for (const [h, n] of Object.entries(r || {})) { const k = refGroup(h); g[k] = (g[k] || 0) + n; } return Object.entries(g).sort((a, b) => b[1] - a[1]).map(([k, n]) => ({ k, n })); };
const pagesCur = Object.fromEntries((gsc?.data?.pages_cur || []).map((r) => [slugOf(r.keys[0]), r]).filter(([k]) => k));
const pages90m = Object.fromEntries((gsc?.data?.pages_90d || []).map((r) => [slugOf(r.keys[0]), r]).filter(([k]) => k));
const articles = postList.map((p) => ({
  slug: p.slug, title: p.title, aff: p.aff, isPR: p.isPR, updated: p.updated, pub: p.published, cats: p.cats,
  c28: pagesCur[p.slug]?.c || 0, i28: pagesCur[p.slug]?.i || 0, p28: pagesCur[p.slug]?.p ?? null,
  c90: pages90m[p.slug]?.c || 0, i90: pages90m[p.slug]?.i || 0, p90: pages90m[p.slug]?.p ?? null,
  v28: v28[p.slug] || 0, v90: v90[p.slug] || 0,
  h28: refDays28.length ? (human28[p.slug] || 0) : null,
  refs28: refDays28.length ? groupRefs(refs28[p.slug]) : null,
})).sort((a, b) => b.v28 - a.v28 || b.i90 - a.i90);
for (const r of topPages) r.v90 = v90[r.slug] || 0;
for (const r of readTop) { r.c28 = pagesCur[r.slug]?.c || 0; r.h28 = refDays28.length ? (human28[r.slug] || 0) : null; r.refs28 = refDays28.length ? groupRefs(refs28[r.slug]) : null; }
// ボット除外の訪問が取れていれば、「読まれている記事」はそれで並べ直す（ボット込みだと読まれていない記事が上に来る）
if (refDays28.length) {
  readTop.splice(0, readTop.length, ...articles.filter((a) => a.h28 > 0).sort((a, b) => b.h28 - a.h28).slice(0, 20)
    .map((a) => ({ slug: a.slug, v: a.v28, title: a.title, aff: a.aff, c28: a.c28, h28: a.h28, refs28: a.refs28 })));
}
// ---------- 記事以外のページ（トップ・カテゴリの一覧・地図など）の読者（2026-11-21） ----------
// 利用者がダイアログで「一覧ページの閲覧数も作戦室で見えるようにする」を選んだ。
// 読者（ボット除外）は pv-archive の pages（2026-11-21 から・上位 100 パス）がある日だけ。訪問（ボット込み）は top から全日。
const CAT_LABEL = { campaigns: 'キャンペーン速報', services: 'サービス紹介', comparisons: '比較', roundups: 'まとめ', howto: 'ハウツー', 'wangan-life': '湾岸ライフ', rankings: 'ランキング' };
const pageLabel = (pth) => {
  let m;
  if (pth === '/') return 'トップページ';
  if ((m = pth.match(/^\/category\/([^/]+)\/(?:(\d+)\/)?$/))) return `カテゴリの一覧：${CAT_LABEL[m[1]] || m[1]}${m[2] ? `（${m[2]} ページ目）` : ''}`;
  if ((m = pth.match(/^\/tags\/([^/]+)\/$/))) { let t = m[1]; try { t = decodeURIComponent(t); } catch (e) {} return `タグの一覧：${t}`; }
  if (pth === '/wangan-map/') return '湾岸イベントマップ';
  const FIX = { '/author/': '運営者のページ', '/about/': 'このサイトについて', '/contact/': 'お問い合わせ', '/posts/': '記事の一覧', '/tags/': 'タグの一覧（全体）', '/privacy/': 'プライバシーポリシー' };
  if (FIX[pth]) return FIX[pth];
  if (pth === '/venues/') return '会場の一覧';
  if ((m = pth.match(/^\/venues\/([^/]+)\/$/))) return `会場のページ：${m[1]}`;
  if (pth.startsWith('/posts/')) return '記事の一覧';
  return pth;
};
const isPagePath = (pth) => !/^\/posts\/[^/]+\/$/.test(pth) && !/\.[a-z0-9]{2,5}$/i.test(pth) && !/^\/(_|api\/|cdn-cgi\/)/.test(pth);
const pageDays28 = in28.filter((d) => daily[d]?.pages);
const pagesAgg = {};
for (const d of in28) for (const t of daily[d]?.top || []) { if (!isPagePath(t.path)) continue; const r = (pagesAgg[t.path] = pagesAgg[t.path] || { path: t.path, v: 0, h: 0 }); r.v += t.v || 0; }
for (const d of pageDays28) for (const [pth, x] of Object.entries(daily[d].pages || {})) { if (!isPagePath(pth)) continue; const r = (pagesAgg[pth] = pagesAgg[pth] || { path: pth, v: 0, h: 0 }); r.h += x.human || 0; }
// 上位 30 に、カテゴリの一覧（1 ページ目）は入らなくても必ず足す（どのカテゴリの一覧が読まれているかを比べるため）
const pagesSorted = Object.values(pagesAgg).sort((a, b) => (pageDays28.length ? b.h - a.h : 0) || b.v - a.v);
const pagesTop = [...pagesSorted.slice(0, 30), ...pagesSorted.slice(30).filter((r) => /^\/category\/[^/]+\/$/.test(r.path))]
  .map((r) => ({ path: r.path, label: pageLabel(r.path), v28: r.v, h28: pageDays28.length ? r.h : null }));
const pagesMeta = { humanDays: pageDays28.length, days: in28.length, from: pageDays28[0] || null };

// 日ごとの訪問（記事の詳細で棒にする）と、全記事が同じ日に跳ねた日（読者ではない一斉アクセスの疑い）
const recentDays = days.slice(-45);
const postTotal = (d) => (daily[d]?.top || []).filter((t) => t.path.startsWith('/posts/')).reduce((a, t) => a + (t.v || 0), 0);
const med = (xs) => { const y = [...xs].sort((a, b) => a - b); return y.length ? y[Math.floor(y.length / 2)] : 0; };
const medTotal = med(recentDays.map(postTotal));
const spikeDays = recentDays.filter((d) => medTotal && postTotal(d) >= medTotal * 3);
// X の告知日（画像レビューページに記録された投稿 ID から。ID に投稿時刻が入っている）
const reviewPage = fs.existsSync(path.join(ROOT, 'scripts/image-review/page.html')) ? fs.readFileSync(path.join(ROOT, 'scripts/image-review/page.html'), 'utf8') : '';
const xPosts = {};
for (const m of reviewPage.matchAll(/slug:\s*"([^"]+)",[^\n]*\n\s*posted:\s*\[\s*"(\d+)"/g)) {
  const t = new Date(Number((BigInt(m[2]) >> 22n) + 1288834974657n));
  (xPosts[m[1]] = xPosts[m[1]] || []).push(t.toISOString().slice(0, 10));   // 訪問の日付（UTC）にそろえる
}
for (const a of articles) {
  a.series = recentDays.map((d) => [d, (daily[d]?.top || []).find((t) => t.path === `/posts/${a.slug}/`)?.v || 0]);
  a.xDates = xPosts[a.slug] || [];
  const spikeV = a.series.filter(([d]) => spikeDays.includes(d)).reduce((x, [, v]) => x + v, 0);
  const xV = a.series.filter(([d]) => a.xDates.some((x) => { const k = (new Date(d) - new Date(x)) / 864e5; return k >= 0 && k <= 1; })).reduce((x, [, v]) => x + v, 0);
  a.why = { spikeV, xV };   // 28 日ではなく、表示している 45 日の中での数
}
// 日ごとの訪問は、日付が 1 日ずつ続いていれば値だけ（sv）にして詰める。日付は pvMeta.seriesDays から引く
// （2026-10-31 にスナップショットが保存先の 1 件の上限 256KB を超えたため。作戦室は series と sv の両方を読む）
const seriesDays = recentDays.slice();
const contiguous = seriesDays.every((d, i) => !i || (new Date(d) - new Date(seriesDays[i - 1])) / 864e5 === 1);
if (contiguous) for (const a of articles) { a.sv = a.series.map(([, v]) => v); delete a.series; }
const pvMeta = { first: days[0] || null, last: lastDay, days90: in90.length, refFrom: days.find((d) => daily[d]?.posts) || null, refDays28: refDays28.length, spikeDays, seriesFrom: recentDays[0] || null, seriesDays: recentDays.length };

// ---------- ブログ全体の月ごとの動き（記事の公開・更新・訪問・ページビュー） ----------
// 公開・更新は記事のフロントマター（publishDate / updatedDate）。PV・UU は pv-archive の zone（**ゾーン全体**）。
const monthly = {};
const mm = (d) => (d || '').slice(0, 7);
for (const p of postList) {
  if (p.published) (monthly[mm(p.published)] = monthly[mm(p.published)] || {}).published = (monthly[mm(p.published)].published || 0) + 1;
  if (p.updatedOnly && p.updatedOnly !== p.published) (monthly[mm(p.updatedOnly)] = monthly[mm(p.updatedOnly)] || {}).updated = (monthly[mm(p.updatedOnly)].updated || 0) + 1;
}
for (const d of days) {
  const m = (monthly[mm(d)] = monthly[mm(d)] || {}); const x = daily[d] || {};
  m.days = (m.days || 0) + 1; m.visits = (m.visits || 0) + (x.visits || 0); m.human = (m.human || 0) + (x.human || 0);
  if (x.zone) { m.pageViews = (m.pageViews || 0) + (x.zone.pageViews || 0); m.uniquesSum = (m.uniquesSum || 0) + (x.zone.uniques || 0); m.zoneDays = (m.zoneDays || 0) + 1; }
  // ブログのページ（HTML）だけのページビュー。human はボット除外（2026-09-26 から記録・利用者のコメント wgp406ngpotuc0s7kcso）
  if (x.pv) { m.pvAll = (m.pvAll || 0) + (x.pv.all || 0); m.pvHuman = (m.pvHuman || 0) + (x.pv.human || 0); m.pvDays = (m.pvDays || 0) + 1; }
}
const monthlyRows = Object.entries(monthly).map(([month, v]) => ({ month, ...v })).sort((a, b) => b.month.localeCompare(a.month)).slice(0, 12);
const zoneDays28 = in28.filter((d) => daily[d]?.zone);
const blog = {
  posts: postList.length,
  pv28: zoneDays28.length ? zoneDays28.reduce((a, d) => a + (daily[d].zone.pageViews || 0), 0) : null,
  uuDaySum28: zoneDays28.length ? zoneDays28.reduce((a, d) => a + (daily[d].zone.uniques || 0), 0) : null,
  zoneDays28: zoneDays28.length,
  // ブログのホストの HTML の応答（＝ページビュー）。human はボット除外（2026-10-24 から積んでいる）
  pvDays28: in28.filter((d) => daily[d]?.pv).length,
  pvAll28: in28.some((d) => daily[d]?.pv) ? in28.reduce((a, d) => a + (daily[d]?.pv?.all || 0), 0) : null,
  pvHuman28: in28.some((d) => daily[d]?.pv) ? in28.reduce((a, d) => a + (daily[d]?.pv?.human || 0), 0) : null,
};
// 前の 28 日（29〜56 日前）。記録の日数が今の 28 日とそろうときだけ比べる（そろわない比較は出さない）
// 利用者のコメント（2026-10-30・blog.pv / pvh / uu / human / posts「検索クリックと同じように先月比を出して欲しい」）
{
  const zPrev = inPrev28.filter((d) => daily[d]?.zone);
  const pPrev = inPrev28.filter((d) => daily[d]?.pv);
  blog.zoneDaysPrev28 = zPrev.length;
  blog.pvDaysPrev28 = pPrev.length;
  blog.humanDays28 = in28.filter((d) => daily[d]?.human != null).length;
  blog.humanDaysPrev28 = inPrev28.filter((d) => daily[d]?.human != null).length;
  blog.pv28Prev = zPrev.length ? zPrev.reduce((a, d) => a + (daily[d].zone.pageViews || 0), 0) : null;
  blog.uuDaySum28Prev = zPrev.length ? zPrev.reduce((a, d) => a + (daily[d].zone.uniques || 0), 0) : null;
  blog.pvHuman28Prev = pPrev.length ? pPrev.reduce((a, d) => a + (daily[d].pv.human || 0), 0) : null;
  blog.pvAll28Prev = pPrev.length ? pPrev.reduce((a, d) => a + (daily[d].pv.all || 0), 0) : null;
  // 記事の数は 28 日前の時点（その日までに公開されていた本数）
  const cut = lastDay ? new Date(new Date(lastDay) - 28 * 864e5).toISOString().slice(0, 10) : null;
  blog.postsPrev = cut ? postList.filter((p) => p.published && p.published <= cut).length : null;
  blog.postsPrevAt = cut;
}

// ---------- ASP の案件（A8 以外も） ----------
const others = json(show(HB, 'reports/board/asp-probe/others.json'));

// ---------- X（Mac の書き出し：フォロワー数の推移・投稿ごとの表示回数） ----------
const xw = json(show(HB, 'reports/board/x-weekly.json'));
const reviewSets = [];
{ const src = fs.existsSync(path.join(ROOT, 'scripts/image-review/page.html')) ? fs.readFileSync(path.join(ROOT, 'scripts/image-review/page.html'), 'utf8') : '';
  const blocks = src.split(/\n\s*key:\s*"/).slice(1);   // 投稿の組ごとに切る（key から次の key まで）
  for (const b of blocks) {
    const key = b.slice(0, b.indexOf('"')); const title = (b.match(/title:\s*"([^"]+)"/) || [])[1]; const slug = (b.match(/slug:\s*"([^"]+)"/) || [])[1];
    if (!title) continue;
    const pm = b.match(/posted:\s*\[([^\]]*)\]/);   // 投稿していない組も題名の引き当てに使う（ids は空）
    const ids = pm ? [...pm[1].matchAll(/"(\d+)"/g)].map((x) => x[1]) : [];
    reviewSets.push({ key, title, slug, ids, at: ids[0] ? new Date(Number((BigInt(ids[0]) >> 22n) + 1288834974657n)).toISOString() : null });
  } }
reviewSets.sort((a, b) => (b.at || '').localeCompare(a.at || ''));
// ---------- X とブログをつなぐ：投稿ごとに「告知の日と翌日の記事の読者」と「前後のフォロワーの増減」 ----------
// フォロワーの読み取りの失敗（2026-11-02 に 626 → 3 と記録された）を外す。前後の値の半分未満に落ちて戻る点は読み違い
// 2026-11-05: 毎日の記録（follower-snapshots）は 10 月下旬から 615〜626 で止まり、11/2 に 3・11/3 に 77 と読み違えていた。
// 一方、毎朝プロフィールのヘッダーを読む x-numbers.json は 669 → 696 と伸びている（利用者「フォロワーが 11/2 で止まってる」）。
// ヘッダーの値がある日はそれを使い（読んだ時刻の UTC の日付 = 前の晩の数）、無い日だけ毎日の記録を使う。
const folHdr = {};
for (const h of (git('log', '--format=%H', '-n', '200', HB, '--', 'reports/board/x-numbers.json') || '').split('\n').filter(Boolean).reverse()) {
  const j = json(show(h, 'reports/board/x-numbers.json'));
  const n = j?.header?.followers; if (typeof n !== 'number' || n <= 0 || !j.generated) continue;
  folHdr[j.generated.slice(0, 10)] = { date: j.generated.slice(0, 10), count: n, following: j.header.following ?? null, at: j.generated, src: 'header' };
}
const folMap = {};
for (const f of (xw?.followers || []).filter((f) => typeof f.count === 'number')) folMap[f.date] = f;
for (const [d, f] of Object.entries(folHdr)) folMap[d] = f;
const folRaw = Object.values(folMap).sort((a, b) => a.date.localeCompare(b.date));
const folBad = [];
const fol = folRaw.filter((f, i) => {
  const prev = folRaw.slice(0, i).reverse().find((x) => !folBad.includes(x));
  const next = folRaw[i + 1];
  const ref = [prev?.count, next?.count].filter((n) => typeof n === 'number');
  if (ref.length && f.count < Math.min(...ref) * 0.5) { folBad.push(f); return false; }
  return true;
});
if (folBad.length) console.warn(`X: フォロワーの読み違いを外した: ${folBad.map((f) => `${f.date}=${f.count}`).join(', ')}`);
const folOn = (d) => { let v = null; for (const f of fol) { if (f.date <= d) v = f.count; else break; } return v; };
const addDays = (d, n) => iso(new Date(new Date(d + 'T00:00:00Z').getTime() + n * 864e5));
const humanOn = (slug, d) => daily[d]?.posts ? (daily[d].posts[`/posts/${slug}/`]?.human || 0) : null;
const slugOfPost = (p) => { const raw = String(p.id || ''); const s1 = raw.replace(/^blog-promo-/, '').replace(/^\d{8}-/, '').replace(/-v\d+$/, '');
  return (postList.find((x) => x.slug === s1) || postList.find((x) => raw.includes(x.slug)) || postList.find((x) => x.slug.split('-')[0] === s1.split('-')[0] && s1.split('-')[0].length > 3) || {}).slug || null; };
const xPostsJoined = (xw?.posts || []).map((p) => {
  const day = String(p.posted_at || '').slice(0, 10); const slug = slugOfPost(p);
  const r0 = slug && day ? humanOn(slug, day) : null, r1 = slug && day ? humanOn(slug, addDays(day, 1)) : null;
  const folExact = (d) => (fol.find((f) => f.date === d) || {}).count ?? null;   // 記録が抜けた日をまたぐと増減が膨らむので、その日ちょうどの記録だけ使う
  const fb = day ? folExact(addDays(day, -1)) : null, fa = day ? folExact(addDays(day, 1)) : null;
  return { tweet_id: p.tweet_id, id: p.id, day, slug, views: p.views ?? null, likes: p.likes ?? null, reposts: p.reposts ?? null, replies: p.replies ?? null,
    readers: r0 == null && r1 == null ? null : (r0 || 0) + (r1 || 0), folDelta: fb != null && fa != null ? fa - fb : null };
}).sort((a, b) => (b.views || 0) - (a.views || 0));
// 分かったこと（決まった計算だけ。推測で埋めない）
const xFacts = [];
if (xPostsJoined.length) {
  const v = xPostsJoined.map((p) => p.views || 0).sort((a, b) => a - b); const med = v[Math.floor(v.length / 2)];
  const top = xPostsJoined[0];
  xFacts.push(`記録のある自分の投稿 ${xPostsJoined.length} 本の表示は、中央値 ${med.toLocaleString()} 回。いちばん多いのは「${(posts[top.slug]?.title || top.id || '').slice(0, 24)}」の ${(top.views || 0).toLocaleString()} 回（${top.day}）。`);
  const lk = xPostsJoined.filter((p) => p.views); const lr = lk.reduce((a, p) => a + (p.likes || 0), 0) / Math.max(1, lk.reduce((a, p) => a + p.views, 0)) * 100;
  xFacts.push(`いいねは表示 100 回あたり ${lr.toFixed(1)} 件。リポストは 13 本中 ${xPostsJoined.filter((p) => p.reposts > 0).length} 本でしか付いていない。`);
  const withR = xPostsJoined.filter((p) => p.readers != null && p.views);
  if (withR.length) { const rv = withR.reduce((a, p) => a + p.readers, 0), vv = withR.reduce((a, p) => a + p.views, 0);
    xFacts.push(`告知した日と翌日に記事を読んだ人（ボット除外）は、表示 1,000 回あたり ${(rv / vv * 1000).toFixed(1)} 人（読者の記録がある ${withR.length} 本の合計：表示 ${vv.toLocaleString()} 回 → 読者 ${rv} 人）。X の表示がそのまま記事の読者にはなっていない。`); }
  const withF = xPostsJoined.filter((p) => p.folDelta != null);
  if (withF.length) { const best = [...withF].sort((a, b) => b.folDelta - a.folDelta)[0];
    xFacts.push(`投稿の前日から翌日までのフォロワーの増減（前日と翌日の記録がそろう ${withF.length} 本）は、最大で ${best.folDelta >= 0 ? '+' : ''}${best.folDelta}（「${(posts[best.slug]?.title || best.id || '').slice(0, 20)}」の ${best.day}）。平均は ${(withF.reduce((a, p) => a + p.folDelta, 0) / withF.length).toFixed(1)}。`); }
}
if (fol.length > 14) {
  const last = fol[fol.length - 1]; const wk = fol.filter((f) => f.date > addDays(last.date, -7)); const pw = fol.filter((f) => f.date > addDays(last.date, -14) && f.date <= addDays(last.date, -7));
  const g1 = wk.length ? last.count - (folOn(addDays(last.date, -7)) ?? wk[0].count) : null, g0 = pw.length ? (folOn(addDays(last.date, -7)) ?? 0) - (folOn(addDays(last.date, -14)) ?? pw[0].count) : null;
  if (g1 != null && g0 != null) xFacts.push(`フォロワーは直近 7 日で ${g1 >= 0 ? '+' : ''}${g1}、その前の 7 日で ${g0 >= 0 ? '+' : ''}${g0}（${last.date} 時点 ${last.count} 人）。`);
}

const xData = { generated: xw?.generated || null, joined: xPostsJoined, facts: xFacts, followers: fol, posts: xw?.posts || [], keys: xw?.keys || null, reviewSets };

// ---------- X の数字 ----------
// **2026-10-19 まで、ここは docs/growth-strategy.md の手書きの表（10/12）だけを読んでいた。** 誰も更新せず、
// フォロワー 345 のまま 1 週間出し続け、利用者に「全然最新じゃない」と指摘された（実数は 10/18 で 507）。
// いまは Mac が毎日 6:40 に X の画面から読む reports/board/x-numbers.json（x-numbers.js）を先に使い、
// 手書きの表は、自動で取れない項目の補いにだけ使う。
const gs = fs.existsSync(path.join(ROOT, 'docs/growth-strategy.md')) ? fs.readFileSync(path.join(ROOT, 'docs/growth-strategy.md'), 'utf8') : '';
const xManual = ((gs.split('## 共有の数字')[1] || '').split('\n## ')[0] || '').split('\n')
  .filter((l) => /^\|/.test(l) && !/^\|\s*-/.test(l) && !/^\|\s*指標/.test(l))
  .map((l) => l.split('|').slice(1, -1).map((c) => c.trim().replace(/\*\*/g, '').replace(/`/g, '')))
  .filter((c) => c.length >= 4).map(([k, v, at, src]) => ({ k, v, at, src: src + '（手書き）' }));
// 読めなかった日のファイル（全部 null）は使わず、履歴をさかのぼって最後に読めたものを使う（2026-10-22）
let xNum = json(show(HB, 'reports/board/x-numbers.json'));
if (xNum && !xNum.header?.followers) {
  const revs = (git('log', '--format=%H', '-n', '15', HB, '--', 'reports/board/x-numbers.json') || '').split('\n').filter(Boolean);
  const good = revs.map((h) => json(show(h, 'reports/board/x-numbers.json'))).find((j) => j?.header?.followers);
  if (good) xNum = { ...good, fallbackFrom: xNum.generated };
}
const jst = (t) => t ? new Date(new Date(t).getTime() + 9 * 3600e3).toISOString().slice(0, 16).replace('T', ' ') : '';
const kfmt = (n) => n == null ? null : n >= 10000 ? (n / 1000).toFixed(1).replace(/\.0$/, '') + 'K' : n.toLocaleString();
const xAuto = [];
if (xNum?.header?.followers) {
  const at = jst(xNum.generated), h = xNum.header, d7 = xNum.d7 || {}, d90 = xNum.d90 || {}, ocr = xNum.ocr || {};
  const add = (k, v, src) => { if (v != null && v !== '') xAuto.push({ k, v: String(v), at, src: src + '（Mac が毎日読む）' }); };
  add('フォロワー', h.followers.toLocaleString(), 'プロフィールのヘッダー');
  add('フォロー中', h.following != null ? `${h.following.toLocaleString()}（比率 ${(h.following / h.followers).toFixed(3)}）` : null, 'プロフィールのヘッダー');
  const vf = ocr.verifiedFollowers ?? d7.verifiedFollowers;
  add('認証済みフォロワー', vf != null ? `${vf.toLocaleString()} / 500（収益化の条件）` : null, '収益化の条件の画面');
  add('インプレッション（7 日）', kfmt(d7.impressions), 'アナリティクス 7D。返信を含む全体');
  add('プロフィールへのアクセス（7 日）', kfmt(d7.profileVisits), 'アナリティクス 7D');
  add('インプレッション（90 日）', kfmt(d90.impressions), 'アナリティクス 3M。返信を含む全体');
  add('プロフィールへのアクセス（90 日）', kfmt(d90.profileVisits), 'アナリティクス 3M');
  add('オリジナルコンテンツ報酬', ocr.eligible === false ? '対象外' : ocr.eligible === true ? '対象' : null, '収益化の条件の画面');
  add('認証済みインプレッション（90 日・ホーム・返信除く）', ocr.verifiedImpressions90 != null ? `${ocr.verifiedImpressions90.toLocaleString()} / 50万（収益化の条件）` : null, '収益化の条件の画面');
}
const xAutoKeys = new Set(xAuto.map((r) => r.k.replace(/（[^）]*）/g, '')));
const xShared = [...xAuto, ...xManual.filter((r) => !xAutoKeys.has(r.k.replace(/（[^）]*）/g, '')) && !/ブログ Google 検索クリック/.test(r.k))];

// ---------- ASP ----------
const a8 = json(show(HB, 'reports/board/asp-probe/a8partnered.json'));
const aspStatus = json(show(HB, 'reports/asp-sync/status.json'));
const macWeekly = json(show(HB, 'reports/board/mac-weekly-status.json'));
const manual = json(fs.existsSync(path.join(ROOT, 'ops/data/board/manual.json')) ? fs.readFileSync(path.join(ROOT, 'ops/data/board/manual.json'), 'utf8') : null) || {};
const yen = (s) => { const m = (s || '').replace(/,/g, '').match(/(\d{3,6})円/); return m ? +m[1] : null; };
const NG_PROGRAM = /チャットレディ|ライブチャット|出会い|アダルト|風俗/;
const affInv = buildInventory();
// 案件ごとに、どの記事に入っているか（2026-10-24・利用者のコメント「どの記事に案件名を入れているかの対応表」）。
// 記事側の名前は短い（「OZmall」）が、A8 の案件名は長い（「…東京女子に人気【OZmall】」）。
// 【】の中が一致するもの、なければ名前を含む案件が 1 つだけのものに結びつける。迷うものは結びつけない（下の affByItem には全部出る）。
const affByItem = {};
for (const a of affInv) for (const it of a.items) {
  const k = it.asp + '\u0000' + it.item;
  (affByItem[k] = affByItem[k] || { asp: it.asp, item: it.item, n: 0, articles: [] });
  affByItem[k].n += it.n; affByItem[k].articles.push({ slug: a.slug, n: it.n });   // 題名は affInventory から引く（db の 1 文書 256KB の上限に収める）
}
const normName = (x) => (x || '').replace(/[\s　・｜|（）()【】\[\]!！+＋]/g, '').toLowerCase();
const a8Articles = {};
for (const v of Object.values(affByItem)) {
  if (v.asp !== 'A8') continue;
  const ni = normName(v.item);
  const rows = a8?.rows || [];
  let hit = rows.filter((r) => [...(r.name || '').matchAll(/【([^】]+)】/g)].some((m) => normName(m[1]) === ni));
  if (hit.length !== 1) { const c = rows.filter((r) => normName(r.name).includes(ni) || ni.includes(normName(r.name))); hit = c.length === 1 ? c : []; }
  if (hit.length === 1) (a8Articles[hit[0].id] = a8Articles[hit[0].id] || []).push(...v.articles);
}
// 2026-10-31: A8 の提携中が 310 件になり、作戦室の db の 1 文書の上限（256KB）に近づいた。名前・報酬を短くし、false と空の配列は書かない
// 2026-11-03: 313 件で 279KB になり上限を超えた。作戦室が使っていない listing を落とし、yen が無いものは書かない
const a8Rows = (a8?.rows || []).map((r) => { const o = { id: r.id, name: (r.name || '').slice(0, 50), reward: (r.reward || '').replace(/\s*EPC$/, '').slice(0, 60) };
  const y = yen(r.reward); if (y != null) o.yen = y;
  if (r.self) o.self = true; if (NG_PROGRAM.test(r.name || '')) o.ng = true; if ((a8Articles[r.id] || []).length) o.articles = a8Articles[r.id]; return o; });

// ---------- 所見（決まった条件に当たったものだけ） ----------
if (gsc) xShared.push({ k: 'ブログ Google 検索クリック（28 日）', v: String(gscCur.clicks), at: `${gscCur.from}〜${gscCur.to}`, src: 'Search Console（Mac が毎日読む）' });
const findings = [];
const pct = (a, b) => (b ? Math.round((a - b) / b * 100) : null);
const push = (level, key, text) => findings.push({ level, key, text });
if (gsc) {
  const dc = pct(gscCur.clicks, gscPrev.clicks), di = pct(gscCur.impressions, gscPrev.impressions);
  push(di != null && di < -15 ? 'warn' : 'info', 'gsc-trend', `検索の表示は ${gscCur.impressions.toLocaleString()} 回（前の期間比 ${di == null ? '—' : (di > 0 ? '+' : '') + di + '%'}）、クリックは ${gscCur.clicks} 回（${dc == null ? '—' : (dc > 0 ? '+' : '') + dc + '%'}）。期間 ${gscCur.from}〜${gscCur.to}。`);
  const titleCands = pos4to10.filter((r) => r.i >= 20 && r.c / r.i < 0.03).sort((a, b) => b.i - a.i).slice(0, 5);
  if (titleCands.length) push('action', 'ctr', `4〜10 位にいてクリック率 3% 未満の記事が ${titleCands.length} 本：${titleCands.map((r) => `「${posts[r.slug]?.title?.slice(0, 24) || r.slug}」（${r.i} 回・${r.p.toFixed(1)} 位）`).join('、')}。タイトルと説明文の直し候補。`);
}
const gaps = readTop.filter((r) => r.aff === 0).slice(0, 8);
if (gaps.length) push('action', 'gaps', `直近 28 日に読まれた上位 20 本のうち ${readTop.filter((r) => r.aff === 0).length} 本は成果リンクが 0。上から：${gaps.slice(0, 5).map((r) => `「${r.title.slice(0, 22)}」`).join('、')}。`);
const readers = (r) => (r.h28 != null ? r.h28 : r.v28);
const nonSearch = articles.filter((r) => readers(r) >= 10 && r.c28 / readers(r) < 0.2).sort((a, b) => readers(b) - readers(a)).slice(0, 5);
if (nonSearch.length) push('info', 'non-search', `検索のクリックが読者の 2 割未満なのに読まれている記事が ${nonSearch.length} 本：${nonSearch.map((r) => `「${r.title.slice(0, 20)}」（${r.h28 != null ? '読者' : '訪問'} ${readers(r)}・検索クリック ${r.c28}）`).join('、')}。${refDays28.length ? '読者はボットを除いた数。X か直接か等の内訳は Web Analytics の有効化待ち。' : '訪問はボットを含む数。'}`);
const ngs = a8Rows.filter((r) => r.ng);
if (ngs.length) push('warn', 'ng-program', `A8 の提携中に、ブログの読者層と合わない案件が ${ngs.length} 件（${ngs.map((r) => r.name.slice(0, 20)).join('、')}）。記事には使わない。`);
// **毎日取るものが 2 日以上古ければ鳴らす**（2026-10-19。週 1 だった頃の「9 日」のままで、10/12 から止まっていても鳴らなかった）
// 読者データ（Cloudflare）は前日分が翌朝に入るので、2 日前までは正常。3 日で鳴らす
const staleness = [['検索データ', gsc?.generated, 2], ['A8 の一覧', a8?.generated, 2], ['X の数字', xNum?.generated, 2], ['読者データ', lastDay, 3]]
  .map(([n, t, lim]) => [n, t, t ? daysAgo(t) : null, lim]).filter(([, t, d, lim]) => !t || d >= lim);
if (staleness.length) push('warn', 'stale', `古いデータ：${staleness.map(([n, , d]) => d == null ? `${n}（届いていない）` : `${n}（${d} 日前）`).join('、')}。Mac の毎日のジョブ（com.dailyhack.board-weekly・6:40）が動いているかを確かめる。**この所見が出ている日は「数字を更新した」と報告しない。**`);
if (xNum?.fallbackFrom) push('warn', 'x-fallback', `今朝は X の数字を読めなかった（${jst(xNum.fallbackFrom)}）。作戦室の X の数字は ${jst(xNum.generated)} に読んだもの。**この所見が出ている日は X の数字を「更新した」と報告しない。**`);
if (!a8) push('warn', 'a8-missing', 'A8 の提携一覧がまだ届いていない（Mac の週次ジョブの初回待ち）。');
for (const p of manual.pending || []) if (p.since && daysAgo(p.since) > 21) push('info', 'pending-' + p.key, `${p.label} は申請から ${daysAgo(p.since)} 日。審査の状況を確かめる。`);

// ---------- 全体像（トップ）のカレンダー・判断待ち・止まっているデータ（2026-11-19 利用者「作戦室のトップに X とブログとアフィリエイトのサマリや投稿予定カレンダー、その他サマリーで知るべき情報を」）----------
// どれもリポジトリと ops/heartbeat から読むだけ（LLM 不使用・Mac のジョブも増やさない）。取れないものは null にして、作戦室は「データ待ち」と出す
const jstToday = iso(new Date(today.getTime() + 9 * 3600e3));
const homeEnd = iso(new Date(new Date(jstToday + 'T00:00:00Z').getTime() + 13 * 864e5));
const blogPlan = [], events = [];
for (const f of fs.readdirSync(POSTS_DIR).filter((x) => x.endsWith('.md'))) {
  const src = fs.readFileSync(path.join(POSTS_DIR, f), 'utf8');
  const fm = (src.match(/^---\n([\s\S]*?)\n---/) || [])[1] || '';
  const get = (k) => ((fm.match(new RegExp(`^${k}:\\s*"?(.*?)"?\\s*$`, 'm')) || [])[1] || '').trim();
  const slug = f.replace(/\.md$/, ''), title = get('title').split('｜')[0].slice(0, 60), pub = get('publishDate').slice(0, 10), draft = get('draft') === 'true';
  if (draft) blogPlan.push({ slug, title, date: pub >= jstToday ? pub : null, state: 'draft' });
  else if (pub > jstToday) blogPlan.push({ slug, title, date: pub, state: 'scheduled' });
  const ev = (fm.match(/^event:\n((?:[ \t]+.*\n?)+)/m) || [])[1];
  if (ev) {
    const eg = (k) => ((ev.match(new RegExp(`^\\s+${k}:\\s*"?(.*?)"?\\s*$`, 'm')) || [])[1] || '').trim();
    const s = eg('startDate').slice(0, 10), e = (eg('endDate') || eg('startDate')).slice(0, 10);
    if (s && s <= homeEnd && e >= jstToday) events.push({ slug, name: eg('name').slice(0, 60), start: s, end: e, draft });
  }
}
events.sort((a, b) => a.start.localeCompare(b.start));
// X の予約・キュー（tweet2 が reports/board/x-schedule.json に書き出す。形は依頼表 2026-11-19 affiliate → tweet2 の案 { generated, posts: [{ id, scheduled_at, kind, slug, text, status }] }。まだ無ければ null）
const xSchedRaw = json(show(HB, 'reports/board/x-schedule.json'));
const xSchedule = xSchedRaw ? { generated: xSchedRaw.generated || xSchedRaw.generatedAt || null, items: (Array.isArray(xSchedRaw) ? xSchedRaw : (xSchedRaw.posts || xSchedRaw.items || xSchedRaw.schedule || [])).slice(0, 60) } : null;
// 依頼表の「未対応」「対応中」を宛先ごとに数える（blog2 は blog3 に数える）
const reqText = fs.existsSync(path.join(ROOT, 'docs/cross-session-requests.md')) ? fs.readFileSync(path.join(ROOT, 'docs/cross-session-requests.md'), 'utf8') : '';
const reqOpen = { blog3: 0, tweet2: 0, affiliate: 0 }, reqNew = { blog3: 0, tweet2: 0, affiliate: 0 };
for (const l of reqText.split('\n')) {
  const c = l.split('|').map((x) => x.trim()); if (!/^20\d\d-\d\d-\d\d$/.test(c[1] || '')) continue;
  if (!/^\**(未対応|対応中)/.test(c[4] || '')) continue;
  const to = ((c[2] || '').split('→')[1] || '').replace(/blog2/g, 'blog3');
  for (const k of Object.keys(reqOpen)) if (to.includes(k)) { reqOpen[k]++; if (daysAgo(c[1]) <= 7) reqNew[k]++; }
}
// マージ待ちの PR（gh が使えるときだけ。使えなければ null で、作戦室は「データ待ち」）
let openPRs = null;
try {
  const out = execFileSync('gh', ['api', 'repos/Yokottinnn/daily-hack/pulls?state=open&per_page=100', '--jq', '[.[]|{n:.number,t:.title,at:.created_at,draft:.draft}]'], { encoding: 'utf8', timeout: 20000, stdio: ['ignore', 'pipe', 'ignore'] });
  openPRs = JSON.parse(out).map((p) => ({ ...p, t: String(p.t).slice(0, 80), age: daysAgo(p.at) }));
} catch { openPRs = null; }
// 止まっているデータ（毎日届くはずのものの日付。lim 日以上前なら止まっている）
const staleList = [
  ['ASP の提携状況（asp-sync）', aspStatus?.generated, 2],
  ['X の数字', xNum?.generated, 2],
  ['検索データ（Search Console）', gsc?.generated, 2],
  ['A8 の提携一覧', a8?.generated, 2],
  ['読者データ（Cloudflare）', lastDay, 3],
].map(([name, at, lim]) => ({ name, at: at || null, days: at ? daysAgo(at) : null, lim }));
const macFail = macWeekly ? Object.entries(macWeekly).filter(([, v]) => v && typeof v === 'object' && v.ok === false).map(([k]) => k) : [];
// 止まっているもの（2026-11-23 決定ログ「鍵・認証情報・ログインが足りずに止まっているものは、見つけた日のうちに利用者へ伝える。作戦室のトップに一覧を出す」）
// 1 行 = { key, what（何が止まっているか）, impact（記事や作戦室にどう響くか）, fix（利用者にしてもらうこと・分かるものだけ。無ければ null）, status（いまの対応）, since, src }
// fix・status は推測で書かない。データから言えないものは ops/data/board/manual.json の blocked[key] に、分かったセッションが書く（null のときは作戦室が「まだ分かっていない」と出す）
const hoursAgo = (s) => s ? Math.round((today - new Date(s)) / 36e5) : null;
const blocked = [];
// manual.blocked[key].until（YYYY-MM-DD）を書いた説明は、その日を過ぎたら使わない（同じ key が別の理由でまた止まったとき、古い説明を出さないため）
const blockedNote = (k) => { const m = (manual.blocked || {})[k]; return m && typeof m === 'object' && !(m.until && m.until < jstToday) ? m : null; };
const addBlocked = (o) => { const m = blockedNote(o.key) || {}; blocked.push({ fix: null, status: null, since: null, ...o, ...(m.fix ? { fix: m.fix } : {}), ...(m.status ? { status: m.status } : {}), ...(m.since ? { since: m.since } : {}) }); };
// ① 3 店ボタンの価格（reports/board/shop-prices.json：keys・series の skipped/error・errors・generatedAt）
const shopPrices = json(show(HB, 'reports/board/shop-prices.json'));
if (shopPrices) {
  const cells = Object.values(shopPrices.series || {}).flatMap((s) => Object.values(s || {})).flatMap((r) => Object.entries(r || {}));
  const byReason = {};
  for (const [store, v] of cells) if (v && (v.skipped || v.error)) { const k = store + '\u0000' + (v.skipped ? 'skipped' : 'error') + '\u0000' + String(v.skipped || v.error).slice(0, 80); byReason[k] = (byReason[k] || 0) + 1; }
  const perStore = (st) => cells.filter(([s]) => s === st).length;
  const STORE = { rakuten: '楽天市場', yahoo: 'Yahoo!ショッピング' };
  for (const [k, n] of Object.entries(byReason)) {
    const [store, kind, reason] = k.split('\u0000');
    const keyMissing = /ACCESS_KEY|APP_ID|鍵|key/i.test(reason) && kind === 'skipped';
    addBlocked({ key: `shop-${store}-${keyMissing ? 'key' : kind}`, kind: keyMissing ? 'key' : kind,
      what: `3 店ボタンの${STORE[store] || store}の価格（${kind === 'skipped' ? '飛ばした' : '失敗'}：${reason}）`,
      impact: `${n === perStore(store) ? '全 ' + n + ' 件' : perStore(store) + ' 件中 ' + n + ' 件'}の価格が取れていない。記事の比較表・商品カードで${STORE[store] || store}の欄が「価格はリンク先で」になり、「いちばん安い」の比べ合いに入らない`,
      since: null, src: `reports/board/shop-prices.json（${jst(shopPrices.generatedAt)} に取ったもの）` });
  }
  if ((shopPrices.errors || []).length) addBlocked({ key: 'shop-errors', kind: 'error', what: `3 店ボタンの価格の取得でエラー ${shopPrices.errors.length} 件`, impact: '該当する商品の価格が前回のまま', src: 'reports/board/shop-prices.json の errors' });
  const h = hoursAgo(shopPrices.generatedAt);
  if (h == null || h >= 24) addBlocked({ key: 'shop-stale', kind: 'stale', what: `3 店ボタンの価格が ${h == null ? '日付不明' : Math.floor(h / 24) + ' 日前（' + jst(shopPrices.generatedAt) + '）'}のまま${macFail.includes('shop') ? '（今朝の Mac のジョブでも失敗）' : ''}`, impact: '記事の 3 店ボタンの価格（楽天・Yahoo!）がその日の値のまま。毎朝の取り直しが入っていない', src: 'reports/board/shop-prices.json の generatedAt・mac-weekly-status.json の shop' });
}
// ② 毎朝の Mac のジョブ（mac-weekly-status.json の ok=false）
const MACW = { gsc: ['Search Console の数字', '作戦室の検索の数字が前の日のまま'], a8_partnered: ['A8 の提携一覧', '作戦室の「ASP と案件」が前の日のまま'], others: ['ほかの ASP の一覧', '作戦室の ASP の一覧が前の日のまま'], x: ['X の投稿の記録', '作戦室の X の表が前の日のまま'], x_numbers: ['X の数字', '全体像の X の帯が前の日のまま'], shop: ['3 店ボタンの価格', '記事の 3 店ボタンの価格が前の日のまま'], asp_results: ['ASP の成果', '全体像のアフィリエイトの帯が前の日のまま'] };
for (const k of macFail) if (!(k === 'shop' && blocked.some((b) => b.key === 'shop-stale'))) addBlocked({ key: 'macweekly-' + k, kind: 'job', what: `今朝の Mac のジョブで失敗：${(MACW[k] || [k])[0]}`, impact: (MACW[k] || [, '該当する数字が前の日のまま'])[1], src: `reports/board/mac-weekly-status.json（${jst(macWeekly.generated)}）` });
// ③ ASP のログイン（reports/asp-sync/status.json の providers：loggedIn=false か needsHuman=true）と、その古さ
const ASPN = { a8: 'A8.net', moshimo: 'もしもアフィリエイト', vc: 'バリューコマース', rakuten: '楽天アフィリエイト' };
if (aspStatus) {
  for (const [k, v] of Object.entries(aspStatus.providers || {})) if (v && (v.loggedIn === false || v.needsHuman === true))
    addBlocked({ key: 'asp-login-' + k, kind: 'login', what: `${v.name || ASPN[k] || k} に自動でログインできていない${v.reason ? '（' + String(v.reason).slice(0, 100) + '）' : ''}`, impact: '提携状況・成果の数字がその ASP の分だけ前のまま', src: 'reports/asp-sync/status.json' });
  const h = hoursAgo(aspStatus.generated);
  if (h == null || h >= 24) addBlocked({ key: 'asp-sync-stale', kind: 'stale', what: `ASP の提携状況（asp-sync）が ${h == null ? '日付不明' : Math.floor(h / 24) + ' 日前（' + jst(aspStatus.generated) + '）'}のまま`, impact: '作戦室の提携状況・ログインの状態が古い', src: 'reports/asp-sync/status.json の generated' });
} else addBlocked({ key: 'asp-sync-missing', kind: 'stale', what: 'ASP の提携状況（asp-sync）の status.json が届いていない', impact: '各 ASP のログインの状態が分からない', src: 'reports/asp-sync/status.json' });
// ④ ASP の成果（db の results/latest：note にログイン・認証の失敗が書かれた行と、古さ）。--results で受け取る（無ければ見ない）
const resultsDoc = (() => { try { const j = args.results ? JSON.parse(fs.readFileSync(args.results, 'utf8')) : null; return j && (j.data || j); } catch { return null; } })();
if (resultsDoc) {
  for (const r of resultsDoc.rows || []) if (/ログイン|認証|2段階|二段階|パスワード|再ログイン|login|captcha/i.test(r.note || '') && /切れ|でき(ない|なかった)|失敗|必要|要る|求め|止ま|expired|fail/i.test(r.note || ''))
    addBlocked({ key: 'results-login-' + String(r.asp).replace(/[^A-Za-z0-9]/g, '').toLowerCase().slice(0, 20), kind: 'login', what: `${r.asp} の成果を読めていない（${String(r.note).slice(0, 120)}）`, impact: '全体像のアフィリエイトの帯で、この ASP の数字が前のまま', src: 'db の results/latest の note' });
  const h = hoursAgo(resultsDoc.generatedAt);
  if (h == null || h >= 36) addBlocked({ key: 'results-stale', kind: 'stale', what: `ASP の成果（results/latest）が ${h == null ? '日付不明' : Math.floor(h / 24) + ' 日前（' + jst(resultsDoc.generatedAt) + '）'}のまま`, impact: '全体像のアフィリエイトの帯が古い', src: 'db の results/latest の generatedAt' });
}
// ⑤ manual.json の blocked のうち、データからは見えないもの（自動の行に当たらなかった key）も出す（what が書いてあるものだけ）
for (const k of Object.keys(manual.blocked || {})) { const m = blockedNote(k); if (m && m.what && !blocked.some((b) => b.key === k)) blocked.push({ key: k, kind: m.kind || 'manual', what: m.what, impact: m.impact || null, fix: m.fix || null, status: m.status || null, since: m.since || null, src: m.src || 'ops/data/board/manual.json の blocked' }); }
const home = { today: jstToday, end: homeEnd, blogPlan, events, xSchedule, requests: { open: reqOpen, new7: reqNew }, openPRs, stale: staleList, macFail, deadlines: manual.deadlines || [], blocked, blockedChecked: new Date().toISOString() };

const snapshot = {
  generatedAt: new Date().toISOString(),
  sources: {
    gsc: gsc ? { file: gscFile, generated: gsc.generated, window: [gscCur.from, gscCur.to] } : null,
    pv: lastDay ? { branch: 'ops/pv-archive', lastDay, days28: in28.length } : null,
    a8: a8 ? { file: 'reports/board/asp-probe/a8partnered.json', generated: a8.generated } : null,
    aspSync: aspStatus ? { generated: aspStatus.generated, pushed: lastTouched(HB, 'reports/asp-sync/status.json') } : null,
    macWeekly,
    xNumbers: xNum ? { file: 'reports/board/x-numbers.json', generated: xNum.generated, error: xNum.error || null } : null,
  },
  kpi: {
    gsc28: gscCur, gscPrev28: gscPrev, gsc90: gsc90,
    pv28: { visits: pvSum(in28, 'visits'), human: pvSum(in28, 'human'), jp: pvSum(in28, 'jp') },
    pvPrev28: { visits: pvSum(inPrev28, 'visits'), human: pvSum(inPrev28, 'human'), jp: pvSum(inPrev28, 'jp') },
    posts: { total: postList.length, isPR: postList.filter((p) => p.isPR).length, withAff: postList.filter((p) => p.aff > 0).length },
    pos4to10: { pages: pos4to10.length, impressions: sum(pos4to10, 'i') },
  },
  gscWeekly, gscMonthly, topPages, queries, pq, readTop, pagesTop, pagesMeta, articles, pvMeta, xShared, monthly: monthlyRows, blog, others, xData,
  a8: a8 ? { total: a8.total, rows: a8Rows, applyingCount: a8.applyingCount ?? null, generated: a8.generated } : null,
  // 記事ごとの成果リンクの一覧（2026-10-17・利用者の指示）
  affInventory: affInv,
  affByItem: Object.values(affByItem).sort((x, y) => y.articles.length - x.articles.length || y.n - x.n),
  manual,
  findings,
  home,
};
// 2026-11-03: A8 の提携中の一覧は別の文書（snapshot/a8）に分けて持つ。1 文書 256KB の上限を超えたため。
// 作戦室（board.html）は snapshot/latest と snapshot/a8 の両方を読み、a8.rows を戻してから描く
const OUT_A8 = OUT.replace(/\.json$/, '') + '.a8.json';
const a8Doc = { generated: snapshot.a8?.generated ?? null, rows: snapshot.a8?.rows ?? [] };
if (snapshot.a8) { snapshot.a8 = { ...snapshot.a8, rowsDoc: 'snapshot/a8' }; delete snapshot.a8.rows; }
// 2026-11-07: snapshot/latest が 214KB（日本語を \u で数えると 283KB）になり、利用者の作戦室で読み込まれなくなった（「データ：読み込み中」のまま）。
// 記事の一覧を snapshot/arts、成果リンクの一覧を snapshot/aff に分ける（それぞれ 10 万バイト以下）。作戦室は 4 つを読んで合わせて描く
// 2026-11-17: snapshot/aff が日本語を \u で数えて 240KB（上限 256KB の 9 割超）になったので、案件ごとの集計（affByItem）を snapshot/affitem に分けた
const OUT_ARTS = OUT.replace(/\.json$/, '') + '.arts.json', OUT_AFF = OUT.replace(/\.json$/, '') + '.aff.json', OUT_AFFI = OUT.replace(/\.json$/, '') + '.affitem.json';
const artsDoc = { generated: snapshot.generatedAt, articles: snapshot.articles };
// 2026-11-23: 11/22〜23 に比較記事が 20 本以上増え、snapshot/aff が日本語を \u で数えて 295KB（上限 256KB 超）、affitem も 261KB になった。
// どちらも前半・後半の 2 文書に分ける（aff + aff2 の affInventoryB、affitem + affitem2 の affByItemB）。作戦室は前半と後半をつないで描く
// 件数ではなく大きさ（日本語を \u で数えた長さ）で半分に分ける。記事によって成果リンクの数が大きく違うため
const half = (a) => { const arr = a || []; const sz = arr.map((x) => JSON.stringify(x).replace(/[\u0080-\uffff]/g, '______').length); const tot = sz.reduce((p, c) => p + c, 0); let acc = 0, m = 0; while (m < arr.length && acc + sz[m] <= tot / 2) acc += sz[m++]; return [arr.slice(0, m), arr.slice(m)]; };
const [affA, affB] = half(snapshot.affInventory), [itemA, itemB] = half(snapshot.affByItem);
const affDoc = { generated: snapshot.generatedAt, affInventory: affA };
const aff2Doc = { generated: snapshot.generatedAt, affInventoryB: affB };
const affiDoc = { generated: snapshot.generatedAt, affByItem: itemA };
const affi2Doc = { generated: snapshot.generatedAt, affByItemB: itemB };
for (const k of ['articles', 'affInventory', 'affByItem']) delete snapshot[k];
snapshot.splitDocs = ['snapshot/a8', 'snapshot/arts', 'snapshot/aff', 'snapshot/aff2', 'snapshot/affitem', 'snapshot/affitem2'];
const OUT_AFF2 = OUT.replace(/\.json$/, '') + '.aff2.json', OUT_AFFI2 = OUT.replace(/\.json$/, '') + '.affitem2.json';
fs.writeFileSync(OUT, JSON.stringify(snapshot, null, 1));
fs.writeFileSync(OUT_A8, JSON.stringify(a8Doc, null, 1));
fs.writeFileSync(OUT_ARTS, JSON.stringify(artsDoc, null, 1));
fs.writeFileSync(OUT_AFF, JSON.stringify(affDoc, null, 1));
fs.writeFileSync(OUT_AFFI, JSON.stringify(affiDoc, null, 1));
fs.writeFileSync(OUT_AFF2, JSON.stringify(aff2Doc, null, 1));
fs.writeFileSync(OUT_AFFI2, JSON.stringify(affi2Doc, null, 1));
// 2026-11-19: 全体像の「前週・前月との差」用の日ごとの記録（db の snapshot/hist）。前日までの記録を --hist で受け取り、今日の 1 行を足す
const OUT_HIST = OUT.replace(/\.json$/, '') + '.hist.json';
if (args.hist) {
  const rd = (f) => { try { const j = JSON.parse(fs.readFileSync(f, 'utf8')); return j.data || j; } catch { return null; } };
  const hist = addDay(rd(args.hist) || { days: {} }, jstDate(snapshot.generatedAt), entryOf(snapshot, args.results ? rd(args.results) : null));
  fs.writeFileSync(OUT_HIST, JSON.stringify(hist, null, 1));
  JSON.parse(fs.readFileSync(OUT_HIST, 'utf8'));
  console.log(`hist: ${OUT_HIST} days=${Object.keys(hist.days).length}`);
}
for (const f of [OUT, OUT_A8, OUT_ARTS, OUT_AFF, OUT_AFFI, OUT_AFF2, OUT_AFFI2]) JSON.parse(fs.readFileSync(f, 'utf8')); // 書いたものを読み直す（最上位ルール 13）
for (const [f, lim] of [[OUT, 262144], [OUT_A8, 262144], [OUT_ARTS, 262144], [OUT_AFF, 262144], [OUT_AFFI, 262144], [OUT_AFF2, 262144], [OUT_AFFI2, 262144]]) { const s = JSON.stringify(JSON.parse(fs.readFileSync(f, 'utf8'))); const b = Buffer.byteLength(s), e = s.replace(/[\u0080-\uffff]/g, '______').length; if (b > lim * 0.9 || e > lim * 0.9) console.error(`警告: ${f} が ${b} バイト（日本語を \\u で数えると ${e}・上限 ${lim} の 9 割を超えた）`); }
console.log(`snapshot: ${OUT} + ${OUT_A8} + ${OUT_ARTS} + ${OUT_AFF} + ${OUT_AFF2} + ${OUT_AFFI} + ${OUT_AFFI2}  gsc=${!!gsc}(${gscFile}) pv=${lastDay} a8=${a8 ? a8Rows.length : 0} findings=${findings.length}`);
