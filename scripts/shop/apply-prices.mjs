#!/usr/bin/env node
// Mac が取った価格（ops/heartbeat の reports/board/shop-prices.json）を src/data/shop/<シリーズ>.json に書き込む。LLM 不使用・$0。
//   node scripts/shop/apply-prices.mjs                 … origin/ops/heartbeat から読む（先に git fetch する）
//   node scripts/shop/apply-prices.mjs --in <file>     … 手元のファイルから
// 当たりが無かった店は価格を消す（古い価格を出さない）。鍵が無くて取っていない店（skipped）とエラーの店は前回の値を残す。
// 取り直しが 8 日より古ければ書かずに止める（古いものを新しい日付で載せない）。
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const args = Object.fromEntries(process.argv.slice(2).map((a, i, all) => a.startsWith('--') ? [a.slice(2), all[i + 1]] : null).filter(Boolean));
let txt;
if (args.in) txt = fs.readFileSync(args.in, 'utf8');
else {
  try { execFileSync('git', ['-C', ROOT, 'fetch', '-q', 'origin', 'ops/heartbeat:refs/remotes/origin/ops/heartbeat'], { stdio: 'ignore' }); } catch {}
  txt = execFileSync('git', ['-C', ROOT, 'show', 'origin/ops/heartbeat:reports/board/shop-prices.json'], { encoding: 'utf8' });
}
const P = JSON.parse(txt);
const age = (Date.now() - new Date(P.generatedAt)) / 864e5;
if (!(age <= 8)) { console.error(`shop-prices.json が古い（${P.generatedAt}）。書かずに止める`); process.exit(1); }

const R_KEYS = ['itemUrl', 'price', 'postageIncluded', 'pointRate', 'reviewAverage', 'reviewCount', 'shop'];
const Y_KEYS = ['url', 'price', 'shippingFree', 'point', 'reviewAverage', 'reviewCount', 'shop'];
let changed = 0;
for (const [sid, rows] of Object.entries(P.series || {})) {
  const file = path.join(ROOT, 'src/data/shop', `${sid}.json`);
  if (!fs.existsSync(file)) continue;
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  const before = changed;
  for (const it of data.items || []) {
    const row = rows[it.id] || {};
    for (const [store, keys] of [['rakuten', R_KEYS], ['yahoo', Y_KEYS]]) {
      const got = row[store];
      if (!got || got.skipped || got.error || !it[store]) continue;
      for (const k of keys) it[store][k] = got.found ? (got[k] ?? null) : null;
      it[store].checkedAt = P.generatedAt;
      changed++;
    }
  }
  if (changed === before) continue;
  data.pricesCheckedAt = P.generatedAt;
  fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n');
}
console.log(`shop: ${changed} 件の店の価格を書いた（取得 ${P.generatedAt}・エラー ${(P.errors || []).length} 件）`);
