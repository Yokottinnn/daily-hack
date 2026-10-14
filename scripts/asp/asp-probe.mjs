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
// **会員名の行（Welcome, ○○ / ようこそ○○さん）も出さない**（2026-10-11 に楽天ウェブサービスで出してしまった）
const NG = /契約者|振込|口座|氏名|合同会社|有限会社|（\d{6,}）|\(\d{6,}\)|あなたの報酬|確定報酬|未確定|様$|さん$|Welcome|ようこそ|こんにちは/i;
const ROWS = [];
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
  if (WHICH === 'rakuten2') {
    // 商品リンクのコードを丸ごと読み、リンクの形（パラメータ名）を確かめる。あわせて「ツールを使う」の中身を見る
    await go('https://affiliate.rakuten.co.jp/search?v=2&g=100316');
    const mk = await p.evaluate(() => { const a = [...document.querySelectorAll('a[href*="/link/pc/item"]')][0]; return a ? a.href : ''; });
    if (mk) {
      await go(mk);
      const hrefs = await p.evaluate(() => {
        const out = new Set();
        for (const t of document.querySelectorAll('textarea, input[type=text]')) for (const m of (t.value || '').matchAll(/https?:\/\/hb\.afl\.rakuten\.co\.jp\/[^"'<\s]+/g)) out.add(m[0]);
        return [...out];
      });
      lines.push('## 商品リンクのコードに入っていた URL（全部）', '', '```text', ...hrefs.map((h) => h.replace(/&amp;/g, '&')), '```', '');
      lines.push('## コードの種類を切り替えるボタン', '', ...(await links(/テキスト|画像|URL|短縮|コード|タイプ|種類/)).map(([t, h]) => `- ${t} — ${h}`), '');
    }
    await go('https://affiliate.rakuten.co.jp/tool');
    lines.push(`- ツールの画面: ${here()}`, '', '## ツールの一覧', '', ...(await links(/./)).filter(([, h]) => /affiliate\.rakuten\.co\.jp\/(tool|link)/.test(h)).map(([t, h]) => `- ${t} — ${h}`), '');
  }

  if (WHICH === 'rakutenws') {
    // 自分のアフィリエイト ID は楽天ウェブサービスの「アプリ一覧」に出る（API の説明 ichiba-item-search の affiliateId「Check here」→ /app/list）
    await go('https://webservice.rakuten.co.jp/app/list');
    let st = await p.evaluate(() => ({ pw: !!document.querySelector('input[type=password]'), url: location.origin + location.pathname, title: document.title.slice(0, 60) }));
    if (/login|authorize/.test(st.url)) {
      // 楽天会員の共通ログイン（OSSO）が残っていれば、ID を選ぶだけで通る
      await p.locator('div[role=button], button, a').filter({ hasText: /^(次へ|ログイン|続ける)$/ }).first().click({ timeout: 5000 }).catch(() => {});
      await p.waitForTimeout(5000);
      st = await p.evaluate(() => ({ pw: !!document.querySelector('input[type=password]'), url: location.origin + location.pathname, title: document.title.slice(0, 60) }));
    }
    lines.push(`- 画面: ${st.url}（${st.title}）${st.pw ? ' ／ パスワード欄あり＝未ログイン' : ''}`, '');
    const got = await p.evaluate((src) => {
      const t = document.body.innerText || '';
      const ids = [...new Set(t.match(new RegExp(src, 'g')) || [])];
      const near = t.split('\n').map((x) => x.trim()).filter((x) => /アフィリエイトID|Affiliate ?ID|アプリ|アプリケーション/i.test(x)).slice(0, 12).map((x) => x.slice(0, 60));
      return { ids, near };
    }, RID.source);
    lines.push('## 画面のアフィリエイト ID', '', got.ids.length ? got.ids.map((x) => `- \`${x}\``).join('\n') : '（見つからない）', '');
    lines.push('## 「アフィリエイトID」「アプリ」を含む行', '', ...got.near.filter((x) => !NG.test(x)).map((x) => `- ${x}`), '');
    // 何も拾えなかったときのために、画面の行とリンクをそのまま出す（**@ を含む行・NG の行は出さない**）
    await p.waitForTimeout(4000);
    const raw = await p.evaluate(() => ({
      text: (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).slice(0, 60).map((x) => x.slice(0, 70)),
      links: [...new Set([...document.querySelectorAll('a[href]')].map((a) => `${(a.innerText || '').trim().slice(0, 30)} — ${a.href.replace(/[?#].*$/, '')}`))].slice(0, 40),
    }));
    lines.push('## 画面の行（先頭 60・長い英数字は伏せる）', '', '```text', ...raw.text.filter((x) => !NG.test(x) && !/@/.test(x)).map((x) => x.replace(/[A-Za-z0-9_-]{16,}/g, (m) => `［${m.length}文字・伏せた］`)), '```', '', '## 画面のリンク', '', ...raw.links.filter((x) => !/@/.test(x)).map((x) => `- ${x.replace(/[A-Za-z0-9_-]{16,}/g, (m) => `［${m.length}文字］`)}`), '');
  }

  if (WHICH === 'rakutenitem') {
    // キーワードで商品を探し、上から 3 件の「商品リンク作成」でリンクの URL を丸ごと取る（ID は商品ごとに違うので、商品ごとに取る）
    for (const kw of (process.env.RAKUTEN_KW || '').split(',').filter(Boolean)) {
      await go('https://affiliate.rakuten.co.jp/');
      const box = p.locator('input[name=sitem]:visible, input[type=search]:visible').first();
      if (!(await box.count())) { lines.push('- 検索欄が見つからない'); break; }
      await box.fill(kw); await box.press('Enter');
      await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {}); await p.waitForTimeout(5000);
      const mks = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href*="/link/pc/item"]')].map((a) => a.href))].slice(0, 3));
      lines.push(`## 「${kw}」`, '');
      for (const mk of mks) {
        const name = decodeURIComponent((mk.match(/goods_name=([^&]*)/) || [])[1] || '').slice(0, 60);
        const price = decodeURIComponent((mk.match(/price=([^&]*)/) || [])[1] || '');
        await go(mk);
        const url = await p.evaluate(() => { for (const t of document.querySelectorAll('textarea, input[type=text]')) { const m = (t.value || '').match(/https?:\/\/hb\.afl\.rakuten\.co\.jp\/ichiba\/[^"'<\s]+/); if (m) return m[0].replace(/&amp;/g, '&'); } return ''; });
        lines.push(`- ${name}（${price}）`, `  - ${url || '（リンクが取れない）'}`);
      }
      lines.push('');
    }
  }

  if (WHICH === 'vc4') {
    // 提携済みの「Yahoo!ショッピング」の広告詳細から、リンクのコード（sid・pid が入る公開値）を読む
    await go('https://aff.valuecommerce.ne.jp/ad/adDetail/2136156');
    lines.push(`- 画面: ${here()}（${(await p.title()).slice(0, 40)}）`, '');
    const codes = await p.evaluate(() => [...document.querySelectorAll('textarea, input[type=text]')].map((t) => t.value || '').filter((v) => /valuecommerce/.test(v)).slice(0, 4));
    lines.push('## 画面に出たリンクのコード', '', '```text', ...codes.map((c) => c.replace(/\s+/g, ' ').slice(0, 500)), '```', '');
    lines.push('## リンク作成・MyLink のボタン', '', ...(await links(/リンク|MyLink|広告を|コード|取得/)).map(([t, h]) => `- ${t} — ${h}`), '');
  }

  if (WHICH === 'forms') {
    // 申請・登録の前に、フォームの中身を読むだけ（送らない）。値は出さず、欄の名前・選択肢・ボタンだけ
    const formDump = async () => p.evaluate(() => {
      const vis = (el) => !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
      const lab = (e) => ((e.closest('label') || {}).innerText || (e.id && (document.querySelector(`label[for="${e.id}"]`) || {}).innerText) || e.placeholder || '').replace(/\s+/g, ' ').trim().slice(0, 40);
      const fields = [...document.querySelectorAll('input, select, textarea')].filter((e) => vis(e) && e.type !== 'hidden').slice(0, 40).map((e) => e.tagName === 'SELECT'
        ? `select[name=${e.name}] 「${lab(e)}」: ${[...e.options].map((o) => o.text.trim()).join(' / ').slice(0, 300)}`
        : `${e.tagName.toLowerCase()}[type=${e.type} name=${e.name}] 「${lab(e)}」${e.required ? ' 必須' : ''}${e.checked ? ' ✔' : ''}`);
      const btns = [...document.querySelectorAll('button, input[type=submit], a[role=button], [role=button]')].filter(vis).map((b) => (b.innerText || b.value || '').replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 20);
      return { fields, btns };
    });
    await go('https://media-console.a8.net/program/detail-not-partnered?programId=s00000023355003');
    let f = await formDump();
    lines.push('## A8 提携申請の欄（三井住友カード NL）', '', ...f.fields.filter((x) => !NG.test(x)).map((x) => `- ${x}`), '', `- ボタン: ${f.btns.join(' ／ ')}`, '');
    await go('https://webservice.rakuten.co.jp/app/create');
    f = await formDump();
    lines.push(`## 楽天ウェブサービス アプリ登録の欄（${here()}）`, '', ...f.fields.filter((x) => !NG.test(x)).map((x) => `- ${x}`), '', `- ボタン: ${f.btns.join(' ／ ')}`, '');
  }

  if (WHICH === 'rakutenws2') {
    // アプリ登録後（2026-10-11）: アプリ一覧 → 詳細で、自分のアフィリエイト ID（公開値）を読み、
    // applicationId などの**鍵は Keychain に入れるだけで出さない**（文字数だけ出す）
    const { execFileSync } = await import('node:child_process');
    await go('https://webservice.rakuten.co.jp/app/list');
    const mask = (x) => x.replace(/[A-Za-z0-9_-]{16,}/g, (m) => `［${m.length}文字・伏せた］`);
    const det = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => /\/app\/(detail|edit|info|show|view)|\/app\/[0-9a-f-]{6,}/i.test(h)))].slice(0, 3));
    lines.push(`- アプリの詳細へのリンク: ${det.length} 件`, '');
    if (det[0]) await go(det[0]);
    else { const more = p.getByText(/More Details|詳細/).first(); if (await more.count()) { await more.click().catch(() => {}); await p.waitForTimeout(4000); } }
    lines.push(`- 画面: ${here()}`, '');
    const got = await p.evaluate((src) => {
      const t = document.body.innerText || '';
      const rows = t.split('\n').map((x) => x.trim()).filter(Boolean);
      const val = (re) => { const i = rows.findIndex((x) => re.test(x)); if (i < 0) return ''; const same = rows[i].replace(re, '').replace(/^[\s:：]+/, '').trim(); return same || rows[i + 1] || ''; };
      return { aff: [...new Set(t.match(new RegExp(src, 'g')) || [])], appId: val(/^(Application ID|アプリID)/i), labels: rows.filter((x) => /ID|Secret|Key|キー/i.test(x)).slice(0, 12) };
    }, RID.source);
    lines.push('## 自分のアフィリエイト ID（公開値）', '', got.aff.length ? got.aff.map((x) => `- \`${x}\``).join('\n') : '（見つからない）', '');
    lines.push('## ID・鍵らしい行（値は伏せる）', '', ...got.labels.filter((x) => !NG.test(x) && !/@/.test(x)).map((x) => `- ${mask(x)}`), '');
    const appId = (got.appId.match(/[A-Za-z0-9_-]{16,}/) || [])[0] || '';
    if (appId) {
      try { execFileSync('/usr/bin/security', ['add-generic-password', '-U', '-s', 'dailyhack-rakuten-ws', '-a', 'applicationId', '-w', appId]); lines.push(`- applicationId を Keychain（dailyhack-rakuten-ws）に入れた（${appId.length} 文字）`); }
      catch (e) { lines.push(`- ⚠️ Keychain に入れられない: ${String(e).slice(0, 80)}`); }
    } else lines.push('- applicationId は見つからない');
    if (got.aff[0]) { fs.writeFileSync(path.join(OUT, 'rakuten-affiliate-id.txt'), got.aff[0] + '\n'); }
  }

  if (WHICH === 'rakutentabs') {
    // 楽天ウェブサービスのタブがいまどうなっているか（登録画面に残ったエラー・画像認証の状態）を読む。押さない・送らない
    const mask = (x) => x.replace(/[A-Za-z0-9_-]{16,}/g, (m) => `［${m.length}文字・伏せた］`);
    const tabs = ctx.pages().filter((q) => /webservice\.rakuten\.co\.jp/.test(q.url()));
    lines.push(`## 楽天ウェブサービスのタブ ${tabs.length} 枚`, '');
    for (const q of tabs) {
      const d = await q.evaluate(() => {
        const vis = (el) => !!(el.offsetWidth || el.offsetHeight);
        const msgs = [...document.querySelectorAll('[role=alert], .error, .alert, [class*=error], [class*=Error], [class*=invalid], .help-block, .text-danger')].filter(vis).map((e) => e.innerText.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 8);
        const fields = [...document.querySelectorAll('input:not([type=hidden]), select, textarea')].filter(vis).map((e) => `${e.name}=${e.type === 'checkbox' ? (e.checked ? '✔' : '－') : ((e.value || '').length + '文字')}`);
        const head = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).filter((x) => /success|registered|error|invalid|required|captcha|完了|登録|エラー|失敗|必須/i.test(x)).slice(0, 10).map((x) => x.slice(0, 90));
        return { url: location.origin + location.pathname, title: document.title.slice(0, 60), msgs, fields, head };
      }).catch((e) => ({ url: q.url(), err: String(e).slice(0, 80) }));
      lines.push(`### ${d.url}（${d.title || ''}）`, ...(d.msgs || []).map((x) => `- 表示: ${mask(x)}`), ...(d.head || []).filter((x) => !NG.test(x)).map((x) => `- 行: ${mask(x)}`), `- 欄: ${(d.fields || []).join(' ')}`, d.err ? `- ⚠️ ${d.err}` : '', '');
    }
  }

  if (WHICH === 'a8apply') {
    // **利用者の OK を得た提携申請**（2026-10-11）。サイト「Daily hack」を選んで「プログラムの提携申請をする」を押す
    p.on('dialog', (d) => { lines.push(`  - 確認ダイアログ: ${d.message().slice(0, 80)} → OK`); d.accept().catch(() => {}); });
    for (const id of (process.env.A8_IDS || '').split(',').filter(Boolean)) {
      lines.push(`### ${id}`);
      await go(`https://media-console.a8.net/program/detail-not-partnered?programId=${id}`);
      const sel = p.locator('select[name=webSiteId]');
      if (!(await sel.count())) { lines.push(`- 申請欄が無い（${here()}・${(await p.title()).slice(0, 40)}）`, ''); continue; }
      const opt = await sel.evaluate((e) => { const o = [...e.options].find((x) => /daily ?hack/i.test(x.text)); return o ? o.value : ''; });
      if (!opt) { lines.push('- 「Daily hack」の選択肢が無い', ''); continue; }
      await sel.selectOption(opt);
      await p.getByText('プログラムの提携申請をする', { exact: false }).first().click({ timeout: 8000 }).catch((e) => lines.push(`- ⚠️ 押せない: ${String(e).split('\n')[0]}`));
      await p.waitForTimeout(4000);
      // 確認のモーダルが出たら「申請する」系を押す
      const conf = p.locator('button:visible, [role=button]:visible, input[type=submit]:visible').filter({ hasText: /^(申請する|提携申請する|はい|OK|確定|送信)$/ }).first();
      if (await conf.count()) { await conf.click({ timeout: 5000 }).catch(() => {}); await p.waitForTimeout(4000); lines.push('- 確認の画面で申請を押した'); }
      const res = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter((x) => /申請|提携|審査|完了|受け付け|エラー|失敗/.test(x)).slice(0, 6).map((x) => x.slice(0, 70)));
      lines.push(`- 押したあとの画面: ${here()}`, ...res.filter((x) => !NG.test(x)).map((x) => `  - ${x}`), '');
    }
  }

  if (WHICH === 'rakutenapp') {
    // **アプリ登録は画像認証があるので、人が入れる。** それ以外の欄を入れて、タブを前に出したまま残す（送らない）
    const q = await ctx.newPage();
    await q.goto('https://webservice.rakuten.co.jp/app/create', { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
    await q.waitForTimeout(3000);
    const fill = async (sel, v) => q.locator(sel).first().fill(v).catch((e) => lines.push(`- ⚠️ ${sel}: ${String(e).split('\n')[0]}`));
    await fill('input[name=app_name]', 'daily-hack');
    await fill('input[name=app_site]', 'https://daily-hack.com/');
    await q.locator('select[name=app_type]').selectOption({ label: 'Web Application' }).catch((e) => lines.push(`- ⚠️ app_type: ${String(e).split('\n')[0]}`));
    await fill('textarea[name=origins]', 'https://daily-hack.com');
    await fill('textarea[name=app_description]', 'ブログ daily-hack.com の記事に、楽天市場・楽天トラベルの商品リンクを載せるためのアプリ');
    await fill('textarea[name=usage_purpose]', '記事で紹介する商品・宿の情報とアフィリエイトリンクを取得するため');
    await fill('input[name=expected_qps]', '1');
    for (const re of [/Ichiba/, /Travel/]) await q.locator('label').filter({ hasText: re }).locator('input[type=checkbox]').first().check({ force: true }).catch(() => {});
    await q.locator('input[name=captcha]').first().scrollIntoViewIfNeeded().catch(() => {});
    await q.locator('input[name=captcha]').first().focus().catch(() => {});
    await q.bringToFront().catch(() => {});
    const st = await q.evaluate(() => [...document.querySelectorAll('input:not([type=hidden]), select, textarea')].filter((e) => e.offsetWidth).map((e) => `${e.name}=${e.type === 'checkbox' ? (e.checked ? '✔' : '－') : ((e.value || '').length + '文字')}`));
    lines.push('## 楽天ウェブサービス アプリ登録（画像認証の手前まで入れた・送っていない）', '', `- 画面: ${q.url().replace(/[?#].*$/, '')}`, ...st.map((x) => `- ${x}`), '', '**このタブは開いたまま残す。** 利用者が画像認証の文字を入れて「Agree to the terms of service」を押す', '');
  }

  if (WHICH === 'a8partnered') {
    // 提携中プログラムの名前・成果報酬・本人申込（セルフバック）可否を読む。A8_FROM/A8_TO で分割（1 タスク 5 分以内）
    await go('https://media-console.a8.net/program/list/partnered?pageNo=1&pageSize=100&sortKey=APPROVED_DATE&sortOrder=DESC');
    const ids = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href*="programId="]')].map((a) => (a.href.match(/programId=(s\d+)/) || [])[1]).filter(Boolean))]);
    const from = Number(process.env.A8_FROM || 0), to = Number(process.env.A8_TO || ids.length);
    lines.push(`- 提携中 ${ids.length} 件のうち ${from}〜${to - 1} 番目を読む`, '', '| programId | 名前 | 成果報酬 | 本人申込・ポイント | 提携日など |', '| --- | --- | --- | --- | --- |');
    for (const id of ids.slice(from, to)) {
      await p.goto(`https://media-console.a8.net/program/detail-partnered?programId=${id}`, { waitUntil: 'domcontentloaded', timeout: 20000 }).catch(() => {});
      await p.waitForTimeout(1800);
      const d = await p.evaluate(() => {
        const t = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean);
        const h = [...document.querySelectorAll('h1,h2,h3')].map((x) => x.innerText.replace(/\s+/g, ' ').trim()).filter((x) => x && !/プログラム詳細|広告リンク|提携/.test(x))[0] || '';
        const i = t.findIndex((x) => /^成果報酬$/.test(x));
        const reward = i >= 0 ? t.slice(i + 1, i + 3).join(' ') : (t.find((x) => /\d[\d,]*円|\d+(\.\d+)?\s*[%％]/.test(x)) || '');
        const alts = [...document.querySelectorAll('img[alt]')].map((x) => x.alt.trim()).filter((x) => /本人|ポイント|リスティング/.test(x));
        return { h, reward, alts: [...new Set(alts)].join('・') };
      }).catch(() => ({ h: '（読めない）', reward: '', alts: '' }));
      const c = (x) => (x || '').replace(/\|/g, '／').slice(0, 70);
      lines.push(`| ${id} | ${c(d.h)} | ${c(d.reward)} | ${c(d.alts)} | |`);
      ROWS.push({ id, name: d.h, reward: d.reward, self: /本人OK/.test(d.alts), point: /ポイントOK/.test(d.alts), listing: (d.alts.match(/リスティング[^・]*/) || [''])[0] });
    }
    lines.push('');
    // 収益化作戦室が読む JSON（2026-10-12）。名前と広告側の報酬だけ。自分の報酬額は出さない
    fs.writeFileSync(path.join(OUT, `${WHICH}.json`), JSON.stringify({ generated: new Date().toISOString(), total: ids.length, from, to, rows: ROWS }, null, 1));
  }

  if (WHICH === 'a8detail') {
    for (const id of (process.env.A8_IDS || '').split(',').filter(Boolean)) {
      await go(`https://media-console.a8.net/program/detail-not-partnered?programId=${id}`);
      const d = await p.evaluate(() => {
        const t = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean);
        const pick = (re) => t.filter((x) => re.test(x)).slice(0, 3).map((x) => x.slice(0, 80));
        const h = [...document.querySelectorAll('h1,h2,h3')].map((x) => x.innerText.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 4);
        return { title: document.title.slice(0, 80), h, join: pick(/即時|審査|提携方法|提携条件/), reward: pick(/成果報酬|円|%|％/), site: pick(/広告主|サイト名|プログラム名/) };
      });
      lines.push(`### ${id}`, `- 題名: ${d.title}`, `- 見出し: ${d.h.join(' ／ ')}`, `- 名前らしい行: ${d.site.join(' ／ ')}`, `- 提携方式: ${d.join.join(' ／ ')}`, `- 成果報酬: ${d.reward.join(' ／ ')}`, '');
    }
  }

  if (WHICH === 'vcbtn') {
    // **読むだけ（t290）。押さない。** t289 で「新規提携」が見つからなかったため、提携ボタンまわりの HTML を取る
    for (const [name, id] of [['Yahoo!トラベル', 2026983], ['ふるなび', 2142798]]) {
      await go(`https://aff.valuecommerce.ne.jp/ad/adDetail/${id}`);
      const els = await p.evaluate(() => [...document.querySelectorAll('*')].filter((e) => /^(新規提携|提携済み|提携待ち|未提携|再申請可)$/.test((e.innerText || e.value || '').trim())).map((e) => {
        const r = e.getBoundingClientRect(); const cs = getComputedStyle(e);
        return `${e.tagName.toLowerCase()} class="${(e.className || '').toString().slice(0, 50)}" 文字=${(e.innerText || '').trim()} 大きさ=${Math.round(r.width)}x${Math.round(r.height)} display=${cs.display} visibility=${cs.visibility} 親=${e.parentElement?.tagName.toLowerCase()}.${(e.parentElement?.className || '').toString().slice(0, 40)} 親display=${e.parentElement ? getComputedStyle(e.parentElement).display : ''}\n    html: ${e.outerHTML.replace(/\s+/g, ' ').slice(0, 220)}`; }).slice(0, 10));
      // 画面写真は撮らない（公開ブランチに会員名が写り込むため）
      lines.push(`## VC「${name}」 adDetail/${id}（${here()}・題名 ${(await p.title()).slice(0, 30)}）`, ...els.filter((x) => !NG.test(x)).map((x) => `- ${x}`), '');
    }
  }
  if (WHICH === 'applyvc2') {
    // **VC の提携申請・2 回目（t291）。利用者が 2026-10-12 に「4 社とも申請する」を選んだ。**
    // t290 で、詳細ページの「新規提携」は検索メニューの項目で申請ボタンではないと分かった。
    // 申請は広告一覧の行のチェック（make_new_ad[]）＋「チェックしたプログラムと一括提携」で行う。1 社ずつ送る。
    // 確認画面に費用の記載がある／送信ボタンが 1 つに決まらない → その社は送らない
    const vis = (e) => { const r = e.getBoundingClientRect(); const cs = getComputedStyle(e); return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none'; };
    const search = async (kw) => { await go(`https://aff.valuecommerce.ne.jp/ad/adList?${encodeURIComponent('ad_search_condition_form[keyword]')}=${encodeURIComponent(kw)}&${encodeURIComponent('ad_search_condition_form[appStatus]')}=`); };
    const rowInfo = (id) => p.evaluate((id) => {
      const a = document.querySelector(`a[href*="adDetail/${id}"], form[action*="adDetail/${id}"]`); if (!a) return null;
      let r = a; for (let i = 0; i < 10 && r.parentElement; i++) { r = r.parentElement; if (r.querySelector('input[name="make_new_ad[]"]') || r.tagName === 'TR') break; }
      const cb = r.querySelector('input[name="make_new_ad[]"]');
      const ls = r.querySelector('input[name="apply_link_switch[]"]');
      return { status: ((r.innerText || '').match(/提携中|提携済み?|提携待ち|未提携|審査中|即時提携|審査提携|自動提携|再申請可|否認/g) || []).join('・'),
        cb: cb ? { value: cb.value, disabled: cb.disabled, checked: cb.checked } : null, ls: ls ? { value: ls.value, disabled: ls.disabled } : null };
    }, id);
    for (const [name, kw, id] of [['Yahoo!トラベル', 'Yahoo!トラベル', 2026983], ['ふるなび', 'ふるなび', 2142798], ['一休.com', '一休', 179], ['じゃらんnet', 'じゃらん', 2021810]]) {
      await search(kw);
      const ri = await rowInfo(id);
      lines.push(`## VC「${name}」 adDetail/${id}`, `- 一覧の行: ${ri ? `状態「${ri.status || '表示なし'}」・チェック欄 ${ri.cb ? JSON.stringify(ri.cb) : 'なし'}・LinkSwitch 欄 ${ri.ls ? JSON.stringify(ri.ls) : 'なし'}` : '一覧に出ない'}`);
      if (!ri || !ri.cb || ri.cb.disabled) { lines.push('- チェックできない → 送らない', ''); continue; }
      await p.locator(`input[name="make_new_ad[]"][value="${ri.cb.value}"]`).first().check({ force: true, timeout: 5000 }).catch((e) => lines.push(`- ⚠️ チェックできない: ${String(e).split('\n')[0]}`));
      const bulk = p.locator('button, input[type=button], input[type=submit]').filter({ hasText: /チェックしたプログラムと一括提/ });
      const bn = await bulk.count();
      if (bn < 1) { lines.push('- 一括提携のボタンが無い → 送らない', ''); continue; }
      lines.push(`- 一括提携のボタン: 「${(await bulk.first().innerText().catch(() => '')).trim()}」（${bn} 個。先頭を押す）`);
      await bulk.first().click({ force: true, timeout: 5000 }).catch((e) => lines.push(`- ⚠️ 押せない: ${String(e).split('\n')[0]}`));
      await p.waitForTimeout(3500);
      const d = await p.evaluate((visSrc) => { const vis = eval(visSrc);
        const ds = [...document.querySelectorAll('[role=dialog], .modal, .modal-dialog, .ui-dialog, [class*=modal], [class*=dialog]')].filter(vis);
        const root = ds.length ? ds[ds.length - 1] : document.querySelector('main') || document.body;
        return { inDialog: ds.length > 0, url: location.href.replace(/\?.*$/, ''), text: root.innerText.replace(/\s+/g, ' ').trim().slice(0, 700),
          btns: [...root.querySelectorAll('a,button,input[type=submit],input[type=button]')].filter(vis).map((b) => (b.innerText || b.value || '').trim()).filter(Boolean).slice(0, 14) }; }, vis.toString());
      lines.push(`- 押した後: ${d.inDialog ? 'ダイアログ' : '画面'}（${d.url}）`, `  - 文: ${NG.test(d.text) ? '（会員情報を含むので伏せる）' : d.text}`, `  - ボタン: ${d.btns.join(' / ')}`);
      if (/有料|料金|手数料|費用|課金|支払/.test(d.text)) { lines.push('- ⛔ 費用に関する記載がある → 送らない', ''); continue; }
      const sendRe = /^(提携申請(する)?|申請する|提携する|一括提携(申請)?(する)?|提携を申請する|申し込む|OK|はい|送信|確定|同意して申請)$/;
      const scope = d.inDialog ? '[role=dialog] :is(a,button,input[type=submit],input[type=button]):visible, .modal :is(a,button,input[type=submit],input[type=button]):visible, [class*=modal] :is(a,button,input[type=submit],input[type=button]):visible, [class*=dialog] :is(a,button,input[type=submit],input[type=button]):visible' : 'a:visible, button:visible, input[type=submit]:visible, input[type=button]:visible';
      const sb = p.locator(scope).filter({ hasText: sendRe });
      const cnt = await sb.count();
      if (cnt !== 1) { lines.push(`- ⛔ 送信ボタンが ${cnt} 個（1 個に決まらない）→ 送らない`, ''); await p.keyboard.press('Escape').catch(() => {}); continue; }
      lines.push(`- 送信: 「${(await sb.first().innerText().catch(() => '')).trim()}」を押す`);
      await sb.first().click({ timeout: 5000 }).catch((e) => lines.push(`- ⚠️ 押せない: ${String(e).split('\n')[0]}`));
      await p.waitForTimeout(4000);
      const after = await p.evaluate(() => (document.body.innerText.match(/[^\n]*(提携|申請|完了|受け付け|エラー)[^\n]*/g) || []).map((x) => x.trim().slice(0, 90)).slice(0, 6));
      lines.push(...after.filter((x) => !NG.test(x)).map((x) => `- 送った直後: ${x}`));
      await search(kw);
      const ri2 = await rowInfo(id);
      lines.push(`- **送った後の一覧の行: 状態「${ri2 ? ri2.status || '表示なし' : '一覧に出ない'}」・チェック欄 ${ri2 && ri2.cb ? JSON.stringify(ri2.cb) : 'なし'}**`, '');
    }
  }
  if (WHICH === 'applyvc') {
    // **VC の提携申請（t289）。利用者が 2026-10-12 に「4 社とも申請する」を選んだ。**
    // 確認画面を読んでから送る。費用・有料・想定外の項目が見えたら、その社は送らずに止まる
    const vis = (e) => { const r = e.getBoundingClientRect(); const cs = getComputedStyle(e); return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none'; };
    const status = () => p.evaluate((visSrc) => { const vis = eval(visSrc);
      return [...document.querySelectorAll('a,button,span,div')].filter((e) => e.children.length === 0 && vis(e)).map((e) => (e.innerText || '').trim()).filter((x) => /^(新規提携|提携済み|提携待ち|未提携|再申請可|審査中|提携中)$/.test(x)).slice(0, 4).join(' ／ ') || '表示なし'; }, vis.toString());
    const dialog = () => p.evaluate((visSrc) => { const vis = eval(visSrc);
      const ds = [...document.querySelectorAll('[role=dialog], .modal, .modal-dialog, .ui-dialog, [class*=modal], [class*=dialog], [class*=popup]')].filter(vis);
      const root = ds.length ? ds[ds.length - 1] : null; if (!root) return null;
      return { text: root.innerText.replace(/\s+/g, ' ').trim().slice(0, 700),
        selects: [...root.querySelectorAll('select')].map((s) => ({ name: s.name, opts: [...s.options].map((o) => o.text.trim()) })),
        radios: [...root.querySelectorAll('input[type=radio],input[type=checkbox]')].map((r) => `${r.type}:${r.name}:${(r.closest('label,li,tr,div')?.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 40)}${r.checked ? '(選択済)' : ''}`).slice(0, 10),
        btns: [...root.querySelectorAll('a,button,input[type=submit],input[type=button]')].filter(vis).map((b) => (b.innerText || b.value || '').trim()).filter(Boolean).slice(0, 10) }; }, vis.toString());
    for (const [name, id] of [['Yahoo!トラベル', 2026983], ['ふるなび', 2142798], ['一休.com', 179], ['じゃらんnet', 2021810]]) {
      await go(`https://aff.valuecommerce.ne.jp/ad/adDetail/${id}`);
      lines.push(`## VC「${name}」 adDetail/${id}`, `- 申請前の状態: ${await status()}`);
      const btn = p.locator('a:visible, button:visible').filter({ hasText: /^\s*新規提携\s*$/ }).first();
      if (!(await btn.count())) { lines.push('- 「新規提携」ボタンが見えない → 送らない', ''); continue; }
      await btn.click({ timeout: 5000 }).catch((e) => lines.push(`- ⚠️ 押せない: ${String(e).split('\n')[0]}`));
      await p.waitForTimeout(3000);
      const d = await dialog();
      if (!d) { lines.push(`- 確認画面が見つからない（URL ${here()}）→ 送らない`, ''); continue; }
      lines.push(`- 確認画面の文: ${NG.test(d.text) ? '（伏せる）' : d.text}`, `- 選択欄: ${d.selects.map((s) => `${s.name}〔${s.opts.filter((o) => !NG.test(o)).join('|')}〕`).join(' / ') || 'なし'}`, `- チェック欄: ${d.radios.filter((x) => !NG.test(x)).join(' / ') || 'なし'}`, `- ボタン: ${d.btns.join(' / ')}`);
      if (/有料|料金|手数料|費用|課金|支払/.test(d.text)) { lines.push('- ⛔ 費用に関する記載がある → 送らない', ''); await p.keyboard.press('Escape').catch(() => {}); continue; }
      // サイトの選択欄があれば、ブログ（daily-hack）を選ぶ。見つからなければ送らない
      let ok = true;
      for (const s of d.selects) {
        const opt = s.opts.find((o) => /daily-hack|デイリーハック|あんたバカ/i.test(o));
        if (opt) await p.locator(`select[name="${s.name}"]:visible`).first().selectOption({ label: opt }).catch(() => { ok = false; });
        else if (s.opts.length > 1) { lines.push(`- ⛔ 選択欄 ${s.name} にブログが見つからない → 送らない`); ok = false; }
      }
      if (!ok) { lines.push(''); await p.keyboard.press('Escape').catch(() => {}); continue; }
      const sendRe = /^(提携申請(する)?|申請する|提携する|申し込む|申込む|提携を申請する|OK|はい|同意して申請)$/;
      const sb = p.locator('[role=dialog] :is(a,button,input[type=submit]):visible, .modal :is(a,button,input[type=submit]):visible, [class*=modal] :is(a,button,input[type=submit]):visible, [class*=dialog] :is(a,button,input[type=submit]):visible')
        .filter({ hasText: sendRe });
      const cnt = await sb.count();
      if (cnt !== 1) { lines.push(`- ⛔ 送信ボタンが ${cnt} 個（1 個でない）→ 送らない`, ''); await p.keyboard.press('Escape').catch(() => {}); continue; }
      lines.push(`- 送信: 「${(await sb.first().innerText().catch(() => '')).trim()}」を押す`);
      await sb.first().click({ timeout: 5000 }).catch((e) => lines.push(`- ⚠️ 押せない: ${String(e).split('\n')[0]}`));
      await p.waitForTimeout(4000);
      const after = await p.evaluate(() => (document.body.innerText.match(/[^\n]*(提携|申請|完了|エラー)[^\n]*/g) || []).map((x) => x.trim().slice(0, 80)).slice(0, 5));
      lines.push(...after.filter((x) => !NG.test(x)).map((x) => `- 押した直後: ${x}`));
      await go(`https://aff.valuecommerce.ne.jp/ad/adDetail/${id}`);
      lines.push(`- **申請後の状態: ${await status()}**`, '');
    }
  }
  if (WHICH === 'applyprep3') {
    // **読むだけ・3 回目（t288）。押さない・送らない。** t287 でもキーワードが効かず、どの社名でも同じ一覧だった。
    // 検索フォームの送り方（action・method・ボタン）を読み、URL の問い合わせで引けるかを試す
    await go('https://aff.valuecommerce.ne.jp/ad/adList');
    const forms = await p.evaluate(() => [...document.querySelectorAll('form')].map((f) => ({
      action: (f.getAttribute('action') || '').replace(/\?.*$/, ''), method: f.method, id: f.id, cls: f.className.slice(0, 40),
      kw: !!f.querySelector('[name="ad_search_condition_form[keyword]"]'),
      names: [...f.querySelectorAll('[name]')].map((e) => e.name).filter((n) => !/_token/.test(n)).slice(0, 30),
      btns: [...f.querySelectorAll('button,input[type=submit],input[type=button],a.btn')].map((b) => `${b.tagName}:${(b.innerText || b.value || '').trim().slice(0, 15)}:${b.type || ''}:${b.id || ''}`).slice(0, 8) })));
    lines.push('## VC 広告検索のフォーム', ...forms.map((f) => `- form action=${f.action} method=${f.method} id=${f.id} class=${f.cls} keyword欄=${f.kw}\n  - 項目: ${f.names.join(' / ')}\n  - ボタン: ${f.btns.join(' / ')}`), '');
    for (const kw of ['ふるなび', '一休', 'じゃらん']) {
      const u = `https://aff.valuecommerce.ne.jp/ad/adList?${encodeURIComponent('ad_search_condition_form[keyword]')}=${encodeURIComponent(kw)}&${encodeURIComponent('ad_search_condition_form[appStatus]')}=`;
      await go(u);
      const val = await p.locator('input[name="ad_search_condition_form[keyword]"]').first().inputValue().catch(() => '読めない');
      const rows = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href*="adDetail"]')].map((a) => `${(a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60)} — ${a.href.replace(/\?.*$/, '')}`))].filter((x) => !x.startsWith(' —')).slice(0, 6));
      lines.push(`## VC GET 検索「${kw}」（欄に入った値: ${val}）`, ...rows.filter((x) => !NG.test(x)).map((x) => `- ${x}`), '');
    }
    // Yahoo!トラベル（ホームに出ていた広告）の詳細：提携の方式とボタン
    await go('https://aff.valuecommerce.ne.jp/ad/adDetail/2026983');
    const yt = await p.evaluate(() => { const t = document.body.innerText.replace(/[ \t]+/g, ' ');
      return { title: document.title, btns: [...document.querySelectorAll('a,button,input[type=submit],input[type=button]')].map((b) => (b.innerText || b.value || '').trim()).filter((x) => /提携|申請|申込/.test(x)).slice(0, 8),
        cond: (t.match(/[^\n]*(即時提携|審査|自動提携|提携中|提携済|SNS|Twitter|X（|禁止)[^\n]*/g) || []).map((x) => x.trim().slice(0, 110)).slice(0, 12) }; });
    lines.push('## VC 詳細「Yahoo!トラベル」 adDetail/2026983', `- 題名: ${yt.title.slice(0, 50)}`, `- 提携・申請のボタン: ${yt.btns.join(' ／ ') || 'なし'}`, ...yt.cond.filter((x) => !NG.test(x)).map((x) => `- ${x}`), '');
    // VC「サイトの追加」画面の入力項目（送らない）
    await go('https://aff.valuecommerce.ne.jp/account/siteAdd');
    const sa = await p.evaluate(() => [...document.querySelectorAll('input,select,textarea')].filter((e) => e.type !== 'hidden').map((e) => {
      const lab = (e.id && document.querySelector(`label[for="${e.id}"]`)?.innerText) || e.closest('tr,dl,div')?.innerText || '';
      const opts = e.tagName === 'SELECT' ? [...e.options].map((o) => o.text.trim()).slice(0, 12).join('|') : '';
      return `${e.tagName.toLowerCase()}[${e.type}] ${e.name} ← ${lab.replace(/\s+/g, ' ').trim().slice(0, 60)}${opts ? ` 〔${opts}〕` : ''}`; }).slice(0, 30));
    lines.push('## VC サイトの追加（入力項目・送らない）', `- 開いた画面: ${here()}（${(await p.title()).slice(0, 40)}）`, ...sa.filter((x) => !NG.test(x)).map((x) => `- ${x}`), '');
    // A8：トップの全リンク（メニューの場所が分からないため絞らない）
    await go('https://media-console.a8.net/');
    const a8 = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href]')].map((a) => `${(a.innerText || a.getAttribute('aria-label') || a.title || '').replace(/\s+/g, ' ').trim().slice(0, 30)} — ${a.href.replace(/\?.*$/, '')}`))].slice(0, 80));
    lines.push('## A8 トップの全リンク', `- 開いた画面: ${here()}`, ...a8.filter((x) => !NG.test(x)).map((x) => `- ${x}`), '');
  }
  if (WHICH === 'applyprep2') {
    // **申請・登録の前に読むだけ（2 回目・t287）。押さない・送らない。**
    // t286 では VC の検索に前回の「提携済み」の絞り込みが残り、4 社が 1 件も出なかった。提携状態を「未提携（N）」にして探し直す
    const found = {};
    for (const kw of ['ふるなび', '一休', 'じゃらん', 'Yahoo!トラベル']) {
      await go('https://aff.valuecommerce.ne.jp/ad/adList');
      await p.locator('input[type=radio][name="ad_search_condition_form[appStatus]"][value=N]').check({ force: true, timeout: 5000 }).catch((e) => lines.push(`- ⚠️ 未提携を選べない: ${String(e).split('\n')[0]}`));
      await p.locator('input[name="ad_search_condition_form[keyword]"]').first().fill(kw).catch((e) => lines.push(`- ⚠️ 入力できない: ${String(e).split('\n')[0]}`));
      const sub = p.locator('button:visible, input[type=submit]:visible').filter({ hasText: /検索/ }).first();
      if (await sub.count()) await sub.click({ timeout: 5000 }).catch(() => {}); else await p.locator('input[name="ad_search_condition_form[keyword]"]').first().press('Enter').catch(() => {});
      await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {}); await p.waitForTimeout(4000);
      const st = await p.locator('input[type=radio][name="ad_search_condition_form[appStatus]"]:checked').getAttribute('value').catch(() => '不明');
      const rows = await p.evaluate(() => { const seen = new Set();
        return [...document.querySelectorAll('a[href*="adDetail"]')].map((a) => {
          let r = a; for (let i = 0; i < 6 && r.parentElement; i++) { r = r.parentElement; if (r.tagName === 'TR' || (r.innerText || '').length > 160) break; }
          return [(a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 70), ((r.innerText || '').match(/提携中|提携済み?|提携待ち|未提携|審査|即時提携|自動提携/g) || []).join('・'), a.href.replace(/\?.*$/, '')];
        }).filter(([t, , h]) => t && !seen.has(h) && seen.add(h)).slice(0, 8); });
      lines.push(`## VC「${kw}」（提携状態の選択: ${st}）`, ...rows.filter(([t]) => !NG.test(t)).map(([t, s2, h]) => `- ${t}［${s2 || '表示なし'}］ — ${h}`), '');
      const hit = rows.find(([t]) => t.includes(kw.replace('!', '！')) || t.includes(kw));
      if (hit) found[kw] = hit[2];
    }
    // 見つかった広告の詳細：提携の条件とボタン（押さない）
    for (const [kw, u] of Object.entries(found)) {
      await go(u);
      const info = await p.evaluate(() => {
        const t = document.body.innerText.replace(/[ \t]+/g, ' ');
        const pick = (re) => (t.match(re) || [''])[0].slice(0, 120);
        return { title: document.title, btns: [...document.querySelectorAll('a,button,input[type=submit],input[type=button]')].map((b) => (b.innerText || b.value || '').trim()).filter((x) => /提携|申請|申込/.test(x)).slice(0, 8),
          cond: [pick(/提携(条件|審査)[^\n]{0,80}/), pick(/(即時|自動|審査)提携[^\n]{0,60}/), pick(/成果報酬[^\n]{0,80}/), pick(/禁止[^\n]{0,80}/), pick(/SNS[^\n]{0,80}/)].filter(Boolean) };
      });
      lines.push(`## VC 詳細「${kw}」 ${u}`, `- 題名: ${info.title.slice(0, 50)}`, `- 提携・申請のボタン: ${info.btns.join(' ／ ') || 'なし'}`, ...info.cond.filter((x) => !NG.test(x)).map((x) => `- ${x}`), '');
    }
    // VC のサイト設定（メディア登録）と A8 の登録情報まわり
    await go('https://aff.valuecommerce.ne.jp/account/siteManage');
    lines.push('## VC サイト設定', `- 開いた画面: ${here()}（${(await p.title()).slice(0, 40)}）`,
      ...(await links(/サイト|追加|登録|新規|SNS/)).filter(([t]) => !NG.test(t)).map(([t, h]) => `- リンク: ${t} — ${String(h).replace(/\?.*$/, '')}`),
      ...(await p.evaluate(() => [...document.querySelectorAll('table tr')].slice(0, 12).map((r) => r.innerText.replace(/\s+/g, ' ').trim().slice(0, 100)))).filter((x) => x && !NG.test(x) && !/\d{6,}/.test(x)).map((x) => `- 行: ${x}`), '');
    await go('https://media-console.a8.net/');
    lines.push('## A8 トップのリンク（サイト・登録・設定・アカウント）', `- 開いた画面: ${here()}`,
      ...(await links(/サイト|登録|設定|アカウント|会員情報|メディア/)).filter(([t]) => !NG.test(t)).map(([t, h]) => `- ${t} — ${String(h).replace(/\?.*$/, '')}`), '');
  }
  if (WHICH === 'applyprep') {
    // **申請・登録の前に、画面を読むだけ**（t286・2026-10-12）。押さない・送らない。
    // ① バリューコマースで 4 社を名前で探し、広告の行・提携の状態・申請ボタンを読む
    // ② A8・もしも・バリューコマースの「メディア（サイト）登録」の画面を、メニューのリンクから辿って読む
    for (const kw of ['ふるなび', '一休', 'じゃらん', 'Yahoo!トラベル']) {
      await go('https://aff.valuecommerce.ne.jp/ad/adList');
      const inputs = await p.evaluate(() => [...document.querySelectorAll('form input[type=text], form input[type=search], form input:not([type])')].map((e) => e.name).filter(Boolean));
      lines.push(`## VC「${kw}」`, `- 検索欄の候補: ${inputs.join(' / ') || 'なし'}`);
      const name = inputs.find((n) => /keyword|word|name|query|search/i.test(n)) || inputs[0];
      if (!name) continue;
      await p.locator(`input[name="${name}"]`).first().fill(kw).catch((e) => lines.push(`- ⚠️ 入力できない: ${String(e).split('\n')[0]}`));
      const sub = p.locator('button:visible, input[type=submit]:visible').filter({ hasText: /検索/ }).first();
      if (await sub.count()) await sub.click({ timeout: 5000 }).catch(() => {}); else await p.locator(`input[name="${name}"]`).first().press('Enter').catch(() => {});
      await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {}); await p.waitForTimeout(4000);
      const rows = await p.evaluate(() => { const seen = new Set();
        return [...document.querySelectorAll('a[href*="adDetail"]')].map((a) => {
          let r = a; for (let i = 0; i < 6 && r.parentElement; i++) { r = r.parentElement; if (r.tagName === 'TR' || (r.innerText || '').length > 160) break; }
          const btns = [...r.querySelectorAll('a,button,input[type=submit],input[type=button]')].map((b) => (b.innerText || b.value || '').trim()).filter((t) => /提携|申請|申込/.test(t));
          return [(a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60), ((r.innerText || '').match(/提携中|提携済み?|提携待ち|未提携|審査中|即時提携|提携申請|自動提携/g) || []).join('・'), btns.join('／'), a.href.replace(/\?.*$/, '')];
        }).filter(([t, , , h]) => t && !seen.has(h) && seen.add(h)).slice(0, 8); });
      lines.push(`- 結果: ${here()}（${rows.length} 件）`, ...rows.filter(([t]) => !NG.test(t)).map(([t, st, b, h]) => `  - ${t}［${st || '状態の表示なし'}］ボタン: ${b || 'なし'} — ${h}`), '');
    }
    const media = [['A8', 'https://media-console.a8.net/'], ['もしも', 'https://af.moshimo.com/af/shop/index'], ['VC', 'https://aff.valuecommerce.ne.jp/']];
    for (const [nm, top] of media) {
      await go(top);
      const ls = await links(/サイト|メディア|媒体/);
      lines.push(`## ${nm} のメディア登録まわり`, `- 開いた画面: ${here()}`, ...ls.filter(([t]) => !NG.test(t)).map(([t, h]) => `  - ${t} — ${String(h).replace(/\?.*$/, '')}`));
      const reg = ls.find(([t]) => /登録|追加|新規/.test(t) && /サイト|メディア|媒体/.test(t)) || ls.find(([t]) => /一覧|管理/.test(t));
      if (reg && /^https?:/.test(reg[1])) {
        await go(reg[1]);
        const f = await p.evaluate(() => [...document.querySelectorAll('form input, form select, form textarea')].slice(0, 40).map((e) => `${e.tagName.toLowerCase()}[${e.type || ''}] name=${e.name} ${(e.closest('label,tr,dl,div') || {}).innerText?.replace(/\s+/g, ' ').trim().slice(0, 40) || ''}`));
        lines.push(`- 「${reg[0]}」の画面: ${here()}（${(await p.title()).slice(0, 40)}）`, ...f.filter((x) => !NG.test(x)).map((x) => `    - ${x}`), ...(await links(/登録|追加|申請|新規/)).filter(([t]) => !NG.test(t)).map(([t, h]) => `    - リンク: ${t} — ${String(h).replace(/\?.*$/, '')}`));
      }
      lines.push('');
    }
  }
  if (WHICH === 'others') {
    // **A8 以外の提携中の案件を JSON に書き出す**（作戦室の「ASP と案件」・2026-10-12）。読むだけ。
    // バリューコマースは vc3 と同じ「提携済み（A）」の絞り込み、もしもは「提携中」の一覧（apply_status=2・asp-sync の実測）。
    const out = { generated: new Date().toISOString(), vc: [], moshimo: [] };
    await go('https://aff.valuecommerce.ne.jp/ad/adList');
    await p.locator('input[type=radio][name="ad_search_condition_form[appStatus]"][value=A]').check({ force: true, timeout: 5000 }).catch((e) => lines.push(`- ⚠️ VC: 提携済みを選べない: ${String(e).split('\n')[0]}`));
    const sub = p.locator('button:visible, input[type=submit]:visible').filter({ hasText: /検索/ }).first();
    if (await sub.count()) await sub.click({ timeout: 5000 }).catch(() => {}); else await p.locator('form:has(input[name="ad_search_condition_form[appStatus]"])').first().evaluate((f) => f.submit()).catch(() => {});
    await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {}); await p.waitForTimeout(5000);
    out.vc = await p.evaluate(() => { const seen = new Set();
      return [...document.querySelectorAll('a[href*="adDetail"]')].map((a) => {
        let r = a; for (let i = 0; i < 6 && r.parentElement; i++) { r = r.parentElement; if (r.tagName === 'TR' || (r.innerText || '').length > 120) break; }
        const txt = (r.innerText || '').replace(/\s+/g, ' ');
        return { name: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60), reward: (txt.match(/[0-9,.]+\s*(円|%)[^ ]{0,12}/) || [''])[0], href: a.href.replace(/\?.*$/, '') };
      }).filter((x) => x.name && !seen.has(x.href) && seen.add(x.href)); });
    await go('https://af.moshimo.com/af/shop/promotion/search?apply_status=2');
    lines.push(`- もしも: 開いた画面 ${here()}（${(await p.title()).slice(0, 40)}）`);
    out.moshimo = await p.evaluate(() => { const seen = new Set();
      return [...document.querySelectorAll('a[href*="promotion"]')].filter((a) => /promotion\/(detail|\d)|promotion_id=|p_id=/.test(a.href) && !/search/.test(a.href)).map((a) => {
        let r = a; for (let i = 0; i < 6 && r.parentElement; i++) { r = r.parentElement; if ((r.innerText || '').length > 150) break; }
        const txt = (r.innerText || '').replace(/\s+/g, ' ');
        return { name: (a.innerText || a.title || '').replace(/\s+/g, ' ').trim().slice(0, 60), reward: (txt.match(/[0-9,.]+\s*(円|%)[^ ]{0,12}/) || [''])[0], href: a.href.replace(/\?.*$/, '') };
      }).filter((x) => x.name && !seen.has(x.href) && seen.add(x.href)); });
    for (const k of ['vc', 'moshimo']) out[k] = out[k].filter((x) => !NG.test(x.name));
    lines.push(`- バリューコマース 提携済み: ${out.vc.length} 件`, ...out.vc.map((x) => `  - ${x.name}｜${x.reward}`), `- もしも 提携中: ${out.moshimo.length} 件`, ...out.moshimo.map((x) => `  - ${x.name}｜${x.reward}`));
    if (!out.moshimo.length) lines.push('', '### もしもの画面のリンク（件数 0 のときの手がかり）', ...(await p.evaluate(() => [...document.querySelectorAll('a')].map((a) => (a.innerText || '').trim().slice(0, 30) + ' — ' + a.href.replace(/\?.*$/, '')).filter((t) => /promotion/.test(t)).slice(0, 25))).map((t) => `  - ${t}`));
    fs.writeFileSync(path.join(OUT, 'others.json'), JSON.stringify(out, null, 1));
  }
  if (WHICH === 'vc2' || WHICH === 'vc3') {
    await go('https://aff.valuecommerce.ne.jp/ad/adList');
    if (WHICH === 'vc3') {
      // 「提携済み」（appStatus=A）で絞り込んで検索する
      await p.locator('input[type=radio][name="ad_search_condition_form[appStatus]"][value=A]').check({ force: true, timeout: 5000 }).catch((e) => lines.push(`- ⚠️ 提携済みを選べない: ${String(e).split('\n')[0]}`));
      const sub = p.locator('button:visible, input[type=submit]:visible').filter({ hasText: /検索/ }).first();
      if (await sub.count()) await sub.click({ timeout: 5000 }).catch(() => {}); else await p.locator('form:has(input[name="ad_search_condition_form[appStatus]"])').first().evaluate((f) => f.submit()).catch(() => {});
      await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {});
      await p.waitForTimeout(5000);
      lines.push(`- 「提携済み」で検索したあとの画面: ${here()}`, `- 選ばれている提携状態: ${await p.locator('input[type=radio][name="ad_search_condition_form[appStatus]"]:checked').getAttribute('value').catch(() => '不明')}`, '');
    }
    lines.push(`- 開いた画面: ${here()}（${(await p.title()).slice(0, 40)}）`, '');
    const f = await p.evaluate(() => [...document.querySelectorAll('select, input[type=radio], input[type=checkbox]')].slice(0, 30)
      .map((e) => e.tagName === 'SELECT' ? `select[name=${e.name}]: ${[...e.options].map((o) => `${o.value}=${o.text.trim()}`).join(' / ').slice(0, 200)}`
        : `${e.type}[name=${e.name}] value=${e.value} ${(e.closest('label') || e.parentElement || {}).innerText?.trim().slice(0, 20) || ''}${e.checked ? ' ✔' : ''}`));
    // **選択肢の文に会社名・契約 ID が出る**（2026-10-11 に出してしまった）。NG の行は落とす
    lines.push('## 絞り込みの欄', '', ...f.filter((x) => !NG.test(x) && !/\d{5,}/.test(x.replace(/value=\d+x\d+/g, ''))).map((x) => `- ${x}`), '');
    lines.push('## 「提携」を含むリンク・ボタン', '', ...(await links(/提携/)).map(([t, h]) => `- ${t} — ${h}`), '');
    const rows = await p.evaluate(() => {
      const seen = new Set();
      return [...document.querySelectorAll('a[href*="adDetail"]')].map((a) => {
        let r = a; for (let i = 0; i < 6 && r.parentElement; i++) { r = r.parentElement; if (r.tagName === 'TR' || (r.innerText || '').length > 120) break; }
        return [(a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60), ((r.innerText || '').match(/提携中|提携済み?|提携待ち|未提携|審査中|即時提携|提携申請/g) || []).join('・'), a.href.replace(/\?.*$/, '')];
      }).filter(([t, , h]) => t && !seen.has(h) && seen.add(h));
    });
    lines.push(`## 広告の行（${rows.length} 件）`, '', ...rows.filter(([t]) => !NG.test(t)).map(([t, st, h]) => `- ${t.replace(/\|/g, '／')}［${st || '表示なし'}］ — ${h}`), '');
  }
} catch (e) { lines.push(`- ⚠️ 失敗: ${String(e).slice(0, 200)}`); }
fs.writeFileSync(path.join(OUT, `${WHICH}.md`), lines.join('\n') + '\n');
console.log(lines.join('\n').slice(0, 2500));
await p.close().catch(() => {});
process.exit(0);
