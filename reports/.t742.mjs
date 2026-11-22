import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const AFF = '587f2635.77bb335f.587f2636.e34c8733';
const hgc = (u) => `https://hb.afl.rakuten.co.jp/hgc/${AFF}/?pc=${encodeURIComponent(u)}&m=${encodeURIComponent(u)}`;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし（ログインの情報を持ち込まない）
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 235000 - (Date.now() - t0);
// [key, 同じショップの同じ型番で当たりを付けた楽天の URL（無ければ null）, 楽天の検索語, 商品名に必ず含む語]
const L = [
  ['o-irodori-saiko', null, '彩りの里 彩幸 田中屋 おせち 2027', ['彩幸']],
  ['o-senga-omotenashi', null, '千賀屋謹製 おもてなし おせち 2027 冷蔵', ['おもてなし', '千賀屋']],
  ['o-hisamatsu-50', null, '博多久松 おせち 2027 8寸 3段重 50品', ['久松', '50品']],
  ['o-belluna-nozomi', null, 'ベルーナ おせち 2027 希 46品', ['希', '46品']],
  ['o-senga-omoiyari', null, '千賀屋謹製 おもいやり おせち 2027 冷蔵', ['おもいやり', '千賀屋']],
  ['o-takumi-kouga', null, '中村孝明 煌賀 おせち 2027', ['煌賀']],
  ['o-itamae-hishou', null, '板前魂の飛翔 おせち 2027', ['飛翔']],
  ['o-kouragumi-tsunuga', null, '甲羅組 おせち 角鹿 2027', ['角鹿']],
  ['k-kouragumi-100007', 'https://item.rakuten.co.jp/kouragumi/100007/', '甲羅組 カット生ずわい蟹 特盛 1.8kg 総重量2.4kg', ['1.8kg']],
  ['k-kouragumi-240021', 'https://item.rakuten.co.jp/kouragumi/240021/', '甲羅組 ボイルたらばがに 爪 1kg 解凍後800g', ['爪']],
  ['k-kouragumi-100075', 'https://item.rakuten.co.jp/kouragumi/100075/', '甲羅組 ボイルずわいがに メガ盛り 3kg', ['3kg']],
  ['k-masuyone-taraba850', 'https://item.rakuten.co.jp/masuyone/taraba-asi850/', 'ますよね 本タラバ脚 1肩 総重量1kg 正味900g', ['正味900g']],
  ['k-kanisho-71316', 'https://item.rakuten.co.jp/kanisho/71316/', '超特大タラバガニ肩付脚 1肩2kg 9L', ['71316']],
  ['k-kanidokoro-404', 'https://item.rakuten.co.jp/kanidokoro/404/', '超特大9L ボイルたらば 半むき身満足セット 1.8kg', ['半むき身']],
  ['k-sfdymt-bt00041', 'https://item.rakuten.co.jp/sfd-ymt/bt-00041/', 'カット済み 特大タラバ蟹 1kg YAMATO', ['カット済']],
  ['k-morigen-zkani014', 'https://item.rakuten.co.jp/morigen/zkani-014/', '森源 プレミアムずわい蟹ポーション 1kg 太脚棒肉100%', ['ポーション']],
];
const ok = (t, must) => must.every((m) => t.includes(m));
async function open(key, u, tag) {
  await p.goto(hgc(u), { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(2500);
  const ti = await p.title();
  const fin = p.url();
  const t = await p.evaluate(() => document.body ? document.body.innerText : '');
  const price = (t.match(/([\d,]+)\s*円/) || [])[1] || '';
  fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${fin}\nFROM: ${u}\n\n${t.slice(0, 30000)}`);
  console.log(`- ${key} [${tag}] 楽天の成果リンク → **${fin.split('?')[0]}**（最初の価格表示 ${price} 円）「${ti.slice(0, 90)}」`);
  return { ti, fin };
}
for (const [key, guess, kw, must] of L) {
  if (left() < 14000) { console.log(`- ⏱ ${key} 以降は時間切れ`); break; }
  try {
    if (guess) {
      const r = await open(key, guess, '同じ型番');
      if (/item\.rakuten\.co\.jp/.test(r.fin) && !/エラー|見つかりません|ページが表示できません/.test(r.ti)) continue;
      console.log(`  - 当たりなし → 検索`);
    }
    await p.goto(`https://search.rakuten.co.jp/search/mall/${encodeURIComponent(kw)}/`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3000);
    const items = await p.evaluate(() => {
      const seen = new Map();
      for (const a of document.querySelectorAll('a[href*="item.rakuten.co.jp/"]')) {
        const m = a.href.match(/^https:\/\/item\.rakuten\.co\.jp\/[^/]+\/[^/?#]+\//); if (!m) continue;
        const t = (a.innerText || a.title || '').replace(/\s+/g, ' ').trim();
        if (t.length > (seen.get(m[0]) || '').length) seen.set(m[0], t);
      }
      return [...seen].slice(0, 10);
    });
    console.log(`  - 検索「${kw}」: ${items.length} 件`);
    for (const [u, t] of items.slice(0, 5)) console.log(`    - ${t.slice(0, 80)} — ${u}`);
    const hit = items.find(([u, t]) => ok(t, must) && !/ふるさと納税/.test(t));
    if (hit) await open(key, hit[0], '検索の一致'); else console.log(`  - ⚠️ ${key}: 商品名に ${must.join('・')} を含む当たりなし`);
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 120)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
