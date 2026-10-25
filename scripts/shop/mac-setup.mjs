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
    lines.push(`- 画面: ${here()}`, '');
    // t294 で「Application ID / Access Key / Affiliate ID」の行がこの画面にあると分かっている
    const got = await p.evaluate(() => {
      const rows = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean);
      const val = (re) => { const i = rows.findIndex((x) => re.test(x)); if (i < 0) return ''; const same = rows[i].replace(re, '').replace(/^[\s:：]+/, '').trim(); return same || rows[i + 1] || ''; };
      return { app: val(/^(Application ID|アプリID)/i), key: val(/^(Access Key|アクセスキー)/i) };
    });
    const key = (got.key.match(/[A-Za-z0-9_\-]{16,}/) || [])[0] || '';
    const app = (got.app.match(/[A-Za-z0-9_\-]{16,}/) || [])[0] || '';
    lines.push(`- Application ID: ${app ? `${app.length} 文字（Keychain の値と${app === keychain('applicationId') ? '同じ' : '**違う**'}）` : '見つからない'}`);
    if (key) {
      try { execFileSync('/usr/bin/security', ['add-generic-password', '-U', '-s', 'dailyhack-rakuten-ws', '-a', 'accessKey', '-w', key]); lines.push(`- Access Key を Keychain（dailyhack-rakuten-ws / accessKey）に入れた（${key.length} 文字）`); }
      catch (e) { lines.push(`- ⚠️ Keychain に入れられない: ${String(e).slice(0, 80)}`); }
    } else lines.push('- Access Key が画面に見つからない（「表示」ボタンで隠れている可能性）。ボタン一覧を下に出す');
    if (!key) await dump('アプリ一覧の画面');
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
      if (rows[0]) { await go(rows[0].h); await dump('先頭のプロモーションの詳細（押していない）'); }
    } else { lines.push('- 検索欄が見つからない'); await dump('もしものトップ'); }
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

function keychain(acct) { try { return execFileSync('/usr/bin/security', ['find-generic-password', '-s', 'dailyhack-rakuten-ws', '-a', acct, '-w'], { encoding: 'utf8' }).trim(); } catch { return ''; } }
fs.writeFileSync(path.join(OUT, `${WHICH}.md`), lines.join('\n') + '\n');
console.log(lines.join('\n'));
process.exit(0);
