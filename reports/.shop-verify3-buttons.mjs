// 3 店ボタン（楽天・Yahoo!・Amazon）を本番の記事で 1 つずつ押し、着いた先を確かめて写真を残す（2026-10-31 利用者の指示
// 「すべて、確実にそこからの購入で商品が購入できるかどうかを確認してその証跡も私に見せて」）。**読むだけ。カートに入れない・買わない。**
//   - 押し方: 記事のページでボタンを本当にクリックする（Yahoo! はクリックの瞬間に LinkSwitch が成果リンクへ差し替えるため、URL を直接開くと確かめられない）
//   - 見るもの: 途中の URL（アフィリエイトの転送を通ったか）・着いた先の URL に印が残るか・商品が出ているか（検索結果の件数／「カートに入れる」）・型番が画面にあるか
//   - 写真: $OPS_REPORT_DIR/shop-verify/<slug>/NN-<店>.jpg（公開ブランチ ops/heartbeat に載る）
// 使い方: SLUG=<記事> node verify-buttons.mjs   LLM 不使用・$0
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const PW_DIR = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')]
  .find((d) => fs.existsSync(path.join(d, 'playwright-core')));
if (!PW_DIR) { console.log('playwright-core が無い'); process.exit(0); }
const { chromium } = createRequire(path.join(PW_DIR, 'x.js'))('playwright-core');
const SLUG = process.env.SLUG || '';
const STORE = process.env.STORE || '';
const MATCH = process.env.MATCH || '';   // 取り直し: リンクにこの文字を含むボタンだけ（| で複数）
const BUDGET = Number(process.env.VERIFY_BUDGET_MS || 250000);
const t0 = Date.now();
const OUT = path.join(process.env.OPS_REPORT_DIR || '/tmp', 'shop-verify', SLUG);
fs.mkdirSync(OUT, { recursive: true });
const rows = [];
const lines = [`# 3 店ボタンの確認: ${SLUG}（scripts/shop/verify-buttons.mjs・**$0**）`, '', `生成: **${new Date().toISOString()}**`, ''];

const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
const ctx = b.contexts()[0] || (await b.newContext());
// 新しいタブの最初の転送から拾うため、押す前から全体で見張る（タブができてから付けると最初の転送を取りこぼす）
const NAV = [];
ctx.on('request', (r) => { try { if (r.isNavigationRequest()) NAV.push({ page: r.frame().page(), url: r.url() }); } catch {} });
const art = await ctx.newPage();
await art.setViewportSize({ width: 1280, height: 900 }).catch(() => {});
await art.goto(`https://daily-hack.fieldbeside.com/posts/${SLUG}/`, { waitUntil: 'domcontentloaded', timeout: 30000 });
await art.waitForTimeout(4000);   // LinkSwitch（vcdal.js）の読み込みを待つ
const btns = await art.evaluate(() => {
  const seen = new Set(); const out = [];
  for (const a of document.querySelectorAll('a.shop-btn')) {
    const store = (a.className.match(/shop-btn--(rakuten|yahoo|amazon)/) || [])[1]; const href = a.getAttribute('href');
    if (!store || seen.has(href)) continue; seen.add(href);
    // 商品名（ボタンの入っている箱の見出し）
    const box = a.closest('.shop-card, .shop-box, section, div[class*="shop"]');
    const name = ((box && box.querySelector('h3, h4, .shop-name, strong')) || {}).textContent || '';
    out.push({ store, href, name: name.replace(/\s+/g, ' ').trim().slice(0, 60) });
  }
  return out;
});
if (STORE) btns.splice(0, btns.length, ...btns.filter((x) => x.store === STORE));
if (MATCH) btns.splice(0, btns.length, ...btns.filter((x) => MATCH.split('|').some((m) => x.href.includes(m))));
lines.push(`- 記事のボタン（同じリンクは 1 回だけ${STORE ? '・' + STORE + ' だけ' : ''}）: ${btns.length} 個`, `- LinkSwitch のスクリプト: ${await art.evaluate(() => !!document.querySelector('script[src*="vcdal.js"]') && typeof window.vc_pid !== 'undefined' ? '読み込まれている（vc_pid=' + window.vc_pid + '）' : '**無い**')}`, '');

const model = (h) => { try { const u = new URL(h); const q = u.searchParams.get('k') || decodeURIComponent((u.searchParams.get('pc') || '').match(/mall\/([^/]+)/)?.[1] || '') || u.searchParams.get('p') || ''; return decodeURIComponent(q).replace(/\+/g, ' ').trim(); } catch { return ''; } };
// SHOP_JSON: src/data/shop/<シリーズ>.json（タスクが origin/main から取り出して渡す）。押したリンクから商品を引く
const SHOP = (() => { try { return JSON.parse(fs.readFileSync(process.env.SHOP_JSON || '', 'utf8')).items || []; } catch { return []; } })();
const itemOf = (bt) => SHOP.find((x) => (bt.store === 'yahoo' && x.yahoo?.url && bt.href.startsWith(x.yahoo.url))
  || (bt.store === 'amazon' && x.amazon?.asin && bt.href.includes(`/dp/${x.amazon.asin}`))
  || (bt.store === 'rakuten' && x.rakuten?.itemUrl && decodeURIComponent(bt.href).includes(x.rakuten.itemUrl))
  || (x[bt.store]?.keyword && model(bt.href) === x[bt.store].keyword)) || null;
let i = 0;
for (const bt of btns) {
  if (Date.now() - t0 > BUDGET) { lines.push(`- ⚠️ 時間切れで ${btns.length - i} 個を残した（次の回で続ける）`); break; }
  i++;
  const n = String(i).padStart(2, '0');
  let q = null;
  try {
    // 記事の中のボタンを本当に押す（target=_blank なので新しいタブで開く）
    const idx = await art.evaluate((h) => [...document.querySelectorAll('a.shop-btn')].findIndex((a) => a.getAttribute('href') === h), bt.href);
    const el = (await art.$$('a.shop-btn'))[idx];
    await el.scrollIntoViewIfNeeded().catch(() => {});
    // 押す前のタブを控え、押したあとに増えたタブのうち「記事のページから開いたもの」だけを採る
    // （同じ Chrome で X の作業が開いたタブを取り違えた・2026-10-31）
    const before = new Set(ctx.pages());
    await el.click({ modifiers: [] });
    let np = null; const tc = Date.now();
    while (!np && Date.now() - tc < 15000) {
      for (const pg of ctx.pages()) if (!before.has(pg) && (await pg.opener().catch(() => null)) === art) { np = pg; break; }
      if (!np) await art.waitForTimeout(300);
    }
    if (!np) throw new Error('押したあと 15 秒で記事のページから開いたタブが無い');
    q = np;
    await q.waitForLoadState('domcontentloaded', { timeout: 30000 }).catch(() => {});
    await q.waitForTimeout(4500);
    await q.setViewportSize({ width: 1280, height: 900 }).catch(() => {});
    const fin = q.url();
    const chain = [...new Set([...NAV.filter((x) => x.page === q).map((x) => x.url), fin])];
    const m = model(bt.href);
    // 型番の照合キー: 英字と数字を両方含む 4 文字以上の語のうち最長のもの。無ければ全部の語（2026-10-31・検索欄の文字で「あり」になる誤りを直した）
    // 商品データ（src/data/shop/<シリーズ>.json の must）があればそれを使う
    const it = itemOf(bt);
    const toks = (it ? (it.amazon?.keyword || it.rakuten?.keyword || '') : m).split(/\s+/).filter(Boolean);
    const mt = toks.filter((t) => /\d/.test(t) && /[A-Za-z]/.test(t) && t.length >= 4).sort((a, z) => z.length - a.length);
    const keys = it?.rakuten?.must || it?.yahoo?.must || (mt.length ? [mt[0]] : toks);
    if (it) bt.name = `${it.brand || ''} ${it.name}`.trim();
    const info = await q.evaluate(([m, keys, store]) => {
      const t = document.body.innerText || '';
      const norm = (s) => s.toLowerCase().replace(/[\s\-‐－]/g, '');
      return {
        title: document.title.slice(0, 90),
        robot: /ロボットではありません|captcha|Enter the characters|アクセスが集中/i.test(t),
        cart: /カートに入れる|カートに追加|今すぐ買う|購入手続き|買い物かごに入れる|かごに追加/.test(t),
        amazonResults: document.querySelectorAll('[data-component-type="s-search-result"]').length,
        rakutenResults: document.querySelectorAll('.searchresultitem, [class*="searchresultitem"], [data-testid*="item"]').length,
        yahooResults: document.querySelectorAll('[class*="SearchResult"] li, li[class*="LoopList"]').length,
        noHit: /該当する商品が見つかりません|検索結果がありません|に一致する商品は見つかりませんでした|見つかりませんでした/.test(t),
        modelOnPage: m ? norm(t).includes(norm(m.split(' ').slice(-1)[0])) : null,
        // 検索結果の 1 件ずつ（広告の枠・検索欄・見出しは見ない）に型番が入っているか
        ...(() => {
          const sel = { amazon: '[data-component-type="s-search-result"]', rakuten: '.searchresultitem, [class*="searchresultitem"]', yahoo: 'li[class*="LoopList"], [class*="SearchResult"] li' }[store];
          const lnk = { amazon: 'a[href*="/dp/"]', rakuten: 'a[href*="item.rakuten.co.jp"]', yahoo: 'a[href*="store.shopping.yahoo.co.jp"]' }[store];
          let els = [...document.querySelectorAll(sel)];
          if (!els.length) els = [...document.querySelectorAll(lnk)];
          const items = els.map((e) => (e.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean).sort((a, z) => z.length - a.length).find((x) => x.length <= 160) || '').filter(Boolean);
          const hit = (x) => keys.every((k) => norm(x).includes(norm(k)));
          const h1 = (document.querySelector('h1') || {}).innerText || '';
          return { keys, items: items.length, hits: items.filter(hit).length, hitTitles: items.filter(hit).slice(0, 3).map((x) => x.slice(0, 90)), top: items.slice(0, 3).map((x) => x.slice(0, 90)), titleHit: hit(document.title + ' ' + h1), h1: h1.slice(0, 90) };
        })(),
      };
    }, [m, keys, bt.store]).catch(() => ({}));
    let aff = '';
    if (bt.store === 'rakuten') aff = /scid=af_pc_etc/.test(fin) ? '着いた先の URL に scid=af_pc_etc（楽天アフィリエイト経由の印）' + (chain.some((u) => /hb\.afl\.rakuten\.co\.jp/.test(u)) ? '・途中で hb.afl.rakuten.co.jp を通った' : '') : '**印が見つからない**';
    if (bt.store === 'amazon') aff = /[?&]tag=dailyhack-22(&|$)/.test(fin) ? '着いた先の URL に tag=dailyhack-22（アソシエイトの印）' : '**tag=dailyhack-22 が無い**';
    if (bt.store === 'yahoo') aff = chain.some((u) => /valuecommerce\.com/.test(u)) || /sc_e=afvc|[?&]vc_/.test(fin) ? 'バリューコマースの転送を通った（LinkSwitch で成果リンクに差し替わった）' : '**バリューコマースを通っていない（素のリンクのまま）**';
    const buy = info.cart && info.titleHit ? 'その商品のページ（カートに入れるボタンあり）' : info.hits > 0 ? `検索結果 ${info.items} 件のうち、型番「${info.keys.join(' ')}」の商品が ${info.hits} 件` : info.cart ? `商品ページだが題名に「${info.keys.join(' ')}」が無い（要目視）` : `**検索結果 ${info.items ?? 0} 件に型番「${(info.keys || []).join(' ')}」の商品が無い**`;
    const found = bt.store === 'amazon' ? `検索結果 ${info.amazonResults ?? '—'} 件` : bt.store === 'rakuten' ? `検索結果 ${info.rakutenResults ?? '—'} 件` : (info.cart ? '商品ページ（カートに入れるボタンあり）' : `検索結果 ${info.yahooResults ?? '—'} 件`);
    const shot = `${process.env.SHOT_PREFIX || (MATCH ? 'r' : '')}${n}-${bt.store}.jpg`;
    await q.screenshot({ path: path.join(OUT, shot), type: 'jpeg', quality: 55 }).catch(() => {});
    rows.push({ n, store: bt.store, name: bt.name, model: m, href: bt.href, chain, fin, aff, found, buy, ...info, shot });
    lines.push(`## ${n} ${bt.store}｜${bt.name || m}`, `- 押したリンク: ${bt.href}`, `- 途中: ${chain.slice(0, -1).map((u) => u.slice(0, 140)).join(' → ') || '（転送なし）'}`, `- 着いた先: ${fin.slice(0, 200)}`,
      `- アフィリエイト: ${aff}`, `- 買えるか: ${buy}${info.hitTitles?.length ? '（' + info.hitTitles[0] + '）' : ''}`, `- 商品: ${found}・型番「${m}」の表示: ${info.modelOnPage == null ? '—' : info.modelOnPage ? 'あり' : '**無い**'}${info.noHit ? '・**該当なしの表示**' : ''}${info.robot ? '・**ロボット確認の画面**' : ''}${info.cart ? '・カートに入れるボタンあり' : ''}`,
      `- 題名: ${info.title || '—'}`, `- 写真: shop-verify/${SLUG}/${shot}`, '');
  } catch (e) {
    lines.push(`## ${n} ${bt.store}｜${bt.name}`, `- ⚠️ 押せなかった: ${String(e).split('\n')[0].slice(0, 200)}`, '');
    rows.push({ n, store: bt.store, name: bt.name, href: bt.href, error: String(e).split('\n')[0].slice(0, 200) });
  }
  if (q) await q.close().catch(() => {});
}
await art.close().catch(() => {});
fs.writeFileSync(path.join(OUT, `result${STORE ? '-' + STORE : ''}${MATCH ? '-retry' : ''}${process.env.OUT_SUFFIX || ''}.json`), JSON.stringify({ slug: SLUG, generated: new Date().toISOString(), total: btns.length, rows }, null, 1));
fs.writeFileSync(path.join(OUT, `report${STORE ? '-' + STORE : ''}${MATCH ? '-retry' : ''}${process.env.OUT_SUFFIX || ''}.md`), lines.join('\n'));
console.log(lines.slice(0, 6).join('\n'));
console.log(`対象 ${btns.length} 個 / 確かめた ${rows.length} 個`);
process.exit(0);
