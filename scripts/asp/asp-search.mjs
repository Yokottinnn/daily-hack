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
{
  const lines = ['# A8.net の検索結果（asp-search）', '', `生成: **${new Date().toISOString()}**`, ''];
  for (const kw of KW) {
    if (Date.now() - T0 > BUDGET * 0.55) { lines.push(`- （時間切れで「${kw}」以降は検索していない）`); break; }
    await p.goto(`https://media-console.a8.net/program/search/keyword?keywords=${encodeURIComponent(kw)}`, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
    await p.waitForTimeout(2500);
    if (await loggedOut()) { lines.push('**未ログイン。** asp-sync で入り直してから走らせる'); break; }
    const rows = await p.evaluate(() => {
      const out = new Map();
      for (const a of document.querySelectorAll('a[href*="programId="]')) {
        const id = (a.href.match(/programId=(s\d+)/) || [])[1];
        if (!id || out.has(id)) continue;
        let box = a; for (let i = 0; i < 6 && box.parentElement; i++) { box = box.parentElement; if (box.innerText && box.innerText.length > 60) break; }
        out.set(id, (box.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 260));
      }
      return [...out.entries()];
    });
    lines.push(`## 「${kw}」 ${rows.length} 件`, '');
    for (const [id, t] of rows.slice(0, 12)) if (!NG.test(t)) lines.push(`- \`${id}\` ${t.replace(/\|/g, '／')}`);
    lines.push('');
  }
  fs.writeFileSync(path.join(OUT, 'a8.md'), lines.join('\n') + '\n');
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
