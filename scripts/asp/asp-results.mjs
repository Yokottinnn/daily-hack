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
  // 2026-11-12: 利用者「報酬金額だけじゃなくて発生売上も取得して」。A8 で売上（注文金額）の列があるのは「成果別（確定）」だけ（t612 で確かめた）
  { id: 'a8', name: 'A8.net', urls: ['https://media-console.a8.net/report/program/summary', 'https://media-console.a8.net/report/confirmed/program', 'https://media-console.a8.net/report/confirmed/result'] },
  // 2026-11-06: 楽天で初の発生（未確定 1 件）。何がどの店で買われたかを見るため、サマリの画面から「注文明細」「ショップ別」「成果報酬・確定実績」も辿る（利用者「159円の報酬が発生しているみたいだけど、これなに？」）
  { id: 'rakuten', name: '楽天アフィリエイト', urls: ['https://affiliate.rakuten.co.jp/report/summary'], tabs: ['注文明細', 'ショップ別', '成果報酬・確定実績'] },
  { id: 'vc', name: 'バリューコマース', top: 'https://aff.valuecommerce.ne.jp/', link: /^レポート$/ },
  // 2026-11-12: 利用者「Amazonも追加してよ」。ホームの「今月のレポート」（クリック・注文済み・発送済み・紹介料）と、ホームのリンクにある「売上レポート」（t612 で確かめた）
  { id: 'amazon', name: 'Amazon アソシエイト', urls: ['https://affiliate.amazon.co.jp/home', 'https://affiliate.amazon.co.jp/home/reports'] },
  // もしもは 2026-11-02 にメディア登録が削除され、利用者の判断で放置（読まない）
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
    const followed = new Set();
    for (let ui = 0; ui < urls.length; ui++) {
      const u = urls[ui];
      await go(u);

      const title = (await p.title()).slice(0, 60);
      const tables = await readTables();
      lines.push(`- 画面: ${here()}（${hide(title)}）・表 ${tables.length} 個`);
      tables.forEach((t, i) => {
        lines.push(`  - 表 ${i + 1}: 見出し「${t.head.map(hide).join(' | ')}」・行 ${t.rows.length}`);
        if (!followed.has(u)) t.rows.slice(0, 8).forEach((r) => { if (!NG.test(r.join(' '))) lines.push(`    - ${r.map(hide).join(' | ').slice(0, 220)}`); });
      });
      if (!tables.length && !followed.has(u)) {
        const txt = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).slice(0, 60));
        lines.push('  - 表が無い。画面の文字（数字は伏せる）:', ...txt.filter((x) => !NG.test(x)).slice(0, 30).map((x) => `    - ${hide(x).slice(0, 120)}`));
      }
      // 楽天のレポートは表ではなく文字で並ぶ（t340）。collect のときは画面の文字も持つ（数字入り・非公開の置き場にだけ書く）
      const text = MODE === 'collect' ? await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).slice(0, 400)) : undefined;
      result.asps[e.id].push({ url: here(), title, tables, text });
    }
    // タブを文字で押して読む（楽天の「注文明細」などは普通のリンクではなかった・2026-11-06）。商品名が出るので公開の md には件数だけ
    for (const label of e.tabs || []) {
      await go(urls[0]);
      const el = p.getByText(label, { exact: true }).first();
      const ok = await el.click({ timeout: 8000 }).then(() => true).catch(() => false);
      await p.waitForTimeout(5000);
      const tables = ok ? await readTables() : [];
      lines.push(`- タブ「${label}」: ${ok ? '押せた' : '押せない'}・画面 ${here()}・表 ${tables.length} 個${tables.map((t) => '（行 ' + t.rows.length + '）').join('')}`);
      const text = ok && MODE === 'collect' ? await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).slice(0, 400)) : undefined;
      if (ok) result.asps[e.id].push({ url: here(), tab: label, title: (await p.title()).slice(0, 60), tables, text });
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
