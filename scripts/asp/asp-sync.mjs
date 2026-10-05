// ASP（A8.net・もしもアフィリエイト・バリューコマース・楽天アフィリエイト）の
// **ログインを保ち、管理画面のメニューと提携中の広告を書き出す**（Mac で動かす・LLM 不使用・$0）。
//
// 利用者: 「以降どんな場合でも、ちゃんとあなた自身で A8 やバリューコマースを使えるようにしてほしい。
//          その場しのぎのやり方になってない？」（2026-10-05）
//
// ## 仕組み
//
//   launchd（週 1）／ ops/tasks から呼ばれる
//     → Mac の Chrome（CDP 18810・OpenClaw 用）につなぐ
//     → 各 ASP の管理画面を開く
//         ログイン欄が出たら **Keychain の ID・パスワード**で入り直す（無ければ「要ログイン」と書いて次へ）
//         二段階認証・画像認証が出たら **そこで止めて「要人手」と書く**（突破しようとしない）
//     → メニューの URL と、提携中の広告の行（**金額・氏名・口座は落とす**）を書き出す
//     → 楽天は **アフィリエイト ID**（リンクに必ず載る公開値）も拾う
//
// ## 認証情報は repo にも報告にも出さない
//
// Keychain の汎用パスワード（サービス名 `dailyhack-asp-<id>`、アカウント＝ログイン ID）から読む。
// 登録は利用者が Mac で 1 回だけ:  security add-generic-password -U -s dailyhack-asp-a8 -a 'ID' -w
//
// 出力: $OPS_REPORT_DIR/asp-sync/（ops-heartbeat が ops/heartbeat ブランチへ push する）
//   status.json   … 各 ASP のログイン状態（**出したあと自分で parse して確かめる**・最上位ルール 13）
//   <id>.md       … メニュー URL と提携中の広告の行

import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const PW_DIR = process.env.PW_DIR || [
  path.join(os.homedir(), '.openclaw/workspace/node_modules'),
  path.join(os.homedir(), 'openclaw/node_modules'),
].find((d) => fs.existsSync(path.join(d, 'playwright-core')));
if (!PW_DIR) { console.error('playwright-core が無い'); process.exit(0); }
const req = createRequire(path.join(PW_DIR, 'x.js'));
const { chromium } = req('playwright-core');

const PORT = process.env.CDP_PORT || '18810';
const OUTDIR = path.join(process.env.OPS_REPORT_DIR
  || path.join(os.homedir(), '.openclaw/ops-heartbeat-wt/reports'), 'asp-sync');
fs.mkdirSync(OUTDIR, { recursive: true });
const BUDGET_MS = Number(process.env.ASP_SYNC_BUDGET_MS || 230000);
const T0 = Date.now();

const PROVIDERS = [
  { id: 'a8', name: 'A8.net', start: 'https://pub.a8.net/a8v2/media/partnerProgramListAction.do', menu: /提携|参加|プログラム|広告リンク|セルフバック/ },
  { id: 'moshimo', name: 'もしもアフィリエイト', start: 'https://af.moshimo.com/af/shop/index', menu: /提携|プロモーション|広告|リンク|どこでも/ },
  { id: 'vc', name: 'バリューコマース', start: 'https://aff.valuecommerce.ne.jp/', menu: /提携|広告主|プログラム|リンク|MyLink|LinkSwitch|サイト/ },
  { id: 'rakuten', name: '楽天アフィリエイト', start: 'https://affiliate.rakuten.co.jp/report/summary', menu: /リンク|アフィリエイトID|レポート|サイト|カード|トラベル|ブックス/ },
];

// Keychain から読む。**値は返すだけで、どこにも書かない**
function keychain(id) {
  const svc = `dailyhack-asp-${id}`;
  try {
    const meta = execFileSync('/usr/bin/security', ['find-generic-password', '-s', svc], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    // ID に非 ASCII（全角など）が入ると `"acct"<blob>=0xE3...  "..."` と 16 進で出る（2026-10-05 に vc で踏んだ）
    let acct = (meta.match(/"acct"<blob>="([^"]*)"/) || [])[1];
    const hex = (meta.match(/"acct"<blob>=0x([0-9A-Fa-f]+)/) || [])[1];
    if (!acct && hex) acct = Buffer.from(hex, 'hex').toString('utf8');
    const pass = execFileSync('/usr/bin/security', ['find-generic-password', '-s', svc, '-w'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).replace(/\n$/, '');
    return acct && pass ? { user: acct, pass } : null;
  } catch { return null; }
}

async function pageState(p) {
  return p.evaluate(() => {
    const vis = (el) => !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
    const pw = [...document.querySelectorAll('input[type=password]')].some(vis);
    const text = document.body ? document.body.innerText : '';
    const human = /認証コード|ワンタイム|確認コード|二段階|2段階|reCAPTCHA|画像認証|私はロボットではありません/.test(text)
      || !!document.querySelector('iframe[src*="recaptcha"], iframe[src*="hcaptcha"]');
    // **「パスワード欄が無い」だけでは、ログインしている証拠にならない**（2026-10-05 に 2 件 誤判定した。
    // A8 は 404 ページ、楽天は「楽天IDでログイン」のボタンが出ている入口で、どちらも欄が無かった）
    const title = document.title.slice(0, 80);
    const notFound = /見つかりません|Not Found|404|エラー/i.test(title);
    const loginCta = [...document.querySelectorAll('a, button')].some((el) => vis(el)
      && /^(ログイン|ログインする|ログインはこちら|楽天IDでログイン|IDでログイン|会員ログイン|Login|Sign in)$/i.test((el.innerText || '').replace(/\s+/g, '').trim()));
    const loginUrl = /login|signin|re-authentication|authorize/i.test(location.href);
    const logoutLink = [...document.querySelectorAll('a, button')].some((el) => /ログアウト|logout|sign ?out/i.test(el.innerText || el.href || ''));
    const inputs = [...document.querySelectorAll('input, button, [role=button]')].filter(vis).slice(0, 15)
      .map((el) => el.tagName === 'INPUT' ? `input[type=${el.type}${el.name ? ` name=${el.name}` : ''}${el.id ? ` id=${el.id}` : ''}]` : `button「${(el.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 20)}」`);
    return { pw, human, url: location.href, title, notFound, loginCta, loginUrl, logoutLink, inputs };
  });
}

// **ログインは「本物のキー入力」で行う**（2026-10-05）。
// 画面側の値を直接書き換える方法は A8・もしも・バリューコマースでは通ったが、楽天では
// 「次へ」を押しても ID 入力の画面から先へ進まなかった。キーを 1 文字ずつ打てば、どのサイトでも通常の入力と同じになる。
// 楽天のように「ID → 次へ → パスワード」と 2 画面に分かれる入口にも、この 1 本で対応する。
const ID_SEL = 'input[type=text]:visible, input[type=email]:visible, input:not([type]):visible';
const PW_SEL = 'input[type=password]:visible';

async function typeInto(loc, text) {
  await loc.click({ timeout: 5000 }).catch(() => {});
  await loc.fill('').catch(() => {});
  await loc.pressSequentially(text, { delay: 35 });
}

async function pressButton(p, re) {
  const btn = p.getByRole('button', { name: re }).first();
  if (await btn.count()) { await btn.click({ timeout: 5000 }).catch(() => {}); return; }
  const sub = p.locator('input[type=submit]:visible').first();
  if (await sub.count()) { await sub.click({ timeout: 5000 }).catch(() => {}); return; }
  await p.keyboard.press('Enter');
}

async function tryLogin(p, cred) {
  // 1 画面目: ID だけが出ている（楽天）
  if (!(await p.locator(PW_SEL).count()) && (await p.locator(ID_SEL).count())) {
    await typeInto(p.locator(ID_SEL).first(), cred.user);
    await pressButton(p, /次へ|続ける|Next/);
    await p.waitForTimeout(4500);
  }
  if (!(await p.locator(PW_SEL).count())) return false;
  // ID とパスワードが同じ画面（A8・もしも・バリューコマース）。ID 欄が空なら入れる
  const id = p.locator(ID_SEL).first();
  if ((await id.count()) && !(await id.inputValue().catch(() => 'x'))) await typeInto(id, cred.user);
  await typeInto(p.locator(PW_SEL).first(), cred.pass);
  await pressButton(p, /ログイン|サインイン|次へ|Login|Sign ?in/i);
  await p.waitForLoadState('domcontentloaded', { timeout: 20000 }).catch(() => {});
  await p.waitForTimeout(4500);
  return true;
}

async function dump(p, menuRe) {
  return p.evaluate((src) => {
    const re = new RegExp(src);
    const links = [...document.querySelectorAll('a')]
      .map((a) => [(a.innerText || a.title || '').replace(/\s+/g, ' ').trim().slice(0, 60), a.href])
      .filter(([t, h]) => t && h && h.startsWith('http') && re.test(t));
    const seen = new Set();
    const menus = links.filter(([, h]) => !seen.has(h) && seen.add(h)).slice(0, 40);
    // **金額・氏名・口座・住所は出さない**
    const rows = [...document.querySelectorAll('tr, li')]
      .map((r) => r.innerText.replace(/\s+/g, ' ').trim())
      // **契約者名・契約者 ID も出さない**（2026-10-05、バリューコマースの会社名と契約者 ID を出してしまった）
      .filter((t) => t.length > 3 && t.length < 140 && !/円|¥|報酬|口座|氏名|住所|電話|メール|契約者|振込|合同会社|有限会社|（\d{6,}）|\(\d{6,}\)/.test(t))
      .slice(0, 120);
    const html = document.documentElement.outerHTML;
    const rakutenIds = [...new Set(html.match(/\b[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}\b/g) || [])].slice(0, 5);
    return { menus, rows, rakutenIds };
  }, menuRe.source);
}

const status = { generated: new Date().toISOString(), providers: {} };
const b = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`).catch((e) => { console.error(`CDP ${PORT} につながらない: ${e}`); return null; });
if (!b) {
  status.error = `Chrome が CDP ${PORT} で応答しない`;
} else {
  const ctx = b.contexts()[0] || (await b.newContext());
  const p = await ctx.newPage();
  for (const pr of PROVIDERS) {
    const st = { name: pr.name, loggedIn: false, needsHuman: false, credentialsInKeychain: false, reason: '' };
    status.providers[pr.id] = st;
    const lines = [`# ${pr.name}（asp-sync）`, '', `生成: **${status.generated}**`, ''];
    if (Date.now() - T0 > BUDGET_MS) { st.reason = '時間切れで開いていない'; fs.writeFileSync(path.join(OUTDIR, `${pr.id}.md`), lines.concat([st.reason]).join('\n') + '\n'); continue; }
    try {
      await p.goto(pr.start, { waitUntil: 'domcontentloaded', timeout: 25000 });
      await p.waitForTimeout(3500);
      let s = await pageState(p);
      const cred = keychain(pr.id);
      st.credentialsInKeychain = !!cred;
      if (!s.pw && s.loginCta && cred) {
        // 入口に「ログイン」ボタンだけ出ている（楽天など）→ 押してログイン画面へ
        await p.evaluate(() => {
          const el = [...document.querySelectorAll('a, button')].find((e) => /^(ログイン|ログインする|ログインはこちら|楽天IDでログイン|IDでログイン|会員ログイン)$/.test((e.innerText || '').replace(/\s+/g, '').trim()));
          if (el) el.click();
        });
        await p.waitForTimeout(4000);
        s = await pageState(p);
      }
      if (!s.pw && s.loginUrl && !s.human && cred) {
        await tryLogin(p, cred);
        s = await pageState(p);
      }
      if (s.pw && !s.human && cred) {
        await tryLogin(p, cred);
        await p.goto(pr.start, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
        await p.waitForTimeout(3500);
        s = await pageState(p);
        st.autoLoginTried = true;
      }
      st.url = s.url; st.title = s.title;
      if (!st.loggedIn && (s.pw || s.loginUrl)) st.formSeen = s.inputs; // 入れなかったとき、画面に何が出ていたか（値は無し）
      if (s.human) { st.needsHuman = true; st.reason = '二段階認証・画像認証が出た。利用者が 1 回 通す必要がある'; }
      else if (s.pw || s.loginCta || s.loginUrl) { st.reason = cred ? 'Keychain の ID・パスワードで入れなかった（値を確かめる）' : 'ログインしていない。Keychain に ID・パスワードが無い'; }
      else if (s.notFound) { st.reason = `入口のページが開けなかった（${s.title}）。入口の URL を直す`; }
      else if (!s.logoutLink) { st.reason = 'ログアウトのリンクが見当たらない。ログインできているか確かめられない'; }
      else st.loggedIn = true;
      lines.push(`- ログイン: **${st.loggedIn ? 'できている' : 'できていない'}**${st.reason ? `（${st.reason}）` : ''}`, `- 最終 URL: ${s.url}`, `- 題名: ${s.title}`, '');
      if (!st.loggedIn && s.inputs && s.inputs.length) lines.push('- 画面に出ていた入力欄・ボタン（値は出さない）: ' + s.inputs.join(' ／ '), '');
      if (st.loggedIn) {
        let d = await dump(p, pr.menu);
        lines.push('## メニュー', '', '| メニュー | URL |', '| --- | --- |', ...d.menus.map(([t, h]) => `| ${t.replace(/\|/g, '／')} | ${h} |`), '');
        const go = d.menus.find(([t]) => /提携|参加中/.test(t));
        if (go && Date.now() - T0 < BUDGET_MS) {
          await p.goto(go[1], { waitUntil: 'domcontentloaded', timeout: 25000 });
          await p.waitForTimeout(3500);
          const d2 = await dump(p, pr.menu);
          lines.push(`## 「${go[0]}」の行`, '', '```text', ...d2.rows, '```', '');
          d.rakutenIds.push(...d2.rakutenIds);
        } else {
          lines.push('## 入口の行', '', '```text', ...d.rows, '```', '');
        }
        if (pr.id === 'a8' && Date.now() - T0 < BUDGET_MS) {
          await p.goto('https://media-console.a8.net/program/list/partnered?pageNo=1&pageSize=100&sortKey=APPROVED_DATE&sortOrder=DESC', { waitUntil: 'domcontentloaded', timeout: 25000 });
          await p.waitForTimeout(4000);
          const progs = await p.evaluate(() => {
            const out = new Map();
            for (const a of document.querySelectorAll('a[href*="programId="]')) {
              const id = (a.href.match(/programId=(s\d+)/) || [])[1];
              if (!id || out.has(id)) continue;
              const box = a.closest('tr, li, article, section, div[class*=card], div[class*=item]') || a.parentElement;
              const name = (box ? box.innerText : '').split('\n').map((x) => x.trim())
                .find((x) => x.length > 2 && !/円|%|％|プログラム詳細|広告リンク作成|報酬|^\d/.test(x)) || '';
              out.set(id, name.slice(0, 60));
            }
            return [...out.entries()];
          });
          st.partnered = progs.length;
          lines.push(`## 参加中プログラム（${progs.length} 件）`, '', '| programId | 名前 |', '| --- | --- |', ...progs.map(([id, n]) => `| ${id} | ${n.replace(/\|/g, '／')} |`), '');
          await p.goto('https://media-console.a8.net/program/search/top', { waitUntil: 'domcontentloaded', timeout: 25000 });
          await p.waitForTimeout(3000);
          const form = await p.evaluate(() => [...document.querySelectorAll('form')].map((f) => ({
            action: f.action, method: f.method,
            fields: [...f.querySelectorAll('input, select')].map((e) => `${e.tagName.toLowerCase()}[${e.type || ''}] name=${e.name}`).slice(0, 20),
          })));
          lines.push('## プログラム検索のフォーム（次の回で検索に使う）', '', '```json', JSON.stringify(form, null, 1).slice(0, 3000), '```', '');
        }
        if (pr.id === 'rakuten') {
          st.affiliateIds = [...new Set(d.rakutenIds)];
          lines.push(`## 楽天アフィリエイト ID`, '', st.affiliateIds.length ? st.affiliateIds.map((x) => `- \`${x}\``).join('\n') : '（ページ内に見つからなかった）', '');
        }
        st.menus = d.menus.length;
      }
    } catch (e) {
      st.reason = `失敗: ${String(e).slice(0, 160)}`;
      lines.push(`- ⚠️ ${st.reason}`);
    }
    fs.writeFileSync(path.join(OUTDIR, `${pr.id}.md`), lines.join('\n') + '\n');
  }
  await p.close().catch(() => {});
}

const file = path.join(OUTDIR, 'status.json');
fs.writeFileSync(file, JSON.stringify(status, null, 2) + '\n');
JSON.parse(fs.readFileSync(file, 'utf8')); // 壊れた JSON を出さない（最上位ルール 13）
for (const [id, st] of Object.entries(status.providers)) {
  console.log(`${id}: ${st.loggedIn ? 'ログイン済み' : 'ログインできていない'}${st.reason ? ` / ${st.reason}` : ''}${st.affiliateIds ? ` / 楽天ID ${st.affiliateIds.length} 件` : ''}`);
}
if (status.error) console.log(status.error);
process.exit(0);
