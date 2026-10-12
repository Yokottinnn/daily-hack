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
const months = [...new Set([0, 1, 2].map((k) => { const d = new Date(today); d.setMonth(d.getMonth() - k, 1); return iso(d).slice(0, 7); }))];
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
  gscWeekly, topPages, queries, readTop,
  a8: a8 ? { total: a8.total, rows: a8Rows } : null,
  manual,
  findings,
};
fs.writeFileSync(OUT, JSON.stringify(snapshot, null, 1));
JSON.parse(fs.readFileSync(OUT, 'utf8')); // 書いたものを読み直す（最上位ルール 13）
console.log(`snapshot: ${OUT}  gsc=${!!gsc}(${gscFile}) pv=${lastDay} a8=${a8 ? a8Rows.length : 0} findings=${findings.length}`);
