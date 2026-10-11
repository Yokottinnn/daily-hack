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
    lines.push('## 画面の行（先頭 60）', '', '```text', ...raw.text.filter((x) => !NG.test(x) && !/@/.test(x)), '```', '', '## 画面のリンク', '', ...raw.links.filter((x) => !/@/.test(x)).map((x) => `- ${x}`), '');
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
