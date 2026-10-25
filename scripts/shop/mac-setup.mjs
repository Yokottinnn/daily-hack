// 3 店ボタンの Mac 側の準備（affiliate が担当・2026-10-25 利用者の指示で blog3 から引き取った）。LLM 不使用・$0。
//   SHOP_SETUP=rakuten  … 楽天ウェブサービスのアプリ一覧から Access Key を読み Keychain（dailyhack-rakuten-ws / accessKey）に入れ、API が通るか 1 回だけ試す
//   SHOP_SETUP=moshimo  … もしもで「Amazon」を検索し、出たプロモーションの行とボタンを読む（**押さない**）
//   SHOP_SETUP=yahoo    … Yahoo! デベロッパーネットワークのアプリ管理・登録の画面を読む（**送らない**）
// ログインは asp-sync.mjs が保っている Chrome（CDP 18810）を使う。**鍵・会員名・報酬額は出さない**（鍵は文字数だけ）。
// 出力: $OPS_REPORT_DIR/shop-setup/<SHOP_SETUP>.md（公開ブランチ ops/heartbeat に載る）
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const PW_DIR = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')]
  .find((d) => fs.existsSync(path.join(d, 'playwright-core')));
if (!PW_DIR) { console.log('playwright-core が無い'); process.exit(0); }
const { chromium } = createRequire(path.join(PW_DIR, 'x.js'))('playwright-core');
const WHICH = process.env.SHOP_SETUP || '';
const OUT = path.join(process.env.OPS_REPORT_DIR || '/tmp', 'shop-setup');
fs.mkdirSync(OUT, { recursive: true });
const NG = /契約者|振込|口座|氏名|会社|様$|さん$|Welcome|ようこそ|こんにちは|@|報酬/i;
const mask = (x) => String(x).replace(/[A-Za-z0-9_\-]{16,}/g, (m) => `［${m.length}文字・伏せた］`);
const lines = [`# 3 店ボタンの Mac 側の準備: ${WHICH}（scripts/shop/mac-setup.mjs）`, '', `生成: **${new Date().toISOString()}**`, ''];

// t338: もしもの「提携申請する」は JavaScript の確認ダイアログを出し、受け答えに失敗すると Playwright が落ちた。落ちても記録を残す
process.on('unhandledRejection', (e) => { lines.push(`- ⚠️ 未処理のエラー: ${String(e && e.message || e).split('\n')[0].slice(0, 160)}`); });
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const DIALOGS = [];
p.on('dialog', async (d) => { DIALOGS.push(`${d.type()}「${String(d.message()).slice(0, 120)}」`); if (WHICH === 'moshimo-apply') await d.accept().catch(() => {}); else await d.dismiss().catch(() => {}); });
const go = async (u) => { await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch((e) => lines.push(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`)); await p.waitForTimeout(3500); };
const here = () => { try { const u = new URL(p.url()); return u.origin + u.pathname; } catch { return p.url(); } };
const vis = () => p.evaluate(() => {
  const v = (e) => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
  const lab = (e) => ((e.closest('label') || {}).innerText || (e.id && (document.querySelector(`label[for="${e.id}"]`) || {}).innerText) || e.placeholder || e.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 50);
  const fields = [...document.querySelectorAll('input, select, textarea')].filter((e) => v(e) && e.type !== 'hidden' && e.type !== 'password').slice(0, 40)
    .map((e) => `${e.tagName.toLowerCase()}[type=${e.type || ''} name=${e.name || ''}] 「${lab(e)}」${e.required ? ' 必須' : ''}${e.checked ? ' ✔' : ''}`);
  const btns = [...document.querySelectorAll('button, input[type=submit], a[role=button], [role=button]')].filter(v).map((x) => (x.innerText || x.value || '').replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 25);
  const heads = [...document.querySelectorAll('h1, h2, h3')].filter(v).map((h) => h.innerText.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 15);
  return { fields, btns, heads };
});
const dump = async (title) => {
  const d = await vis();
  lines.push(`## ${title}`, '', `- 画面: ${here()}（${mask((await p.title()).slice(0, 60))}）`, '',
    '見出し:', ...d.heads.filter((x) => !NG.test(x)).map((x) => `- ${mask(x)}`), '',
    '入力欄:', ...d.fields.filter((x) => !NG.test(x)).map((x) => `- ${mask(x)}`), '',
    'ボタン:', `- ${d.btns.filter((x) => !NG.test(x)).map(mask).join(' ／ ')}`, '');
};

try {
  if (WHICH === 'rakuten') {
    await go('https://webservice.rakuten.co.jp/app/list');
    // t332（2026-10-25）: アプリ一覧は「本人確認のし直し」（login.account.rakuten.com/session/upgrade）に飛ばされた。
    // asp-sync と同じ Keychain（dailyhack-asp-rakuten）の ID・パスワードで入り直す（値は出さない）
    if (/login\.account\.rakuten\.com/.test(p.url())) {
      const cred = aspCred('rakuten');
      lines.push(`- 本人確認の画面に飛ばされた（${here()}）。Keychain の ID・パスワード: ${cred ? 'ある' : '**無い**'}`);
      if (cred) {
        const pw = 'input[type=password]:visible';
        if (!(await p.locator(pw).count())) {
          const id = p.locator('input[type=text]:visible, input[type=email]:visible, input[name*=user]:visible').first();
          if ((await id.count()) && !(await id.inputValue().catch(() => 'x'))) { await id.fill(cred.user); }
          const next = p.getByRole('button', { name: /^(次へ|続ける|Next)$/ }).first();
          if (await next.count()) await next.click({ timeout: 5000 }).catch(() => {}); else await p.keyboard.press('Enter');
          await p.waitForTimeout(4500);
        }
        if (await p.locator(pw).count()) {
          await p.locator(pw).first().fill(cred.pass);
          await p.locator(pw).first().press('Enter').catch(() => {});
          await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {});
          await p.waitForTimeout(6000);
        }
        lines.push(`- 入り直したあとの画面: ${here()}`);
        if (!/webservice\.rakuten\.co\.jp/.test(p.url())) await go('https://webservice.rakuten.co.jp/app/list');
      }
    }
    lines.push(`- 画面: ${here()}`, '');
    // t294 で「Application ID / Access Key / Affiliate ID」の行がこの画面にあると分かっている
    const got = await p.evaluate(() => {
      const rows = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean);
      const val = (re) => { const i = rows.findIndex((x) => re.test(x)); if (i < 0) return ''; const same = rows[i].replace(re, '').replace(/^[\s:：]+/, '').trim(); return same || rows[i + 1] || ''; };
      return { app: val(/^(Application ID|アプリID)/i), key: val(/^(Access Key|アクセスキー)/i) };
    });
    // t333: 一覧には Access Key が出ない（「More Details」の先）。押して詳細を開いてから読む
    // t335: 一覧の Access Key は伏せ字（16 文字以上の英数でない）だったので、値が取れていなければ詳細へ進む
    if (!/[A-Za-z0-9_\-]{16,}/.test(got.key)) {
      // t334: getByText では押せなかった。ボタン・リンクの文字で探す
      const more = p.locator('a, button, [role=button], input[type=button], input[type=submit]').filter({ hasText: /More Details|詳細/ }).first();
      if (await more.count()) {
        await more.click({ timeout: 5000 }).catch(() => {});
        await p.waitForLoadState('domcontentloaded', { timeout: 15000 }).catch(() => {});
        await p.waitForTimeout(4000);
        lines.push(`- 「More Details」を押した: ${here()}`);
      } else lines.push('- 「More Details」が見つからない');
      {
        // 値が「表示」ボタンで隠れていれば押す（値そのものは出さない）
        const show = p.getByRole('button', { name: /^(Show|表示|表示する|Reveal)$/i });
        for (let i = 0; i < Math.min(await show.count(), 4); i++) await show.nth(i).click({ timeout: 3000 }).catch(() => {});
        await p.waitForTimeout(1500);
        Object.assign(got, await p.evaluate(() => {
          const rows = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean);
          const val = (re) => { const i = rows.findIndex((x) => re.test(x)); if (i < 0) return ''; const same = rows[i].replace(re, '').replace(/^[\s:：]+/, '').trim(); return same || rows[i + 1] || ''; };
          const inp = [...document.querySelectorAll('input')].map((e) => [((e.closest('tr,div,dl') || {}).innerText || '').slice(0, 40), e.value || '']);
          const fromInput = (re) => (inp.find(([l, v]) => re.test(l) && v) || [])[1] || '';
          // t336: 値は入力欄（type=password を含む）に入っている可能性。ラベルの近くの入力欄の値を全部見る
          const near = (re) => { for (const e of document.querySelectorAll('input, textarea, code, pre, span, td, dd')) { const lab = ((e.closest('tr,li,dl,div') || {}).innerText || '') + ' ' + (e.getAttribute('aria-label') || '') + ' ' + (e.name || '') + ' ' + (e.id || ''); const v = e.value || (e.tagName !== 'INPUT' && e.tagName !== 'TEXTAREA' ? e.textContent : '') || ''; if (re.test(lab) && /^[A-Za-z0-9_\-]{16,}$/.test(v.trim())) return v.trim(); } return ''; };
          return { app: val(/^(Application ID|アプリID)/i) || fromInput(/Application ID/i) || near(/Application ID|applicationId/i), key: near(/Access Key|accessKey|アクセスキー/i) || val(/^(Access Key|アクセスキー)/i) || fromInput(/Access Key/i),
            shape: [...document.querySelectorAll('input, textarea')].map((e) => `${e.tagName.toLowerCase()}[type=${e.type} name=${e.name} id=${e.id}] 値${(e.value || '').length}文字`).slice(0, 12) };
        }));
      }
    }
    const key = (got.key.match(/[A-Za-z0-9_\-]{16,}/) || [])[0] || '';
    const app = (got.app.match(/[A-Za-z0-9_\-]{16,}/) || [])[0] || '';
    lines.push(`- Application ID: ${app ? `${app.length} 文字（Keychain の値と${app === keychain('applicationId') ? '同じ' : '**違う**'}）` : '見つからない'}`);
    if (key) {
      try { execFileSync('/usr/bin/security', ['add-generic-password', '-U', '-s', 'dailyhack-rakuten-ws', '-a', 'accessKey', '-w', key]); lines.push(`- Access Key を Keychain（dailyhack-rakuten-ws / accessKey）に入れた（${key.length} 文字）`); }
      catch (e) { lines.push(`- ⚠️ Keychain に入れられない: ${String(e).slice(0, 80)}`); }
    } else lines.push('- Access Key が画面に見つからない（「表示」ボタンで隠れている可能性）。ボタン一覧を下に出す');
    if (!key) {
      lines.push('- 入力欄の形（値は文字数だけ）:', ...((got.shape || []).map((x) => `  - ${x}`)));
      // t337: 入力欄には無かった。「Access Key」の行のまわりの HTML の形を出す（16 文字以上の英数は伏せる）
      const html = await p.evaluate(() => { const el = [...document.querySelectorAll('*')].filter((e) => e.children.length < 6 && /Access Key/i.test(e.textContent || '')).sort((a, b) => (a.textContent || '').length - (b.textContent || '').length)[0];
        let box = el; for (let i = 0; i < 3 && box && box.parentElement; i++) box = box.parentElement; return box ? box.outerHTML.replace(/\s+/g, ' ').slice(0, 2500) : ''; });
      lines.push('- 「Access Key」の行のまわりの HTML（値は伏せる）:', '```html', mask(html).replace(/[●•*]{6,}/g, '［伏せ字］'), '```');
      // t338: カードの頭しか見えなかった。カード全体の文字と、カードの中のボタン（文字の無いアイコンも aria-label・title で）を出す
      const card = await p.evaluate(() => { const c = [...document.querySelectorAll('.card')].find((e) => /dailyhack/.test(e.textContent || '')); if (!c) return null;
        return { text: (c.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).slice(0, 40), btns: [...c.querySelectorAll('button, a, [role=button]')].map((e) => `${e.tagName.toLowerCase()} 「${(e.innerText || '').trim().slice(0, 30)}」 aria=${e.getAttribute('aria-label') || ''} title=${e.getAttribute('title') || ''} data=${Object.keys(e.dataset).join(',')}`).slice(0, 20) }; });
      if (card) lines.push('- カードの文字（値は伏せる）:', ...card.text.map((x) => `  - ${mask(x).replace(/[●•*]{6,}/g, '［伏せ字］')}`), '- カードの中のボタン:', ...card.btns.map((x) => `  - ${mask(x)}`));
      // t339: Access Key は伏せ字で、横に文字の無いアイコンのボタンがある（表示の切り替え）。押してから読み直す
      const icons = p.locator('.card').filter({ hasText: 'dailyhack' }).locator('button').filter({ hasNotText: /\S/ });
      const n = await icons.count();
      for (let i = 0; i < n; i++) { await icons.nth(i).click({ timeout: 3000 }).catch(() => {}); await p.waitForTimeout(400); }
      await p.waitForTimeout(1500);
      const after = await p.evaluate(() => { const c = [...document.querySelectorAll('.card')].find((e) => /dailyhack/.test(e.textContent || '')); const rows = c ? (c.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean) : []; const i = rows.findIndex((x) => /^Access Key$/i.test(x)); return i >= 0 ? rows[i + 1] || '' : ''; });
      let k2 = (after.match(/^[A-Za-z0-9_\-]{16,}$/) || [])[0] || '';
      // t341: アイコンを押しても伏せ字のまま。アイコンはコピーのボタンらしいので、クリップボードから読む（値は Keychain に入れるだけ）
      if (!k2) {
        await ctx.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: 'https://webservice.rakuten.co.jp' }).catch((e) => lines.push(`- クリップボードの許可: ${String(e).slice(0, 80)}`));
        const appIdNow = keychain('applicationId'); const seen = [];
        for (let i = 0; i < n; i++) {
          await p.evaluate(() => navigator.clipboard.writeText('')).catch(() => {});
          await icons.nth(i).click({ timeout: 3000 }).catch(() => {});
          await p.waitForTimeout(600);
          const v = String(await p.evaluate(() => navigator.clipboard.readText()).catch(() => '') || '').trim();
          seen.push(/^[A-Za-z0-9_\-]{16,}$/.test(v) ? (v === appIdNow ? 'Application ID と同じ' : `${v.length} 文字`) : (v ? 'ほかの値' : '空'));
          if (/^[A-Za-z0-9_\-]{16,}$/.test(v) && v !== appIdNow && !k2) k2 = v;
        }
        lines.push(`- アイコンを押したときのクリップボード: ${seen.join(' ／ ')}`);
        // t343: クリップボードも空。「Access Key」の行そのものの HTML を出す（値と長い英数は伏せる）
        const rowHtml = await p.evaluate(() => { const lab = [...document.querySelectorAll('*')].find((e) => e.children.length === 0 && /^\s*Access Key\s*$/i.test(e.textContent || '')); if (!lab) return ''; let r = lab.parentElement; for (let i = 0; i < 2 && r && r.parentElement && (r.outerHTML || '').length < 600; i++) r = r.parentElement; return (r ? r.outerHTML : '').replace(/\s+/g, ' ').slice(0, 1800); });
        lines.push('- 「Access Key」の行の HTML:', '```html', mask(rowHtml).replace(/[●•*]{4,}/g, '［伏せ字］'), '```');
        // t344: 目のボタンは onclick="toggleSecret(...)"。押したときの通信と、押したあとの code の中身・出た画面（本人確認など）を見る
        const net = []; const onResp = async (r) => { const u = r.url(); if (/webservice\.rakuten|rakuten\.co\.jp/.test(u) && !/\.(css|js|png|svg|woff2?)(\?|$)/.test(u)) { let keys = ''; try { const j = await r.json(); keys = Object.keys(j || {}).join(','); } catch {} net.push(`${r.request().method()} ${u.replace(/\?.*$/, '')} → ${r.status()}${keys ? ' {' + keys + '}' : ''}`); } };
        p.on('response', onResp);
        const eye = p.locator('xpath=//span[normalize-space()="Access Key"]/following-sibling::div[1]//button[contains(@onclick,"toggleSecret")]').first();
        if (await eye.count()) { await eye.click({ timeout: 4000 }).catch(() => {}); await p.waitForTimeout(4000); }
        p.off('response', onResp);
        const code = await p.evaluate(() => { const lab = [...document.querySelectorAll('span')].find((e) => /^\s*Access Key\s*$/i.test(e.textContent || '')); const c = lab && lab.parentElement.querySelector('code'); return c ? (c.textContent || '').trim() : ''; });
        const modal = await p.evaluate(() => [...document.querySelectorAll('.modal.show, [role=dialog], .swal2-popup')].filter((e) => e.getBoundingClientRect().height > 0).map((e) => (e.innerText || '').replace(/\s+/g, ' ').slice(0, 300)));
        lines.push(`- 目のボタン（Access Key）を押した: ${(await eye.count()) ? 'あり' : '見つからない'}・通信 ${net.length} 件`, ...net.slice(0, 8).map((x) => `  - ${mask(x)}`), `- 押したあとの値: ${/^[A-Za-z0-9_\-]{16,}$/.test(code) ? code.length + ' 文字（見えた）' : '伏せ字のまま'}`, ...modal.map((x) => `- 出た画面: ${mask(x)}`));
        if (/^[A-Za-z0-9_\-]{16,}$/.test(code) && code !== keychain('applicationId')) k2 = code;
        // t345: 「More Details」で開いた小窓（credentials を含む）が上に被っていた。小窓の中の Access Key の目を押して読む
        if (!k2) {
          const m = p.locator('.modal.show').first();
          if (await m.count()) {
            const codes0 = await m.locator('code').allInnerTexts().catch(() => []);
            const eyes = m.locator('button[onclick*="toggleSecret"]'); const ne = await eyes.count();
            for (let i = 0; i < ne; i++) { await eyes.nth(i).click({ timeout: 3000 }).catch(() => {}); await p.waitForTimeout(1500); }
            const pairs = await m.evaluate((el) => [...el.querySelectorAll('code')].map((c) => { const lab = ((c.closest('div.col-sm-6, .row, dl, tr, li') || c.parentElement).innerText || '').split('\n')[0].trim(); return [lab.slice(0, 30), (c.textContent || '').trim()]; }));
            lines.push(`- 小窓の中: code ${codes0.length} 個・目のボタン ${ne} 個`, ...pairs.map(([l, v]) => `  - ${l}: ${/^[A-Za-z0-9_\-]{16,}$/.test(v) ? v.length + ' 文字（見えた）' : (v.slice(0, 2) || '空') + '…'}`));
            const hit = pairs.find(([l, v]) => /Access Key/i.test(l) && /^[A-Za-z0-9_\-]{16,}$/.test(v));
            if (hit && hit[1] !== keychain('applicationId')) k2 = hit[1];
          } else lines.push('- 小窓が無い');
        }
      }
      {
      }
      lines.push(`- アイコンのボタン ${n} 個を押したあとの Access Key: ${k2 ? `${k2.length} 文字（見えた）` : `まだ伏せ字（${after.slice(0, 3)}…）`}`);
      if (k2) {
        try { execFileSync('/usr/bin/security', ['add-generic-password', '-U', '-s', 'dailyhack-rakuten-ws', '-a', 'accessKey', '-w', k2]); lines.push(`- Access Key を Keychain（dailyhack-rakuten-ws / accessKey）に入れた（${k2.length} 文字）`); }
        catch (e) { lines.push(`- ⚠️ Keychain に入れられない: ${String(e).slice(0, 80)}`); }
      }
    }
    else lines.push('- 価格の自動取得（mac-weekly.sh の 2e）は次の 6:40 から楽天の価格を取る');
    // API が通るか 1 回だけ（結果は件数と HTTP の状態だけ出す）
    const appId = keychain('applicationId'), acc = keychain('accessKey');
    if (appId) {
      const q = new URLSearchParams({ applicationId: appId, keyword: '充電式カイロ', hits: '1', formatVersion: '2', format: 'json' });
      if (acc) q.set('accessKey', acc);
      const r = await fetch(`https://openapi.rakuten.co.jp/ichibams/api/IchibaItem/Search/20260701?${q}`).catch((e) => ({ status: 0, text: async () => String(e) }));
      const t = await r.text();
      lines.push(`- 楽天 API（2026-07-01 版）の試し: HTTP ${r.status}${r.status === 200 ? `・件数 ${(() => { try { return JSON.parse(t).count; } catch { return '?'; } })()}` : `・${mask(t.slice(0, 160))}`}`);
    }
  }

  if (WHICH === 'moshimo') {
    await go('https://af.moshimo.com/af/shop/index');
    const box = p.locator('input[type=search]:visible, input[name*=keyword]:visible, input[placeholder*="検索"]:visible').first();
    if (await box.count()) {
      await box.fill('Amazon'); await box.press('Enter');
      await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {});
      await p.waitForTimeout(5000);
      const rows = await p.evaluate(() => [...document.querySelectorAll('a[href*="promotion"]')]
        .map((a) => { let box = a; for (let i = 0; i < 6 && box.parentElement; i++) { box = box.parentElement; if ((box.innerText || '').length > 120) break; }
          return { t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60), h: a.href, box: (box.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 240) }; })
        .filter((x) => /amazon/i.test(x.t + x.box)).slice(0, 12));
      lines.push(`- 「Amazon」で検索した画面: ${here()}`, '', '## Amazon を含むプロモーション', '', ...rows.map((r) => `- ${mask(r.t)} — ${r.h}\n  - ${mask(r.box)}`), '');
      // t332: 「Amazon」のプロモーションは promotion_id=170（検索結果の「プロモーション詳細」のリンク）。提携基準と申請の状態を読む
      const det = rows.find((r) => /promotion\/detail/.test(r.h) && /Amazon/.test(r.box));
      if (det) {
        await go(det.h);
        const text = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean));
        const i0 = Math.max(0, text.findIndex((x) => /提携前に以下の内容/.test(x)));
        lines.push('## Amazon のプロモーション詳細（押していない）', '', `- 画面: ${here()}`, '', '```text', ...text.slice(i0, i0 + 160).filter((x) => !/報酬|振込|口座|氏名/.test(x)).map((x) => x.slice(0, 220)), '```', '');
        // 「提携申請する」が何をするか（押さずに、リンク先・onclick・フォームを読む）
        const btns = await p.evaluate(() => [...document.querySelectorAll('a, button, input[type=submit]')].filter((e) => /提携申請する/.test(e.innerText || e.value || ''))
          .map((e) => ({ tag: e.tagName, href: e.getAttribute('href') || '', onclick: (e.getAttribute('onclick') || '').slice(0, 160), data: Object.entries(e.dataset).map(([k, v]) => `${k}=${v}`).join(' ').slice(0, 200), form: e.form ? `${e.form.method} ${e.form.action}` : '' })));
        lines.push('## 「提携申請する」の中身（押していない）', '', ...btns.map((x) => `- ${x.tag} href=${x.href} onclick=${x.onclick} data=${x.data} form=${x.form}`), '');
        await dump('Amazon の詳細のボタン');
      }
    } else { lines.push('- 検索欄が見つからない'); await dump('もしものトップ'); }
  }

  if (WHICH === 'moshimo-apply-open') {
    // Amazon の提携基準「メディア内に『Amazonのアソシエイトとして、当メディアは適格販売により収入を得ています。』の旨を記載」を本番で確かめてから、
    // 「提携申請する」（data-promotion_id=170）を押して、出た確認の画面を読む（**最後の送信は押さない**。押すのは次のタスク）
    // マージから本番への反映に数分かかるので、最大 8 分待つ
    let ok = false;
    for (let i = 0; i < 16 && !ok; i++) {
      const live = await fetch(`https://daily-hack.fieldbeside.com/?t=${Date.now()}`).then((r) => r.text()).catch(() => '');
      ok = live.includes('Amazonのアソシエイトとして、当メディアは適格販売により収入を得ています。');
      if (!ok) await new Promise((r) => setTimeout(r, 30000));
    }
    lines.push(`- 本番のトップに Amazon アソシエイトの記載: ${ok ? 'ある' : '**無い**（押さずに止める）'}`);
    if (ok) {
      await go('https://af.moshimo.com/af/shop/promotion/detail?promotion_id=170');
      const st = await p.evaluate(() => (document.body.innerText || '').match(/(申請中|提携中|否認|未提携)/g) || []);
      lines.push(`- 画面の提携状態の語: ${[...new Set(st)].join(' / ') || 'なし'}`);
      const btn = p.locator('button[data-promotion_id="170"]').first();
      if (await btn.count()) {
        await btn.click({ timeout: 5000 }).catch(() => {});
        await p.waitForTimeout(3500);
        await dump('「提携申請する」を押したあと（最後の送信は押していない）');
        const modal = await p.evaluate(() => [...document.querySelectorAll('[role=dialog], .modal, .modal-content, .remodal, .c-modal')].filter((e) => e.getBoundingClientRect().height > 0).map((e) => (e.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 900)));
        lines.push('## 出た確認の画面の文字', '', ...modal.map((x) => `- ${mask(x)}`), '');
      } else lines.push('- data-promotion_id=170 のボタンが無い（もう申請済みかもしれない）');
    }
  }

  if (WHICH === 'moshimo-apply') {
    // t335 で「提携申請する」を押すと「ご確認ください」の画面（閉じる／提携申請する）が出ると分かった。ここで最後の「提携申請する」を押す
    // （申請は利用者の OK 済み 2026-10-25。本番に Amazon アソシエイトの記載があることを先に確かめる）
    const live = await fetch(`https://daily-hack.fieldbeside.com/?t=${Date.now()}`).then((r) => r.text()).catch(() => '');
    if (!live.includes('Amazonのアソシエイトとして、当メディアは適格販売により収入を得ています。')) { lines.push('- 本番に Amazon アソシエイトの記載が無いので押さない'); }
    else {
      await go('https://af.moshimo.com/af/shop/promotion/detail?promotion_id=170');
      const first = p.locator('button[data-promotion_id="170"]').first();
      if (!(await first.count())) lines.push('- data-promotion_id=170 のボタンが無い（申請済みかもしれない）');
      else {
        await first.click({ timeout: 5000 }).catch(() => {});
        await p.waitForTimeout(3000);
        // 確認の画面（ご確認ください／閉じる／提携申請する）の「提携申請する」= data-promotion_id を持たない、見えているボタン（t336 は箱の探し方で落ちた）
        const txt = await p.evaluate(() => { const h = [...document.querySelectorAll('*')].find((e) => e.children.length === 0 && /ご確認ください/.test(e.textContent || '') && e.getBoundingClientRect().height > 0); let b = h; for (let i = 0; i < 5 && b && b.parentElement; i++) { b = b.parentElement; if ((b.innerText || '').includes('閉じる')) break; } return b ? (b.innerText || '').replace(/\s+/g, ' ').slice(0, 900) : ''; }).catch((e) => '読めない: ' + String(e).slice(0, 80));
        lines.push('## 確認の画面の文字', '', `- ${mask(txt)}`, '');
        const go2 = p.locator('button:visible:not([data-promotion_id]), a:visible:not([data-promotion_id]), input[type=submit]:visible').filter({ hasText: /^\s*提携申請する\s*$/ }).last();
        if (await go2.count()) {
          await go2.click({ timeout: 5000 }).catch(() => {});
          await p.waitForTimeout(5000);
          lines.push(`- 確認の画面の「提携申請する」を押した（${here()}）`, `- 出たダイアログ: ${DIALOGS.join(' ／ ') || 'なし'}（moshimo-apply では「OK」を押す）`);
          await dump('押したあとの画面');
        } else lines.push('- 確認の画面の中に「提携申請する」が見つからない（押していない）');
        await go('https://af.moshimo.com/af/shop/promotion/search?words=Amazon&apply_status=1');
        const rows = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter((x) => /Amazon\.co\.jp/.test(x)).slice(0, 5));
        lines.push('## 「申請中」で絞った一覧の Amazon の行', '', ...rows.map((x) => `- ${mask(x).slice(0, 160)}`), '');
      }
    }
  }

  if (WHICH === 'moshimo-status') {
    // 申請したかどうかを読むだけ（t336 は途中で落ちて記録が無い）。押さない
    await go('https://af.moshimo.com/af/shop/promotion/detail?promotion_id=170');
    const btn = await p.locator('button[data-promotion_id="170"]').count();
    const words = await p.evaluate(() => [...new Set((document.body.innerText || '').match(/(申請中|提携中|否認中|未提携|審査中|申請済み)/g) || [])]);
    lines.push(`- Amazon（170）の詳細: 「提携申請する」ボタン ${btn} 個・画面の状態の語 ${words.join(' / ') || 'なし'}`);
    for (const st of ['1', '2']) {
      await go(`https://af.moshimo.com/af/shop/promotion/search?words=Amazon&apply_status=${st}`);
      const rows = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter((x) => /Amazon\.co\.jp/.test(x)).slice(0, 3));
      const hit = await p.evaluate(() => ((document.body.innerText || '').match(/検索結果: ?(\d+) ?件/) || [])[1] || '?');
      lines.push(`- apply_status=${st} で絞った一覧: ${hit} 件・Amazon.co.jp の行 ${rows.length}`, ...rows.map((x) => `  - ${mask(x).slice(0, 140)}`));
    }
  }

  if (WHICH === 'moshimo-media') {
    // t339: 「提携申請する」の確認は「提携申請には、あなたのサイトやブログを登録する必要があります。メディア登録ページに移動しますか？」だった。
    // 申請の画面のメディアの選択肢と、メディア登録の画面を読む（**送らない**）
    await go('https://af.moshimo.com/af/shop/promotion/detail?promotion_id=170');
    const opts = await p.evaluate(() => [...document.querySelectorAll('select[name=shop_site_id] option')].map((o) => `${o.selected ? '✔ ' : ''}${(o.textContent || '').trim()}（value ${o.value ? 'あり' : '空'}）`));
    lines.push('## 申請の画面のメディアの選択肢', '', ...opts.map((x) => `- ${mask(x)}`), '');
    const reg = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href]')].filter((a) => /メディア|サイト登録|登録メディア/.test(a.innerText || '')).map((a) => `${(a.innerText || '').trim().slice(0, 30)} — ${a.href}`))].slice(0, 8));
    lines.push('## メディア登録へのリンク', '', ...reg.map((x) => `- ${mask(x)}`), '');
    const regUrl = (reg.find((x) => /登録/.test(x)) || '').split(' — ')[1];
    if (regUrl) { await go(regUrl); await dump('メディア一覧の画面'); }
    // t341: メディア一覧に「メディアを登録する」がある。押して出る登録の画面の欄を読む（**送らない**）
    // t343: 登録の入口は URL の欄（media_url）＋「メディアを登録する」。daily-hack の URL を入れて押し、次の画面の欄を読む（その先の送信はしない）
    const urlBox = p.locator('input[name=media_url]').first();
    if (await urlBox.count()) await urlBox.fill('https://daily-hack.fieldbeside.com/');
    const add = p.getByRole('button', { name: /メディアを登録する/ }).first();
    if (await add.count()) { await add.click({ timeout: 5000 }).catch(() => {}); await p.waitForLoadState('domcontentloaded', { timeout: 15000 }).catch(() => {}); await p.waitForTimeout(5000); await dump('URL を入れて「メディアを登録する」を押したあと（この先は送っていない）');
      const txt = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).filter((x) => /必須|入力|選択|カテゴリ|ジャンル|PV|訪問|説明|規約|同意|確認|登録/.test(x)).slice(0, 40));
      lines.push('- 画面の案内の文字:', ...txt.map((x) => `  - ${mask(x).slice(0, 160)}`));
      // t344: 「登録前にご確認ください。(1/2)」の小窓が出る。小窓の中の欄・ボタンを読む（押さない）
      const mdl = await p.evaluate(() => { const h = [...document.querySelectorAll('*')].find((e) => e.children.length === 0 && /登録前にご確認ください/.test(e.textContent || '') && e.getBoundingClientRect().height > 0); let b = h; for (let i = 0; i < 6 && b && b.parentElement; i++) { b = b.parentElement; if (b.querySelectorAll('button, input').length) break; } if (!b) return null;
        return { text: (b.innerText || '').replace(/\s+/g, ' ').slice(0, 600), ctrls: [...b.querySelectorAll('button, input, a[role=button], label')].map((e) => `${e.tagName.toLowerCase()}[type=${e.type || ''} name=${e.name || ''}] 「${(e.innerText || e.value || '').trim().slice(0, 30)}」`).slice(0, 15) }; });
      if (mdl) lines.push('- 確認の小窓:', `  - ${mask(mdl.text)}`, ...mdl.ctrls.map((x) => `  - ${x}`));
      // t345: 小窓のボタンが button 要素ではなかった。押せそうな見えている要素（cursor:pointer・短い文字）を全部出す（押さない）
      const clickables = await p.evaluate(() => [...document.querySelectorAll('a, button, div, span, label, input')].filter((e) => { const r = e.getBoundingClientRect(); if (!r.height) return false; const cs = getComputedStyle(e); const t = (e.innerText || e.value || '').trim(); return (cs.cursor === 'pointer' || e.tagName === 'BUTTON' || e.type === 'checkbox') && t.length > 0 && t.length < 24 && e.children.length < 3; }).map((e) => `${e.tagName.toLowerCase()}${e.className ? '.' + String(e.className).split(' ')[0] : ''} 「${(e.innerText || e.value || '').trim()}」`).filter((x, i, a) => a.indexOf(x) === i).slice(-30));
      lines.push('- 押せそうな要素（後ろの 30 個）:', ...clickables.map((x) => `  - ${x}`));
      const opts = await p.evaluate(() => [...document.querySelectorAll('select')].filter((e) => e.getBoundingClientRect().height > 0).map((e) => `select[name=${e.name}]: ${[...e.options].map((o) => o.textContent.trim()).join(' / ').slice(0, 400)}`));
      lines.push('- 選択肢:', ...opts.map((x) => `  - ${x}`)); }
  }

  if (WHICH === 'yahoo-open') {
    // 利用者が Yahoo! JAPAN ID でログインするための画面を、この Chrome に開いたままにする（閉じない）
    const q = await ctx.newPage();
    await q.goto('https://e.developer.yahoo.co.jp/dashboard/', { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
    await q.bringToFront().catch(() => {});
    lines.push(`- Yahoo! デベロッパーネットワークの画面を開いたままにした: ${q.url()}（利用者がここで Yahoo! JAPAN ID にログインする）`);
  }

  if (WHICH === 'yahoo-check') {
    // 2026-10-25 利用者が Yahoo! の Client ID を Keychain（dailyhack-yahoo-shopping / clientId）に入れた。最初に別の値を入れて上書きしたとのこと。
    // **値は出さない。** 出すのは件数・文字数・形（Yahoo! の Client ID は "dj0" で始まる英数字）と、API の HTTP の状態・件数だけ
    let v = '';
    try { v = execFileSync('/usr/bin/security', ['find-generic-password', '-s', 'dailyhack-yahoo-shopping', '-a', 'clientId', '-w'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).replace(/\n$/, ''); } catch {}
    let items = 0;
    try { const dump = execFileSync('/usr/bin/security', ['dump-keychain'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 64 << 20 }); items = (dump.match(/"svce"<blob>="dailyhack-yahoo-shopping"/g) || []).length; } catch { items = -1; }
    lines.push(`- Keychain の dailyhack-yahoo-shopping の項目: ${items < 0 ? '数えられない' : items + ' 件'}`);
    lines.push(`- clientId の値: ${v ? `${v.length} 文字・${/^[A-Za-z0-9_\-=]+$/.test(v) ? '英数字だけ' : '英数字以外を含む（パスワードの可能性）'}・${/^dj0/.test(v) ? '"dj0" で始まる（Yahoo! の Client ID の形）' : '"dj0" で始まらない'}` : '**読めない**'}`);
    if (v) {
      const q = new URLSearchParams({ appid: v, query: '充電式カイロ', results: '1' });
      const r = await fetch(`https://shopping.yahooapis.jp/ShoppingWebService/V3/itemSearch?${q}`).catch((e) => ({ status: 0, text: async () => String(e) }));
      const t = await r.text();
      let hits = '?'; try { hits = JSON.parse(t).totalResultsAvailable; } catch {}
      lines.push(`- Yahoo!ショッピング API（商品検索 V3）の試し: HTTP ${r.status}${r.status === 200 ? `・ヒット ${hits} 件（**使える**）` : `・${mask(t.slice(0, 200))}`}`);
    }
  }

  if (WHICH === 'yahoo-wait') {
    // t348: この Chrome（CDP 18810）には Yahoo! のログインが無かった（利用者は別の Chrome でログインしたらしい）。
    // ログインの画面をこの Chrome の前面に出して、利用者のログインを最大 12 分待つ。入れたら登録の画面を読む（送らない）
    const q = await ctx.newPage();
    await q.goto('https://e.developer.yahoo.co.jp/dashboard/', { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
    // t349: ボタンが描かれる前に探して押せず、読み込み中の空の画面を「ログインできた」と取り違えた。描かれるのを待ってから押す
    const btn = q.getByText(/^Yahoo! JAPAN IDでログイン$/).first();
    await btn.waitFor({ timeout: 15000 }).catch(() => {});
    if (await btn.count()) { await btn.click({ timeout: 5000 }).catch(() => {}); await q.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {}); }
    lines.push(`- ログインのボタンを押したあとの画面: ${(() => { try { const u = new URL(q.url()); return u.origin + u.pathname; } catch { return q.url(); } })()}`);
    await q.bringToFront().catch(() => {});
    lines.push(`- ログインの画面をこの Chrome の前面に出した（${new Date().toISOString()}）。最大 12 分待つ`);
    let ok = false;
    for (let i = 0; i < 48 && !ok; i++) {
      await q.waitForTimeout(15000);
      const u = q.url();
      // ログインできた証拠＝デベロッパーの画面で、文字が十分に描かれていて、「ログインする必要があります」が無いこと
      if (/e\.developer\.yahoo\.co\.jp/.test(u)) { const t = await q.evaluate(() => document.body.innerText || '').catch(() => ''); ok = t.length > 300 && !/ログインする必要があります/.test(t); }
    }
    lines.push(`- 待った結果: ${ok ? '**ログインできた**' : 'ログインされなかった（12 分）'}`);
    if (ok) { await go('https://e.developer.yahoo.co.jp/register'); await dump('新しいアプリケーションを開発（登録の画面・送っていない）');
      const opts = await p.evaluate(() => [...document.querySelectorAll('select')].filter((e) => e.getBoundingClientRect().height > 0).map((e) => `select[name=${e.name}]: ${[...e.options].map((o) => (o.selected ? '✔' : '') + o.textContent.trim()).join(' / ').slice(0, 300)}`));
      const radios = await p.evaluate(() => [...document.querySelectorAll('input[type=radio], input[type=checkbox]')].map((e) => `${e.type}[name=${e.name} value=${e.value}]${e.checked ? ' ✔' : ''} 「${((e.closest('label') || {}).innerText || (e.id && (document.querySelector('label[for="' + e.id + '"]') || {}).innerText) || '').replace(/\s+/g, ' ').trim().slice(0, 60)}」`));
      const txt = await p.evaluate(() => (document.querySelector('form') || document.body).innerText.split('\n').map((x) => x.trim()).filter(Boolean).slice(0, 80));
      lines.push('- 選択肢:', ...opts.map((x) => `  - ${x.replace(/[^\s/]+@[^\s/]+/g, '［メール］')}`), '- ラジオ・チェック:', ...radios.map((x) => `  - ${x}`), '- 登録の画面の文字:', ...txt.filter((x) => !NG.test(x)).map((x) => `  - ${mask(x).slice(0, 150)}`)); }
  }

  if (WHICH === 'yahoo') {
    // Yahoo! デベロッパーネットワークの公式の入口（アプリケーションの管理・新規登録）
    await go('https://e.developer.yahoo.co.jp/dashboard/');
    await dump('アプリケーションの管理');
    // t347: 利用者のログイン後もデベロッパーの画面は「ログインが必要」のまま。「Yahoo! JAPAN IDでログイン」を押して、
    // Yahoo! のログイン済みの状態で戻ってこられるか（ID・パスワードの欄が出るか）を見る。**ID・パスワードは入れない**
    const sso = p.getByText(/^Yahoo! JAPAN IDでログイン$/).first();
    if (await sso.count()) {
      await sso.click({ timeout: 5000 }).catch(() => {});
      await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {});
      await p.waitForTimeout(6000);
      const hasPw = await p.locator('input[type=password]:visible, input[name=handle]:visible, input[name=login]:visible').count();
      lines.push(`- 「Yahoo! JAPAN IDでログイン」を押した: いまの画面 ${here()}・ID かパスワードの欄 ${hasPw ? 'あり（Yahoo! のログインがこの Chrome に無い）' : 'なし'}`);
      await dump('押したあとの画面');
    }
    const tabs = ctx.pages().map((q) => { try { const u = new URL(q.url()); return u.host; } catch { return ''; } }).filter((h) => /yahoo/.test(h));
    lines.push(`- この Chrome で開いている Yahoo! のタブ: ${tabs.length} 個（${[...new Set(tabs)].join('・')}）`);
    await go('https://e.developer.yahoo.co.jp/register');
    await dump('新しいアプリケーションを開発（登録の画面・送っていない）');
    // 2026-10-25 利用者が Yahoo! JAPAN ID でログインした。登録の画面の選択肢と案内の文字も読む（送らない）
    const opts = await p.evaluate(() => [...document.querySelectorAll('select')].filter((e) => e.getBoundingClientRect().height > 0).map((e) => `select[name=${e.name}]: ${[...e.options].map((o) => (o.selected ? '✔' : '') + o.textContent.trim()).join(' / ').slice(0, 300)}`));
    const radios = await p.evaluate(() => [...document.querySelectorAll('input[type=radio], input[type=checkbox]')].map((e) => `${e.type}[name=${e.name} value=${e.value}]${e.checked ? ' ✔' : ''} 「${((e.closest('label') || {}).innerText || (e.id && (document.querySelector('label[for="' + e.id + '"]') || {}).innerText) || '').replace(/\s+/g, ' ').trim().slice(0, 60)}」`));
    const txt = await p.evaluate(() => (document.querySelector('form') || document.body).innerText.split('\n').map((x) => x.trim()).filter(Boolean).slice(0, 80));
    lines.push('- 選択肢:', ...opts.map((x) => `  - ${x.replace(/[^\s/]+@[^\s/]+/g, '［メール］')}`), '- ラジオ・チェック:', ...radios.map((x) => `  - ${x}`), '- 登録の画面の文字:', ...txt.filter((x) => !NG.test(x)).map((x) => `  - ${mask(x).slice(0, 150)}`));
  }
} catch (e) { lines.push(`- ⚠️ ${mask(String(e).split('\n')[0])}`); }
finally { await p.close().catch(() => {}); }

function aspCred(id) {
  try {
    const meta = execFileSync('/usr/bin/security', ['find-generic-password', '-s', `dailyhack-asp-${id}`], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    let user = (meta.match(/"acct"<blob>="([^"]*)"/) || [])[1];
    const hex = (meta.match(/"acct"<blob>=0x([0-9A-Fa-f]+)/) || [])[1];
    if (!user && hex) user = Buffer.from(hex, 'hex').toString('utf8');
    const pass = execFileSync('/usr/bin/security', ['find-generic-password', '-s', `dailyhack-asp-${id}`, '-w'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).replace(/\n$/, '');
    return user && pass ? { user, pass } : null;
  } catch { return null; }
}
function keychain(acct) { try { return execFileSync('/usr/bin/security', ['find-generic-password', '-s', 'dailyhack-rakuten-ws', '-a', acct, '-w'], { encoding: 'utf8' }).trim(); } catch { return ''; } }
fs.writeFileSync(path.join(OUT, `${WHICH}.md`), lines.join('\n') + '\n');
console.log(lines.join('\n'));
process.exit(0);
