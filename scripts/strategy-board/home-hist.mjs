#!/usr/bin/env node
// 作戦室のトップ（全体像）の「前週・前月との差」に使う、日ごとの小さな記録（db の snapshot/hist）。
// 2026-11-19 利用者「作戦室のトップページに、X とブログとアフィリエイトのサマリ…」で足した。
// snapshots/<日付> は 1 文書 10〜50 万バイトあり、作戦室で 7 日前・28 日前を読むには重すぎるので、数字だけを 1 文書に積む。
//
// 使い方
//   build-snapshot.mjs --hist <今の snapshot/hist の JSON> で、その日の行を足した <out>.hist.json を書く（毎朝のルーティン）
//   node scripts/strategy-board/home-hist.mjs <snapshots のフォルダ> [今の hist.json] > hist.json   … 過去の snapshots から作り直す
//
// 成果（results/latest）は affiliate が db に直接書くもので、リポジトリにも snapshot にも入らない。
// --results <results/latest の JSON> を渡したときだけ、ASP ごとのクリック・発生の件数を積む（報酬額は積まない）。
import fs from 'node:fs';
import path from 'node:path';

const num = (v) => {
  if (v == null) return null;
  const m = String(v).replace(/,/g, '').match(/(\d+(?:\.\d+)?)\s*(K|万)?/);
  if (!m) return null;
  return Math.round(Number(m[1]) * (m[2] === 'K' ? 1000 : m[2] === '万' ? 10000 : 1));
};
export const jstDate = (t) => new Date(new Date(t).getTime() + 9 * 3600e3).toISOString().slice(0, 10);

// snapshot（build-snapshot の出力・db の snapshot/latest・snapshots/<日付> のどれでもよい）から、その日の数字を抜く
export function entryOf(S, results) {
  // 手書きの表（docs/growth-strategy.md・古い値）から来た X の数字は積まない（2026-11-11 に 122 が混ざっていた）
  const X = (S.xShared || []).filter((r) => !/手書き/.test(r.src || '')), xr = (k) => X.find((r) => r.k === k) || {};
  const k = S.kpi || {};
  const e = {
    fol: num(xr('フォロワー').v), vfol: num(xr('認証済みフォロワー').v),
    imp7: num(xr('インプレッション（7 日）').v), vimp90: num(xr('認証済みインプレッション（90 日・ホーム・返信除く）').v),
    xAt: xr('フォロワー').at || null,
    readers28: k.pv28?.human ?? null, clicks28: k.gsc28?.clicks ?? null, imp28: k.gsc28?.impressions ?? null,
    withAff: k.posts?.withAff ?? null, posts: k.posts?.total ?? null,
  };
  if (results?.rows?.length) {
    e.aff = { at: results.generatedAt || null, rows: results.rows.map((r) => ({ asp: r.asp, period: r.period || '', clicks: r.clicks ?? null, occurred: r.occurred ?? null })) };
  }
  for (const key of Object.keys(e)) if (e[key] == null) delete e[key];
  return e;
}

// 記録に 1 日分を足す（同じ日は上書き）。古いものは 400 日で落とす
export function addDay(hist, date, entry) {
  const days = { ...((hist && hist.days) || {}) };
  days[date] = { ...(days[date] || {}), ...entry };
  const keep = Object.keys(days).sort().slice(-400);
  return { generated: new Date().toISOString(), note: '作戦室の全体像の「前週・前月との差」用。build-snapshot.mjs --hist が毎朝 1 行足す', days: Object.fromEntries(keep.map((d) => [d, days[d]])) };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const dir = process.argv[2];
  if (!dir) { console.error('使い方: node home-hist.mjs <snapshots のフォルダ> [今の hist.json]'); process.exit(1); }
  const read = (f) => { const j = JSON.parse(fs.readFileSync(f, 'utf8')); return j.data || j; };
  let hist = process.argv[3] && fs.existsSync(process.argv[3]) ? read(process.argv[3]) : { days: {} };
  for (const f of fs.readdirSync(dir).filter((x) => /^\d{4}-\d{2}-\d{2}\.json$/.test(x)).sort()) {
    const S = read(path.join(dir, f));
    hist = addDay(hist, f.slice(0, 10), entryOf(S));
  }
  process.stdout.write(JSON.stringify(hist, null, 1) + '\n');
}
