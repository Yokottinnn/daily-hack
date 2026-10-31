// A8・もしも・バリューコマースで、記事に合う広告を探す（Mac で動かす・LLM 不使用・$0）。
// ログインは asp-sync.mjs が保っている Chrome（CDP 18810）を使う。入れていなければ「未ログイン」と書いて飛ばす。
// **出さないもの**: 自分の報酬額・契約者名・契約者 ID・口座。出すのは広告の名前・ID・提携状態・広告側の報酬条件だけ。
//
// 使い方: ASP_KEYWORDS="楽天カード,JAL" node asp-search.mjs   → $OPS_REPORT_DIR/asp-search/*.md
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const PW_DIR = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')]
  .find((d) => fs.existsSync(path.join(d, 'playwright-core')));
if (!PW_DIR) { console.log('playwright-core が無い'); process.exit(0); }
const { chromium } = createRequire(path.join(PW_DIR, 'x.js'))('playwright-core');
const OUT = path.join(process.env.OPS_REPORT_DIR || path.join(os.homedir(), '.openclaw/ops-heartbeat-wt/reports'), 'asp-search');
fs.mkdirSync(OUT, { recursive: true });
const BUDGET = Number(process.env.ASP_SEARCH_BUDGET_MS || 220000);
const T0 = Date.now();
const KW = (process.env.ASP_KEYWORDS || '').split(',').map((x) => x.trim()).filter(Boolean);
const NG = /契約者|振込|口座|氏名|合同会社|有限会社|（\d{6,}）|\(\d{6,}\)|あなたの報酬|確定報酬|未確定/;
const clean = (t) => t.replace(/\s+/g, ' ').trim();

const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const loggedOut = async () => p.evaluate(() => !!document.querySelector('input[type=password]') || /login|re-authentication/i.test(location.href));

// ---- A8: キーワード検索 ----
const ALL = [];
{
  const lines = ['# A8.net の検索結果（asp-search）', '', `生成: **${new Date().toISOString()}**`, ''];
  for (const kw of KW) {
    if (Date.now() - T0 > BUDGET * 0.55) { lines.push(`- （時間切れで「${kw}」以降は検索していない）`); break; }
    await p.goto(`https://media-console.a8.net/program/search/keyword?keywords=${encodeURIComponent(kw)}`, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
    await p.waitForTimeout(2500);
    if (await loggedOut()) { lines.push('**未ログイン。** asp-sync で入り直してから走らせる'); break; }
    const rows = await p.evaluate(() => {
      const out = new Map(), names = new Map();
      for (const a of document.querySelectorAll('a[href*="programId="]')) {
        const id = (a.href.match(/programId=(s\d+)/) || [])[1];
        if (!id) continue;
        // 広告の名前：同じ ID へのリンクの文字・画像の alt のうち、いちばん長いもの（2026-10-17：表の箱だけ拾って名前が抜けていた）
        for (const t of [a.innerText, ...[...a.querySelectorAll('img')].map((i) => i.alt)]) {
          const v = (t || '').replace(/\s+/g, ' ').trim();
          if (v && v.length < 120 && !/^(詳細|提携|プログラム詳細|広告リンク)/.test(v) && v.length > (names.get(id) || '').length) names.set(id, v);
        }
        if (out.has(id)) continue;
        let box = a; for (let i = 0; i < 6 && box.parentElement; i++) { box = box.parentElement; if (box.innerText && box.innerText.length > 60) break; }
        // カード全体：親に別の広告の ID が混ざらないところまで上る。その 1 行目が広告の名前
        let card = box;
        for (let i = 0; i < 8 && card.parentElement; i++) {
          const ids = new Set([...card.parentElement.querySelectorAll('a[href*="programId="]')].map((x) => (x.href.match(/programId=(s\d+)/) || [])[1]));
          if (ids.size > 1) break; card = card.parentElement;
        }
        const first = (card.innerText || '').split('\n').map((x) => x.trim()).find((x) => x && !/^(未提携|提携中|提携審査中|【商品リンク作成】|NEW|新着|プログラムID)/.test(x));
        if (first && first.length < 120 && !names.has(id)) names.set(id, first);
        out.set(id, (box.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 260));
      }
      return [...out.entries()].map(([id, t]) => [id, (names.get(id) ? '【' + names.get(id) + '】 ' : '') + t]);
    });
    lines.push(`## 「${kw}」 ${rows.length} 件`, '');
    for (const [id, t] of rows) if (!NG.test(t)) ALL.push({ kw, id, text: t });
    for (const [id, t] of rows.slice(0, 12)) if (!NG.test(t)) lines.push(`- \`${id}\` ${t.replace(/\|/g, '／')}`);
    lines.push('');
  }
  const SUF = process.env.ASP_OUT_SUFFIX || '';
  fs.writeFileSync(path.join(OUT, `a8${SUF}.md`), lines.join('\n') + '\n');
  // 全件（md は 1 語 12 件まで）。申請の候補を選ぶのに使う（2026-10-31）
  if (SUF) fs.writeFileSync(path.join(OUT, `a8${SUF}.json`), JSON.stringify({ generated: new Date().toISOString(), keywords: KW, rows: ALL }, null, 1));
  console.log(`a8: ${KW.length} 語`);
}

// ---- もしも: 提携中の一覧 ----
if (Date.now() - T0 < BUDGET * 0.8) {
  const lines = ['# もしもアフィリエイト 提携中（asp-search）', '', `生成: **${new Date().toISOString()}**`, ''];
  await p.goto('https://af.moshimo.com/af/shop/promotion/search?apply_status=2', { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
  await p.waitForTimeout(3000);
  if (await loggedOut()) lines.push('**未ログイン。**');
  else {
    const rows = await p.evaluate(() => [...document.querySelectorAll('a[href*="promotion"]')]
      .map((a) => [(a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80), a.href]).filter(([t, h]) => t && /promotion_id|\/detail|p_id=/.test(h)));
    const seen = new Set();
    for (const [t, h] of rows) if (!seen.has(h) && seen.add(h) && !NG.test(t)) lines.push(`- ${t.replace(/\|/g, '／')} — ${h}`);
    lines.push('', `（${seen.size} 件）`);
  }
  fs.writeFileSync(path.join(OUT, 'moshimo.md'), lines.join('\n') + '\n');
  console.log('moshimo: 済');
}

// ---- バリューコマース: 提携済みの一覧 ----
if (Date.now() - T0 < BUDGET) {
  const lines = ['# バリューコマース 提携済み（asp-search）', '', `生成: **${new Date().toISOString()}**`, ''];
  await p.goto('https://aff.valuecommerce.ne.jp/home', { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
  await p.waitForTimeout(3000);
  if (await loggedOut()) lines.push('**未ログイン。**');
  else {
    const link = await p.evaluate(() => { const a = [...document.querySelectorAll('a')].find((x) => /^提携済み$/.test((x.innerText || '').trim())); return a ? a.href : ''; });
    lines.push(`- 「提携済み」の URL: ${link || '（見つからない）'}`, '');
    if (link) {
      await p.goto(link, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
      await p.waitForTimeout(3500);
      const rows = await p.evaluate(() => [...document.querySelectorAll('a[href*="adDetail"]')]
        .map((a) => [(a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80), a.href]).filter(([t]) => t));
      const seen = new Set();
      for (const [t, h] of rows) if (!seen.has(h) && seen.add(h) && !NG.test(t)) lines.push(`- ${t.replace(/\|/g, '／')} — ${h}`);
      lines.push('', `（${seen.size} 件）`);
    }
  }
  fs.writeFileSync(path.join(OUT, 'vc.md'), lines.join('\n') + '\n');
  console.log('vc: 済');
}
await p.close().catch(() => {});
process.exit(0);
