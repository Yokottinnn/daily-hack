// 作戦室に出す X の数字を、X の画面から読む（Mac・CDP・**読むだけ・押さない・投稿しない・LLM 不使用で $0**）。
// 2026-10-19 利用者「数字が更新されていないよ。Xのフォロワーの数とか全然最新じゃないし」。
// それまで作戦室の X の数字は docs/growth-strategy.md の手書きの表（10/12）から出ていて、誰も更新していなかった。
//
//   ① プロフィールのヘッダー（フォロー中・フォロワー）… 走査ではなくヘッダー（最上位ルール 19）
//   ② アナリティクス 7 日（インプレッション・プロフィールへのアクセス・認証済みのフォロワー）
//   ③ アナリティクス 3 か月（インプレッション・プロフィールへのアクセス）
//   ④ オリジナルコンテンツ報酬の条件（認証済みフォロワー・90 日の認証済みインプレッション）
//
// 使い方: node x-numbers.js <out.json>   （mac-weekly.sh と ops/tasks から呼ぶ）
// **自分で開いたタブだけ閉じる。** 共有の Chrome の他のタブには触らない（t314 で X のタブを閉じてしまった）。
const fs = require('fs');
const { chromium } = require('playwright-core');
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || 'http://127.0.0.1:18810';
const HANDLE = process.env.X_HANDLE || 'heng_ji31590';
const out = process.argv[2] || 'x-numbers.json';

// 「ラベル\n値」の値を拾う。値は 26.7K / 1,234 / 198 のような数字
function after(text, label) {
  const lines = text.split('\n').map((s) => s.trim());
  for (let i = 0; i < lines.length; i++) {
    if (lines[i] === label && /^[\d.,]+[KM万]?$/.test(lines[i + 1] || '')) return lines[i + 1];
  }
  return null;
}
function num(v) {
  if (v == null) return null;
  const m = String(v).replace(/,/g, '').match(/^([\d.]+)([KM万]?)$/);
  if (!m) return null;
  const k = { K: 1e3, M: 1e6, 万: 1e4 }[m[2]] || 1;
  return Math.round(parseFloat(m[1]) * k);
}

(async () => {
  const r = { generated: new Date().toISOString(), handle: HANDLE };
  let b, page;
  try {
    // 接続は一時的に落ちることがある（2026-10-19、shared_worker の assert で t324 が落ちた）。3 回まで試す
    for (let i = 1; i <= 3 && !b; i++) {
      try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
      catch (e) { r.connectErrors = (r.connectErrors || []).concat(String(e && e.message).slice(0, 120)); await new Promise((ok) => setTimeout(ok, 10000)); }
    }
    if (!b) throw new Error('CDP に 3 回つながらなかった');
    page = await b.contexts()[0].newPage();

    // ① ヘッダー
    await page.goto(`https://x.com/${HANDLE}`, { waitUntil: 'domcontentloaded', timeout: 40000 });
    await page.waitForSelector('a[href$="/following"]', { timeout: 25000 }).catch(() => {});
    await page.waitForTimeout(3000);
    const links = await page.$$eval('a[href$="/following"], a[href$="/followers"], a[href$="/verified_followers"]',
      (as) => as.map((a) => ({ href: a.getAttribute('href'), text: a.innerText.replace(/\s+/g, ' ').trim() })));
    const pick = (re) => { const l = links.find((x) => re.test(x.href)); return l ? l.text : null; };
    const fing = pick(/\/following$/), fers = pick(/\/(verified_)?followers$/);
    r.header = { following: num((fing || '').split(' ')[0]), followers: num((fers || '').split(' ')[0]), raw: { following: fing, followers: fers } };
    // 読めなかったときは、何が出ていたかを残す（2026-10-22、全部 null で原因が分からなかった）
    if (!r.header.followers) r.debug = { url: page.url(), title: await page.title().catch(() => ''), text: (await page.evaluate(() => document.body.innerText).catch(() => '')).slice(0, 300) };

    // ② アナリティクス 7 日（既定の表示）
    await page.goto('https://x.com/i/account_analytics', { waitUntil: 'domcontentloaded', timeout: 40000 });
    await page.waitForTimeout(6000);
    // **期間は前回押したものが残る**（2026-10-19、7D と 3M が同じ 173.6K で出た）。先に 7D を押してから読む
    const d7tab = page.getByText('7D', { exact: true }).first();
    if (await d7tab.count()) { await d7tab.click({ timeout: 8000 }).catch(() => {}); await page.waitForTimeout(5000); }
    let t = await page.evaluate(() => document.body.innerText);
    const ver = t.match(/認証済みのフォロワー\n([\d,]+)\n[\s\S]*?\/ \n([\d,]+)/);
    r.d7 = {
      impressions: num(after(t, 'インプレッション数')),
      profileVisits: num(after(t, 'プロフィールへのアクセス数')),
      engagements: num(after(t, 'エンゲージメント')),
      verifiedFollowers: ver ? num(ver[1]) : null,
      followersOnPage: ver ? num(ver[2]) : null,
    };
    // ③ 3 か月（タブを押すだけ。設定は変えない）
    const tab = page.getByText('3M', { exact: true }).first();
    if (await tab.count()) {
      await tab.click({ timeout: 8000 }).catch(() => {});
      await page.waitForTimeout(5000);
      t = await page.evaluate(() => document.body.innerText);
      r.d90 = { impressions: num(after(t, 'インプレッション数')), profileVisits: num(after(t, 'プロフィールへのアクセス数')) };
    }

    // ④ オリジナルコンテンツ報酬の条件（読むだけ。申し込まない）
    await page.goto('https://x.com/i/jf/creators/original_content_rewards', { waitUntil: 'domcontentloaded', timeout: 40000 });
    await page.waitForTimeout(6000);
    t = await page.evaluate(() => document.body.innerText);
    const vf = t.match(/認証済みフォロワーが500人以上[^\n]*\n[\s\t]*\n?[\s\t]*([\d,]+)/);
    const vi = t.match(/認証済みインプレッションが50万回以上[^\n]*\n[\s\t]*\n?[\s\t]*([\d,]+)/);
    r.ocr = { verifiedFollowers: vf ? num(vf[1]) : null, verifiedImpressions90: vi ? num(vi[1]) : null, eligible: /対象外|あと少し/.test(t) ? false : null };
  } catch (e) {
    r.error = String(e && e.message).slice(0, 300);
  } finally {
    if (page) await page.close().catch(() => {});
  }
  fs.writeFileSync(out, JSON.stringify(r, null, 1));
  JSON.parse(fs.readFileSync(out, 'utf8')); // 書いた物を自分で読み直す（最上位ルール 13）
  console.log(JSON.stringify(r));
  process.exit(0);
})();
