import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [
 ["hotate", "https://item.rakuten.co.jp/f016918-betsukai/be018-0054/"],
 ["zuwai", "https://item.rakuten.co.jp/f042056-kesennuma/20560597/"],
 ["gyutan", "https://item.rakuten.co.jp/f016918-betsukai/ns0000020/"],
 ["chicken", "https://item.rakuten.co.jp/f452025-miyakonojo/mj-3314/"],
 ["mizutaki", "https://item.rakuten.co.jp/f402303-itoshima/aib001/"],
 ["hamburg", "https://item.rakuten.co.jp/f082112-joso/ni01095/"],
 ["rice", "https://item.rakuten.co.jp/f012246-chitose/ci007/"],
 ["salmon", "https://item.rakuten.co.jp/f016918-betsukai/mt000tz00/"]
];
// **ログインした画面の本文を保存しない**（最上位ルール「ログインが要るページの本文をレポートに保存しない」）。
// 返礼品のページは公開だが、ヘッダーに名前が出ることがあるので、配送・寄付額・内容量の行だけを抜き出す。
const KEEP = /(年内|発送|お届け|配送|着日|決済|寄付金額|内容量|容量|消費期限|賞味期限|保存方法|提供|事業者|\d+円)/;
const DROP = /(様|さん|ポイント残高|ログイン|会員|お気に入り|閲覧履歴|購入履歴|カード番号)/;
for (const [k, u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4000);
    const t = await p.evaluate(() => document.body ? document.body.innerText : '');
    const ti = await p.title();
    const lines = [...new Set(t.split('\n').map((s) => s.trim()).filter((s) => s && s.length < 260 && KEEP.test(s) && !DROP.test(s)))].slice(0, 60);
    fs.writeFileSync(`${D}/${k}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${lines.join('\n')}\n`);
    console.log(`- ${k}: ${lines.length} 行 「${ti.slice(0, 60)}」`);
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0, 100)}`); }
}
await p.close().catch(() => {});
process.exit(0);
