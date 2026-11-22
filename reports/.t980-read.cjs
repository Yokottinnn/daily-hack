const fs = require('fs'), path = require('path'), os = require('os');
const PW = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')].find((d) => fs.existsSync(path.join(d, 'playwright-core')));
if (!PW) { console.log('playwright-core が無い'); process.exit(0); }
const { chromium } = require(path.join(PW, 'playwright-core'));
const QS = [['象印 炎舞炊き NX-AB10', 'NX-AB10'], ['象印 圧力IH NW-YD10', 'NW-YD10'], ['アイリスオーヤマ 食洗機', '']];
(async () => {
  const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
  const ctx = b.contexts()[0] || (await b.newContext());
  for (const [q, key] of QS) {
    const p = await ctx.newPage();
    try {
      await p.goto(`https://shopping.yahoo.co.jp/search?p=${encodeURIComponent(q)}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await p.waitForTimeout(5000);
      const r = await p.evaluate((key) => {
        const norm = (s) => (s || '').toLowerCase().replace(/[\s\-‐－]/g, '');
        const cls = (e) => (typeof e.className === 'string' ? e.className : '').split(/\s+/).filter(Boolean).slice(0, 4).join('.');
        const chain = (e, n) => { const o = []; let x = e; for (let i = 0; i < n && x && x !== document.body; i++, x = x.parentElement) o.push(x.tagName.toLowerCase() + (x.id ? '#' + x.id : '') + (cls(x) ? '.' + cls(x) : '')); return o.join(' < '); };
        const dattrs = (e) => [...e.attributes].map((a) => a.name).filter((n) => n.startsWith('data-') || n === 'role' || n === 'aria-label').join(',');
        const hosts = (e) => [...new Set([...e.querySelectorAll('a[href]')].map((a) => { try { const u = new URL(a.href); return u.hostname + u.pathname.split('/').slice(0, 2).join('/'); } catch { return ''; } }).filter(Boolean))].slice(0, 4).join(' ');
        const labelOf = (e) => [...e.querySelectorAll('*')].map((x) => (x.children.length === 0 ? (x.textContent || '').trim() : '')).filter((t) => /^(PR|広告|スポンサー|Sponsored|AD|Ad)$/.test(t));
        // 1) 今の道具のセレクタ
        const cur = [...document.querySelectorAll('li[class*="LoopList"], [class*="SearchResult"] li')];
        // 2) 商品リンクを持つ箱を全部（親の作りを見る）
        const lis = [...new Set([...document.querySelectorAll('a[href*="store.shopping.yahoo.co.jp"], a[href*="paypaymall.yahoo.co.jp"], a[href*="//ard.yahoo"], a[href*="shopping.yahoo.co.jp/product"]')].map((a) => a.closest('li') || a.closest('[class*="item" i]') || a.parentElement))];
        const rows = lis.slice(0, 40).map((e, i) => ({ i, inCur: cur.includes(e), chain: chain(e, 5), data: dattrs(e), hosts: hosts(e), labels: labelOf(e).join('/'), hasKey: key ? norm(e.innerText).includes(norm(key)) : null, len: (e.innerText || '').length }));
        // 3) 「PR」「広告」だけの葉の要素の場所
        const leaves = [...document.querySelectorAll('span, div, p, em, i, small, b')].filter((x) => x.children.length === 0 && /^(PR|広告|スポンサー|Sponsored)$/.test((x.textContent || '').trim())).slice(0, 15).map((x) => ({ text: x.textContent.trim(), chain: chain(x, 7) }));
        const groups = {}; for (const r of rows) { const k = r.chain.split(' < ').slice(0, 3).join(' < '); groups[k] = (groups[k] || 0) + 1; }
        return { title: document.title.slice(0, 80), cur: cur.length, curHit: key ? cur.filter((e) => norm(e.innerText).includes(norm(key))).length : null, lis: lis.length, rows, leaves, groups };
      }, key);
      console.log(`\n## 検索: ${q}（型番 ${key || 'なし'}）`);
      console.log(`- 題名: ${r.title}`);
      console.log(`- 今のセレクタの件数: ${r.cur}（型番を含む ${r.curHit}）／商品リンクを持つ箱: ${r.lis}`);
      console.log('- 箱の作り（上 3 段）ごとの数:'); for (const [k, v] of Object.entries(r.groups)) console.log(`  - ${v} 件: \`${k}\``);
      console.log('- 「PR」「広告」の印の場所:'); for (const l of r.leaves) console.log(`  - ${l.text}: \`${l.chain}\``);
      console.log('- 箱 1 つずつ（今のセレクタに入るか・型番を含むか・印・data 属性・リンク先）:');
      for (const x of r.rows) console.log(`  - ${x.i} cur=${x.inCur ? 1 : 0} key=${x.hasKey == null ? '-' : x.hasKey ? 1 : 0} label=${x.labels || '-'} data=${x.data || '-'} len=${x.len} hosts=${x.hosts}\n    \`${x.chain}\``);
    } catch (e) { console.log(`- ⚠️ ${q}: ${String(e).split('\n')[0].slice(0, 160)}`); }
    await p.close().catch(() => {});
  }
  process.exit(0);
})();
