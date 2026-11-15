import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const fs = await import('node:fs');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 });
const DIR = process.env.SHOT_DIR; fs.mkdirSync(DIR, { recursive: true });
const t0 = Date.now();
async function open(u){ await p.goto(u,{waitUntil:'domcontentloaded',timeout:25000}).catch(e=>console.log(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`)); await p.waitForTimeout(4000); }
// ① SPU の表を行ごと
await open('https://event.rakuten.co.jp/campaign/point-up/everyday/point/');
const rows = await p.evaluate(()=>[...document.querySelectorAll('table')].map((tb,ti)=>[...tb.querySelectorAll('tr')].map(tr=>`T${ti}| `+[...tr.children].map(c=>c.innerText.replace(/\s+/g,' ').trim()).join(' | ')).filter(x=>x.length<600)).flat()).catch(()=>[]);
console.log(`\n## SPU の表（${rows.length} 行）`); for (const r of rows.slice(0,120)) console.log(`- ${r.slice(0,420)}`);
// 表が無いときのために、「月間獲得上限」の近くの塊を出す
const blocks = await p.evaluate(()=>[...document.querySelectorAll('li,div,dl,section')].filter(e=>/月間獲得上限|上限なし/.test(e.innerText||'') && (e.innerText||'').length<900).map(e=>e.innerText.replace(/\s+/g,' ').trim())).catch(()=>[]);
const uniq=[...new Set(blocks)].sort((a,b)=>a.length-b.length).slice(0,25);
console.log(`\n## 「上限」を含む小さい塊（${uniq.length}）`); for (const u of uniq) console.log(`- ${u.slice(0,600)}`);
// ② FAQ の「上限」を開いて読む
for (const u of ['https://event.rakuten.co.jp/campaign/point-up/everyday/point/','https://event.rakuten.co.jp/campaign/point-up/marathon/guide/']) {
  if (Date.now()-t0>190000) { console.log('- ⏱ 時間切れ'); break; }
  await open(u);
  const qs = p.locator('text=/上限/');
  const n = Math.min(await qs.count().catch(()=>0), 12);
  for (let i=0;i<n;i++){ await qs.nth(i).click({timeout:2000}).catch(()=>{}); await p.waitForTimeout(400); }
  const ans = await p.evaluate(()=>{const t=(document.body.innerText||'').split('\n').map(x=>x.trim()).filter(Boolean); const out=[]; t.forEach((x,i)=>{ if(/上限/.test(x)) out.push(t.slice(i,i+6).join(' ／ ')); }); return [...new Set(out)].filter(x=>!/あなた|保有|現在の/.test(x)).slice(0,30);}).catch(()=>[]);
  console.log(`\n## FAQ（上限）｜${u}`); for (const a of ans) console.log(`- ${a.slice(0,500)}`);
}
await p.close().catch(() => {});
process.exit(0);
