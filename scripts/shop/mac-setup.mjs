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

const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
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
          return { app: val(/^(Application ID|アプリID)/i) || fromInput(/Application ID/i), key: val(/^(Access Key|アクセスキー)/i) || fromInput(/Access Key/i) };
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
    if (!key) await dump('アプリ一覧の画面');
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
        // 「ご確認ください」を含む、いま見えている箱の中の「提携申請する」
        const box = p.locator('div:visible').filter({ hasText: 'ご確認ください' }).filter({ has: p.getByRole('button', { name: '閉じる' }) }).last();
        const txt = (await box.innerText().catch(() => '')).replace(/\s+/g, ' ').slice(0, 900);
        lines.push('## 確認の画面の文字', '', `- ${mask(txt)}`, '');
        const go2 = box.getByRole('button', { name: /^提携申請する$/ }).last();
        if (await go2.count()) {
          await go2.click({ timeout: 5000 }).catch(() => {});
          await p.waitForTimeout(5000);
          lines.push(`- 確認の画面の「提携申請する」を押した（${here()}）`);
          await dump('押したあとの画面');
        } else lines.push('- 確認の画面の中に「提携申請する」が見つからない（押していない）');
        await go('https://af.moshimo.com/af/shop/promotion/search?words=Amazon&apply_status=1');
        const rows = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter((x) => /Amazon\.co\.jp/.test(x)).slice(0, 5));
        lines.push('## 「申請中」で絞った一覧の Amazon の行', '', ...rows.map((x) => `- ${mask(x).slice(0, 160)}`), '');
      }
    }
  }

  if (WHICH === 'yahoo-open') {
    // 利用者が Yahoo! JAPAN ID でログインするための画面を、この Chrome に開いたままにする（閉じない）
    const q = await ctx.newPage();
    await q.goto('https://e.developer.yahoo.co.jp/dashboard/', { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
    await q.bringToFront().catch(() => {});
    lines.push(`- Yahoo! デベロッパーネットワークの画面を開いたままにした: ${q.url()}（利用者がここで Yahoo! JAPAN ID にログインする）`);
  }

  if (WHICH === 'yahoo') {
    // Yahoo! デベロッパーネットワークの公式の入口（アプリケーションの管理・新規登録）
    await go('https://e.developer.yahoo.co.jp/dashboard/');
    await dump('アプリケーションの管理');
    await go('https://e.developer.yahoo.co.jp/register');
    await dump('新しいアプリケーションを開発（登録の画面・送っていない）');
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
