// ASP の画面を「読むだけ」で調べる（Mac で動かす・LLM 不使用・$0）。ASP_PROBE=rakuten|a8|vc で 1 つだけ走らせる。
// ログインは asp-sync.mjs が保っている Chrome（CDP 18810）を使う。**URL を推測しない**（最上位ルール 20）。
// 画面にあるリンク・ボタンを集めて、それを辿る。
// **出さないもの**: 自分の報酬額・契約者名・契約者 ID・口座。楽天のアフィリエイト ID は公開リンクに必ず入る値なので出す。
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const PW_DIR = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')]
  .find((d) => fs.existsSync(path.join(d, 'playwright-core')));
if (!PW_DIR) { console.log('playwright-core が無い'); process.exit(0); }
const { chromium } = createRequire(path.join(PW_DIR, 'x.js'))('playwright-core');
const OUT = path.join(process.env.OPS_REPORT_DIR || path.join(os.homedir(), '.openclaw/ops-heartbeat-wt/reports'), 'asp-probe');
fs.mkdirSync(OUT, { recursive: true });
const WHICH = process.env.ASP_PROBE || '';
const NG = /契約者|振込|口座|氏名|合同会社|有限会社|（\d{6,}）|\(\d{6,}\)|あなたの報酬|確定報酬|未確定|様$/;
const RID = /[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}/g;

const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const lines = [`# ASP の画面調べ: ${WHICH}（asp-probe）`, '', `生成: **${new Date().toISOString()}**`, ''];
const go = async (u) => { await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch((e) => lines.push(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`)); await p.waitForTimeout(3500); };
const here = () => { const u = new URL(p.url()); return u.origin + u.pathname; };
const links = (re) => p.evaluate((src) => {
  const r = new RegExp(src); const seen = new Set();
  return [...document.querySelectorAll('a, [role=button], button')]
    .map((a) => [(a.innerText || a.title || '').replace(/\s+/g, ' ').trim().slice(0, 50), a.href || a.getAttribute('onclick') || ''])
    .filter(([t, h]) => t && r.test(t) && !seen.has(t + h) && seen.add(t + h)).slice(0, 40);
}, re.source);

try {
  if (WHICH === 'rakuten') {
    await go('https://affiliate.rakuten.co.jp/');
    lines.push(`- 開いた画面: ${here()}`, '');
    lines.push('## リンク作成・ツールのメニュー', '', ...(await links(/リンク|ツール|作成|商品|ID|サイト/)).map(([t, h]) => `- ${t} — ${h}`), '');
    // 商品を 1 つ検索して、作られたリンクから ID を読む
    const box = p.locator('input[name=sitem]:visible, input[type=search]:visible').first();
    if (await box.count()) {
      await box.fill('楽天カード'); await box.press('Enter');
      await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {});
      await p.waitForTimeout(5000);
      lines.push(`- 「楽天カード」で検索した画面: ${here()}`, '');
      lines.push('## 検索結果の画面のボタン', '', ...(await links(/リンク|作成|コピー|ツール/)).map(([t, h]) => `- ${t} — ${h}`), '');
    } else lines.push('- 検索欄が見つからない', '');
    // 「商品リンク作成」の画面を開くと、アフィリエイト ID 入りのリンクのコードが出る
    const mk = await p.evaluate(() => { const a = [...document.querySelectorAll('a[href*="/link/pc/item"]')][0]; return a ? a.href : ''; });
    if (mk) {
      await go(mk);
      lines.push(`- 商品リンク作成の画面: ${here()}`, '');
      const codes = await p.evaluate(() => [...document.querySelectorAll('textarea, input[type=text]')].map((t) => t.value || '').filter((v) => /rakuten/.test(v)).slice(0, 3));
      lines.push('## 画面に出たリンクのコード（先頭だけ）', '', '```text', ...codes.map((c) => c.replace(/\s+/g, ' ').slice(0, 400)), '```', '');
    }
    const got = await p.evaluate((src) => {
      const html = document.documentElement.outerHTML;
      const ids = [...new Set(html.match(new RegExp(src, 'g')) || [])];
      const afl = [...new Set((html.match(/https?:\/\/hb\.afl\.rakuten\.co\.jp\/[^"'<\s]+/g) || []))].slice(0, 3);
      return { ids, afl };
    }, RID.source);
    lines.push('## 楽天アフィリエイト ID', '', got.ids.length ? got.ids.map((x) => `- \`${x}\``).join('\n') : '（見つからない）', '');
    lines.push('## 作られたリンクの例', '', '```text', ...got.afl.map((x) => x.replace(/&amp;/g, '&').slice(0, 300)), '```', '');
  }

  if (WHICH === 'a8') {
    const TARGET = new Set((process.env.A8_IDS || '').split(',').filter(Boolean));
    const KW = (process.env.A8_KEYWORDS || '').split(',').filter(Boolean);
    const found = new Map();
    for (const kw of KW) {
      await go(`https://media-console.a8.net/program/search/keyword?keywords=${encodeURIComponent(kw)}`);
      if (kw === KW[0]) lines.push(`- 開いた画面: ${here()}（${(await p.title()).slice(0, 40)}）`, `- 画面の programId リンク数: ${await p.locator('a[href*="programId="]').count()}`, '');
      const rows = await p.evaluate(() => {
        const out = [];
        const seen = new Set();
        for (const a of document.querySelectorAll('a[href*="programId="]')) {
          const id = (a.href.match(/programId=(s\d+)/) || [])[1];
          if (!id || seen.has(id)) continue; seen.add(id);
          let box = a; for (let i = 0; i < 8 && box.parentElement; i++) { box = box.parentElement; if ((box.innerText || '').includes('プログラムID')) break; }
          const t = (box.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean);
          const alts = [...box.querySelectorAll('img[alt]')].map((i) => i.alt.trim()).filter(Boolean);
          const heads = [...box.querySelectorAll('h1,h2,h3,h4,h5,strong,b,[class*=name],[class*=Name],[class*=title],[class*=Title]')].map((h) => h.innerText.replace(/\s+/g, ' ').trim()).filter(Boolean);
          const hrefs = [...new Set([...box.querySelectorAll('a[href]')].map((x) => x.href))].slice(0, 4);
          out.push({ id, heads: [...new Set(heads)].slice(0, 4), alts: alts.slice(0, 3), first: t.slice(0, 4), join: t.filter((x) => /即時|審査|提携/.test(x)).slice(0, 3), hrefs });
        }
        return out;
      });
      for (const r of rows) if ((!TARGET.size || TARGET.has(r.id)) && !found.has(r.id)) found.set(r.id, { kw, ...r });
    }
    lines.push(`## 候補 ${found.size} 件`, '');
    for (const [id, r] of found) {
      const clean = (a) => a.filter((x) => !NG.test(x)).map((x) => x.slice(0, 60).replace(/\|/g, '／')).join(' ／ ');
      lines.push(`### ${id}（検索語「${r.kw}」）`, `- 見出し: ${clean(r.heads)}`, `- 画像の alt: ${clean(r.alts)}`, `- 先頭の行: ${clean(r.first)}`, `- 提携の表示: ${clean(r.join)}`, `- リンク: ${r.hrefs.join(' ')}`, '');
    }
    const miss = [...TARGET].filter((x) => !found.has(x));
    if (miss.length) lines.push(`- 検索結果に出なかった: ${miss.join(', ')}`, '');
  }

  if (WHICH === 'vc') {
    await go('https://aff.valuecommerce.ne.jp/home');
    lines.push(`- 開いた画面: ${here()}`, '');
    const paths = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => h.includes('aff.valuecommerce.ne.jp')).map((h) => h.replace(/[?#].*$/, '').replace(/\/\d+$/, '/<数字>')))].sort());
    lines.push('## 画面にあるバリューコマース内のリンク先（重複なし）', '', ...paths.map((x) => `- ${x}`), '');
    lines.push('## 「提携」を含むメニュー', '', ...(await links(/提携|参加|広告主|広告を探す/)).map(([t, h]) => `- ${t} — ${h}`), '');
    const el = p.locator('a, [role=button], button, li, span').filter({ hasText: /^\s*提携済み\s*$/ }).first();
    if (await el.count()) {
      await el.click({ timeout: 5000 }).catch(() => {});
      await p.waitForLoadState('domcontentloaded', { timeout: 15000 }).catch(() => {});
      await p.waitForTimeout(4000);
      lines.push(`- 「提携済み」を押したあとの画面: ${here()}`, '');
      lines.push('## 押したあとに出たメニュー', '', ...(await links(/提携|参加|一覧/)).map(([t, h]) => `- ${t} — ${h}`), '');
      const rows = await p.evaluate(() => {
        const seen = new Set();
        return [...document.querySelectorAll('a[href*="adDetail"]')]
          .map((a) => { let r = a; for (let i = 0; i < 5 && r.parentElement; i++) { r = r.parentElement; if ((r.innerText || '').length > (a.innerText || '').length + 10) break; }
            const st = ((r.innerText || '').match(/提携中|提携済み?|提携待ち|未提携|審査中|新規提携|即時提携/g) || []).join('・');
            const vis = !!(a.offsetWidth || a.offsetHeight);
            return [`${(a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 70)}［${st || '状態の表示なし'}${vis ? '' : '・非表示'}］`, a.href.replace(/\?.*$/, '')]; })
          .filter(([t, h]) => t && !seen.has(h) && seen.add(h));
      });
      lines.push(`## 広告の行（${rows.length} 件）`, '', ...rows.filter(([t]) => !NG.test(t)).map(([t, h]) => `- ${t.replace(/\|/g, '／')} — ${h}`), '');
    } else lines.push('- 「提携済み」が見つからない', '');
  }
} catch (e) { lines.push(`- ⚠️ 失敗: ${String(e).slice(0, 200)}`); }
fs.writeFileSync(path.join(OUT, `${WHICH}.md`), lines.join('\n') + '\n');
console.log(lines.join('\n').slice(0, 2500));
await p.close().catch(() => {});
process.exit(0);
