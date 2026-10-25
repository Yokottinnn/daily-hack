// ASP の成果（クリック・発生・確定と報酬額）を Mac で読む（affiliate・2026-10-25 利用者のコメント 0dxd6x2bbryrclqjesc3）。LLM 不使用・$0。
//   RESULTS_MODE=shape   … レポート画面の形（表の見出し・行の名前）だけを読む。**数字は全部 # に伏せる**（公開ブランチに出してよい）
//   RESULTS_MODE=collect … 数字を読み、RESULTS_OUT（非公開の置き場）に JSON で書く。**公開ブランチには出さない**
// ログインは asp-sync.mjs が保っている Chrome（CDP 18810）を使う。URL は asp-sync が読んだメニューにあるものだけ（推測しない）。
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const PW_DIR = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')]
  .find((d) => fs.existsSync(path.join(d, 'playwright-core')));
if (!PW_DIR) { console.log('playwright-core が無い'); process.exit(0); }
const { chromium } = createRequire(path.join(PW_DIR, 'x.js'))('playwright-core');
const MODE = process.env.RESULTS_MODE || 'shape';
const OUT = path.join(process.env.OPS_REPORT_DIR || '/tmp', 'asp-results');
fs.mkdirSync(OUT, { recursive: true });
const NG = /契約者|振込|口座|氏名|会社|様$|さん$|Welcome|ようこそ|こんにちは|@/i;
const hide = (x) => String(x).replace(/[0-9０-９][0-9０-９,，.]*/g, '#').replace(/[A-Za-z0-9_\-]{16,}/g, '［伏せた］');
const lines = [`# ASP の成果の画面（asp-results・${MODE}）`, '', `生成: **${new Date().toISOString()}**`, ''];
process.on('unhandledRejection', (e) => { lines.push(`- ⚠️ 未処理のエラー: ${hide(String(e && e.message || e).split('\n')[0].slice(0, 160))}`); });

// asp-sync のメニューにあった入口（reports/.sync/asp-sync/*.md）。VC ともしもは「レポート」の文字のリンクを辿る
const ENTRY = [
  { id: 'a8', name: 'A8.net', urls: ['https://media-console.a8.net/report/program/summary', 'https://media-console.a8.net/report/confirmed/program'] },
  { id: 'rakuten', name: '楽天アフィリエイト', urls: ['https://affiliate.rakuten.co.jp/report/summary'] },
  { id: 'vc', name: 'バリューコマース', top: 'https://aff.valuecommerce.ne.jp/', link: /^レポート$/ },
  { id: 'moshimo', name: 'もしも', top: 'https://af.moshimo.com/af/shop/index', link: /^レポート$/ },
];

const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
p.on('dialog', (d) => d.dismiss().catch(() => {}));
const go = async (u) => { await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch((e) => lines.push(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`)); await p.waitForTimeout(4000); };
const here = () => { try { const u = new URL(p.url()); return u.origin + u.pathname; } catch { return p.url(); } };
const readTables = () => p.evaluate(() => [...document.querySelectorAll('table')].filter((t) => t.getBoundingClientRect().height > 0).slice(0, 6).map((t) => ({
  head: [...t.querySelectorAll('thead th, tr:first-child th')].map((x) => x.innerText.replace(/\s+/g, ' ').trim()).slice(0, 16),
  rows: [...t.querySelectorAll('tbody tr')].slice(0, 40).map((r) => [...r.children].map((c) => c.innerText.replace(/\s+/g, ' ').trim()).slice(0, 16)),
})));
const result = { generatedAt: new Date().toISOString(), asps: {} };

try {
  for (const e of ENTRY) {
    lines.push(`## ${e.name}`, '');
    let urls = e.urls || [];
    if (!urls.length) {
      await go(e.top);
      const links = await p.evaluate((src) => { const re = new RegExp(src); return [...new Set([...document.querySelectorAll('a[href]')].filter((a) => re.test((a.innerText || '').trim())).map((a) => a.href))].slice(0, 3); }, e.link.source);
      lines.push(`- 「レポート」のリンク: ${links.length} 件`);
      urls = links;
    }
    result.asps[e.id] = [];
    for (const u of urls) {
      await go(u);
      const title = (await p.title()).slice(0, 60);
      const tables = await readTables();
      lines.push(`- 画面: ${here()}（${hide(title)}）・表 ${tables.length} 個`);
      tables.forEach((t, i) => {
        lines.push(`  - 表 ${i + 1}: 見出し「${t.head.map(hide).join(' | ')}」・行 ${t.rows.length}`);
        t.rows.slice(0, 8).forEach((r) => { if (!NG.test(r.join(' '))) lines.push(`    - ${r.map(hide).join(' | ').slice(0, 220)}`); });
      });
      if (!tables.length) {
        const txt = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).slice(0, 60));
        lines.push('  - 表が無い。画面の文字（数字は伏せる）:', ...txt.filter((x) => !NG.test(x)).slice(0, 30).map((x) => `    - ${hide(x).slice(0, 120)}`));
      }
      // 楽天のレポートは表ではなく文字で並ぶ（t340）。collect のときは画面の文字も持つ（数字入り・非公開の置き場にだけ書く）
      const text = MODE === 'collect' ? await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).slice(0, 400)) : undefined;
      result.asps[e.id].push({ url: here(), title, tables, text });
    }
    lines.push('');
  }
} catch (err) { lines.push(`- ⚠️ ${hide(String(err).split('\n')[0])}`); }
finally { await p.close().catch(() => {}); }

fs.writeFileSync(path.join(OUT, `${MODE}.md`), lines.join('\n') + '\n');
if (MODE === 'collect' && process.env.RESULTS_OUT) {
  fs.mkdirSync(path.dirname(process.env.RESULTS_OUT), { recursive: true });
  fs.writeFileSync(process.env.RESULTS_OUT, JSON.stringify(result, null, 1) + '\n');   // 数字入り。非公開の置き場にだけ書く
}
console.log(lines.join('\n'));
process.exit(0);
