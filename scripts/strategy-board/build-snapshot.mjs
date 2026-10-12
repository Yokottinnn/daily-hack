#!/usr/bin/env node
// 収益化作戦室（https://claude.ai/artifact/9KWGybrAHF7LtbQdVpw9YN）に載せる数字と所見を、手元の一次データから作る。
// LLM 不使用・$0。毎週のルーティン（docs/strategy-board-routine.md）がクラウドで走らせ、
// 出力の JSON を ArtifactData でサイトの db（snapshot/latest と snapshots/<日付>）に書く。
//
//   node scripts/strategy-board/build-snapshot.mjs --out /tmp/snapshot.json
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
  posts[slug] = { slug, title: get('title'), isPR: get('isPR') === 'true', updated: get('updatedDate') || get('publishDate'), aff: (src.match(AFF) || []).length };
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
// 日ごとの表示・クリックを週にまとめる（推移グラフ用）
const weekly = {};
for (const r of gsc?.data?.dates_90d || []) {
  const d = new Date(r.keys[0]); const monday = new Date(d); monday.setDate(d.getDate() - ((d.getDay() + 6) % 7));
  const k = iso(monday); weekly[k] = weekly[k] || { week: k, clicks: 0, impressions: 0, days: 0 };
  weekly[k].clicks += r.c; weekly[k].impressions += r.i; weekly[k].days++;
}
const gscWeekly = Object.values(weekly).sort((a, b) => a.week.localeCompare(b.week));

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
  slug: p.slug, title: p.title, aff: p.aff, isPR: p.isPR, updated: p.updated,
  c28: pagesCur[p.slug]?.c || 0, i28: pagesCur[p.slug]?.i || 0, p28: pagesCur[p.slug]?.p ?? null,
  c90: pages90m[p.slug]?.c || 0, i90: pages90m[p.slug]?.i || 0, p90: pages90m[p.slug]?.p ?? null,
  v28: v28[p.slug] || 0, v90: v90[p.slug] || 0,
  h28: refDays28.length ? (human28[p.slug] || 0) : null,
  refs28: refDays28.length ? groupRefs(refs28[p.slug]) : null,
})).sort((a, b) => b.v28 - a.v28 || b.i90 - a.i90);
for (const r of topPages) r.v90 = v90[r.slug] || 0;
for (const r of readTop) { r.c28 = pagesCur[r.slug]?.c || 0; r.h28 = refDays28.length ? (human28[r.slug] || 0) : null; r.refs28 = refDays28.length ? groupRefs(refs28[r.slug]) : null; }
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
const pvMeta = { first: days[0] || null, last: lastDay, days90: in90.length, refFrom: days.find((d) => daily[d]?.posts) || null, refDays28: refDays28.length, spikeDays, seriesFrom: recentDays[0] || null };

// ---------- X の数字（共通戦略の「共有の数字」から。tweet2 が一次情報で更新している） ----------
const gs = fs.existsSync(path.join(ROOT, 'docs/growth-strategy.md')) ? fs.readFileSync(path.join(ROOT, 'docs/growth-strategy.md'), 'utf8') : '';
const xShared = ((gs.split('## 共有の数字')[1] || '').split('\n## ')[0] || '').split('\n')
  .filter((l) => /^\|/.test(l) && !/^\|\s*-/.test(l) && !/^\|\s*指標/.test(l))
  .map((l) => l.split('|').slice(1, -1).map((c) => c.trim().replace(/\*\*/g, '').replace(/`/g, '')))
  .filter((c) => c.length >= 4).map(([k, v, at, src]) => ({ k, v, at, src }));

// ---------- ASP ----------
const a8 = json(show(HB, 'reports/board/asp-probe/a8partnered.json'));
const aspStatus = json(show(HB, 'reports/asp-sync/status.json'));
const macWeekly = json(show(HB, 'reports/board/mac-weekly-status.json'));
const manual = json(fs.existsSync(path.join(ROOT, 'ops/data/board/manual.json')) ? fs.readFileSync(path.join(ROOT, 'ops/data/board/manual.json'), 'utf8') : null) || {};
const yen = (s) => { const m = (s || '').replace(/,/g, '').match(/(\d{3,6})円/); return m ? +m[1] : null; };
const NG_PROGRAM = /チャットレディ|ライブチャット|出会い|アダルト|風俗/;
const a8Rows = (a8?.rows || []).map((r) => ({ ...r, yen: yen(r.reward), ng: NG_PROGRAM.test(r.name || '') }));

// ---------- 所見（決まった条件に当たったものだけ） ----------
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
const nonSearch = articles.filter((r) => r.v28 >= 30 && r.c28 / r.v28 < 0.2).slice(0, 5);
if (nonSearch.length) push('info', 'non-search', `検索のクリックが訪問の 2 割未満なのに読まれている記事が ${nonSearch.length} 本：${nonSearch.map((r) => `「${r.title.slice(0, 20)}」（訪問 ${r.v28}・検索クリック ${r.c28}）`).join('、')}。${refDays28.length ? '参照元は「記事を調べる」で見られる。' : '参照元の記録は始めたばかり。訪問はボットを含む数。'}`);
const ngs = a8Rows.filter((r) => r.ng);
if (ngs.length) push('warn', 'ng-program', `A8 の提携中に、ブログの読者層と合わない案件が ${ngs.length} 件（${ngs.map((r) => r.name.slice(0, 20)).join('、')}）。記事には使わない。`);
const staleness = [['検索データ', gsc?.generated], ['A8 の一覧', a8?.generated], ['読者データ', lastDay]].filter(([, t]) => t && daysAgo(t) > 9);
if (staleness.length) push('warn', 'stale', `古いデータ：${staleness.map(([n, t]) => `${n}（${daysAgo(t)} 日前）`).join('、')}。Mac の週次ジョブ（com.dailyhack.board-weekly）を確かめる。`);
if (!a8) push('warn', 'a8-missing', 'A8 の提携一覧がまだ届いていない（Mac の週次ジョブの初回待ち）。');
for (const p of manual.pending || []) if (p.since && daysAgo(p.since) > 21) push('info', 'pending-' + p.key, `${p.label} は申請から ${daysAgo(p.since)} 日。審査の状況を確かめる。`);

const snapshot = {
  generatedAt: new Date().toISOString(),
  sources: {
    gsc: gsc ? { file: gscFile, generated: gsc.generated, window: [gscCur.from, gscCur.to] } : null,
    pv: lastDay ? { branch: 'ops/pv-archive', lastDay, days28: in28.length } : null,
    a8: a8 ? { file: 'reports/board/asp-probe/a8partnered.json', generated: a8.generated } : null,
    aspSync: aspStatus ? { generated: aspStatus.generated, pushed: lastTouched(HB, 'reports/asp-sync/status.json') } : null,
    macWeekly,
  },
  kpi: {
    gsc28: gscCur, gscPrev28: gscPrev, gsc90: gsc90,
    pv28: { visits: pvSum(in28, 'visits'), human: pvSum(in28, 'human'), jp: pvSum(in28, 'jp') },
    pvPrev28: { visits: pvSum(inPrev28, 'visits'), human: pvSum(inPrev28, 'human'), jp: pvSum(inPrev28, 'jp') },
    posts: { total: postList.length, isPR: postList.filter((p) => p.isPR).length, withAff: postList.filter((p) => p.aff > 0).length },
    pos4to10: { pages: pos4to10.length, impressions: sum(pos4to10, 'i') },
  },
  gscWeekly, topPages, queries, readTop, articles, pvMeta, xShared,
  a8: a8 ? { total: a8.total, rows: a8Rows } : null,
  manual,
  findings,
};
fs.writeFileSync(OUT, JSON.stringify(snapshot, null, 1));
JSON.parse(fs.readFileSync(OUT, 'utf8')); // 書いたものを読み直す（最上位ルール 13）
console.log(`snapshot: ${OUT}  gsc=${!!gsc}(${gscFile}) pv=${lastDay} a8=${a8 ? a8Rows.length : 0} findings=${findings.length}`);
