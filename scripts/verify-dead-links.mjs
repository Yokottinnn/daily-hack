// **`check-external-links.mjs` が「切れている」と言ったものを、実ブラウザで裏を取る。**
//
// **curl の判定だけで「切れている」と書かない**（最上位ルール 11）。
// 2026-09-27 の 1 回 目で、**生きているサイトが 404 として並んだ。**
//
//   `https://www.furusato-tax.jp/`  → 404 と出たが、**ふるさとチョイスは生きている**
//   `https://ahamo.com/`            → つながらない と出たが、**ahamo は生きている**
//   `https://www.paypay-card.co.jp/` → 404 と出たが、**PayPayカードは生きている**
//
// WAF が bot に 404 を返しているだけ。**ページを実際に開けば title で分かる。**
//
//   node scripts/verify-dead-links.mjs --in=/tmp/external-links.json --budget=260
//
// **X 運用の Chrome を借りる。** 新しいタブを開いて必ず閉じ、
// **`browser.close()` は呼ばない**（呼ぶと利用者の Chrome ごと落ちる）。
import fs from 'node:fs';
import { createRequire } from 'node:module';

const args = process.argv.slice(2);
const opt = (k, d) => {
  const a = args.find((x) => x.startsWith(`--${k}=`));
  return a ? a.split('=').slice(1).join('=') : d;
};
const IN = opt('in', '/tmp/external-links.json');
const OUT = opt('out', IN.replace(/\.json$/, '-verified.json'));
const BUDGET = Number(opt('budget', 260)) * 1000;
const PORT = opt('port', process.env.CDP_PORT || '18810');

const req = createRequire((process.env.PW_DIR || process.cwd() + '/node_modules') + '/x.js');
const { chromium } = req('playwright-core');

const data = JSON.parse(fs.readFileSync(IN, 'utf8'));
// **`403` は最初から除く。** bot を弾いているだけで、開いても同じことが多い
const suspects = data.results.filter((r) => r.status === 0 || r.status === 404
  || r.status === 410 || (r.status >= 500 && r.status < 600));
console.log(`怪しいもの ${suspects.length} 件 / 全 ${data.results.length} 件`);

const browser = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`);
const ctx = browser.contexts()[0];
const out = [];
const started = Date.now();
let stopped = false;

for (const s of suspects) {
  if (Date.now() - started > BUDGET) { stopped = true; break; }
  let page = null;
  try {
    page = await ctx.newPage();
    const resp = await page.goto(s.url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForTimeout(400);
    const title = (await page.title()).slice(0, 90);
    const final = page.url();
    // **title で見る。** HTTP の番号より、ページが何と名乗っているかのほうが確か
    const looksDead = /404|not found|お探しのページ|ページが見つかり|見つかりません|存在しません/i.test(title);
    out.push({ url: s.url, slugs: s.slugs, curl: s.status,
               http: resp ? resp.status() : null, title, final, verdict: looksDead ? 'DEAD' : 'ALIVE' });
  } catch (e) {
    out.push({ url: s.url, slugs: s.slugs, curl: s.status, http: null,
               title: null, final: null, verdict: 'OPEN_FAILED', err: String(e.message || e).slice(0, 70) });
  } finally {
    if (page) { try { await page.close(); } catch {} }
  }
}

fs.writeFileSync(OUT, JSON.stringify({ checked: out.length, suspects: suspects.length, out }, null, 1));

const by = {};
for (const r of out) (by[r.verdict] ||= []).push(r);
console.log('');
for (const k of Object.keys(by).sort()) console.log(`${k}: ${by[k].length}`);
for (const k of ['DEAD', 'OPEN_FAILED']) {
  console.log(`\n## ${k}`);
  for (const r of by[k] || []) {
    console.log(`  ${r.url}`);
    console.log(`    curl=${r.curl} http=${r.http} title=${JSON.stringify(r.title)}${r.err ? ' err=' + r.err : ''}`);
    console.log(`    ← ${r.slugs.join(' / ')}`);
  }
}
console.log('\n## ALIVE（**curl の誤判定**。記事は直さなくてよい）');
for (const r of by.ALIVE || []) console.log(`  ${r.url}  ← ${JSON.stringify(r.title)}`);
// **`browser.close()` は呼ばない。** CDP 越しに呼ぶと利用者の Chrome ごと落ちる
console.log(stopped ? `\n⏱️ 時間切れ。**${out.length}/${suspects.length} 件まで。**`
                    : `\n✅ 全部 見た（${out.length} 件）`);
process.exit(0);
