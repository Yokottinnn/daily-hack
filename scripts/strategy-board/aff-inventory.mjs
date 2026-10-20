// 記事ごとの成果リンクの一覧（どの記事に・どの ASP の・どの案件／商品のリンクが・いくつ入っているか）。
// 2026-10-17 利用者「どの記事にどのアフィリエイトサイトのどの商品やサービスのリンクを入れているか一覧で出して」
// build-snapshot.mjs から呼ぶ（毎日の作戦室の更新で入れ替わる）。単体でも動く: node scripts/strategy-board/aff-inventory.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

// A8：a8mat の 2・3 番目の区切り（案件と素材主）で案件を引き当てる。媒体 ID（1 番目）は時期でちがう
function a8Programs() {
  const src = fs.readFileSync(path.join(ROOT, 'src/data/banner-catalog.ts'), 'utf8');
  const map = new Map();
  const blocks = src.split(/\n  \{\n    id:/).slice(1);
  for (const b of blocks) {
    const name = (b.match(/name: '([^']*)'/) || [])[1] || '';
    const id = (b.match(/^\s*'([^']+)'/) || [])[1] || '';
    for (const m of b.matchAll(/a8mat=([A-Z0-9]+)\+([A-Z0-9]+)\+([A-Z0-9]+)\+/g)) map.set(`${m[2]}+${m[3]}`, { id, name: short(name) });
  }
  // 手で入れた案件（カタログに無い・2026-10-17 の即時提携）
  map.set('7284UY+4EKC', { id: 'abema', name: 'ABEMAプレミアム' });
  map.set('8MSBBU+4Z4W', { id: 'iyns', name: 'IYNSbyONIGO（イトーヨーカドーネットスーパー）' });
  map.set('6Z8YU2+5DFW', { id: 'wowow', name: 'WOWOWオンデマンド' });
  map.set('8P61QY+5YKQ', { id: 'carricare', name: 'キャリカレ（通信講座）' });
  return map;
}
function short(n) {
  const k = [...n.matchAll(/【([^】]+)】/g)].map((m) => m[1]).filter((x) => !/^(公式|NEW|新商品|当サイト限定)/.test(x));
  return (k.length ? k[k.length - 1] : n).replace(/\s+/g, ' ').slice(0, 40);
}

// 楽天：pc= の行き先で何へのリンクかを決める
function rakutenTarget(url) {
  let u; try { u = new URL(url); } catch { return { group: '楽天', item: url.slice(0, 60) }; }
  const p = decodeURIComponent(u.pathname);
  if (u.hostname === 'travel.rakuten.co.jp' || u.hostname === 'event.travel.rakuten.co.jp') {
    const h = p.match(/HOTEL\/(\d+)/); return { group: '楽天トラベル', item: h ? `宿（施設番号 ${h[1]}）` : (/sales|superdeal|special/.test(p) ? 'セール・特集のページ' : 'トップ') };
  }
  if (u.hostname === 'event.rakuten.co.jp') {
    if (/furusato/.test(p)) return { group: '楽天ふるさと納税', item: /guide/.test(p) ? 'はじめてガイド' : 'トップ' };
    if (/marathon/.test(p)) return { group: '楽天市場', item: 'お買い物マラソン' };
    if (/supersale/.test(p)) return { group: '楽天市場', item: 'スーパーSALE' };
    if (/pointday|everyday/.test(p)) return { group: '楽天市場', item: 'ポイントアップの日（5と0の日など）' };
    return { group: '楽天市場', item: `キャンペーン（${p.replace(/\/$/, '').split('/').pop()}）` };
  }
  if (u.hostname === 'search.rakuten.co.jp') { const kw = (p.match(/\/search\/mall\/([^/]+)/) || [])[1] || ''; return { group: /f=15/.test(u.search) ? '楽天ふるさと納税' : '楽天市場', item: `検索「${kw.replace(/\+/g, ' ')}」` }; }
  if (u.hostname === 'item.rakuten.co.jp') { const [, shop, item] = p.split('/'); return { group: '楽天市場', item: `商品（${shop}／${item}）` }; }
  if (u.hostname === 'www.rakuten.co.jp') return { group: '楽天市場', item: 'トップ' };
  return { group: '楽天', item: `${u.hostname}${p}`.slice(0, 60) };
}

// バリューコマース：LinkSwitch が差し替える対象（提携済みの広告主の普通のリンク）
const VC = [[/(^|\.)ikyu\.com$/, '一休.com'], [/(^|\.)jalan\.net$/, 'じゃらんnet'], [/^travel\.yahoo\.co\.jp$/, 'Yahoo!トラベル']];

export function buildInventory() {
  const a8 = a8Programs();
  const dir = path.join(ROOT, 'src/content/posts');
  const out = [];
  for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.md'))) {
    const src = fs.readFileSync(path.join(dir, f), 'utf8');
    const fm = (src.match(/^---\n([\s\S]*?)\n---/) || [])[1] || '';
    if (/^draft:\s*"?true/m.test(fm)) continue;
    const title = ((fm.match(/^title:\s*"?(.*?)"?\s*$/m) || [])[1] || '').trim();
    const isPR = /^isPR:\s*true/m.test(fm);
    const cnt = new Map();
    const add = (asp, item) => { const k = `${asp}\t${item}`; cnt.set(k, (cnt.get(k) || 0) + 1); };
    // HTML の href と Markdown の [文字](URL) の両方を拾う
    for (const m of src.matchAll(/href="(https?:\/\/[^"]+)"|\]\((https?:\/\/[^)\s]+)\)/g)) {
      const href = (m[1] || m[2]).replace(/&amp;/g, '&');
      let u; try { u = new URL(href); } catch { continue; }
      if (u.hostname === 'px.a8.net') {
        const code = ((href.match(/a8mat=([A-Z0-9+]+)/) || [])[1] || '').split('+'); // searchParams は + を空白にするので生の文字列から取る
        const hit = a8.get(`${code[1]}+${code[2]}`);
        add('A8', hit ? hit.name : `照合できない案件（${code.slice(1, 3).join('+')}）`);
      } else if (u.hostname === 'hb.afl.rakuten.co.jp') {
        const t = rakutenTarget(u.searchParams.get('pc') || '');
        add('楽天', `${t.group}：${t.item}`);
      } else {
        const v = VC.find(([re]) => re.test(u.hostname));
        if (v) add(isPR ? 'バリューコマース（LinkSwitch）' : 'バリューコマース（PR 表記なし・差し替えない）', v[1]);
      }
    }
    const items = [...cnt.entries()].map(([k, n]) => { const [asp, item] = k.split('\t'); return { asp, item, n }; })
      .sort((a, b) => a.asp.localeCompare(b.asp) || b.n - a.n);
    out.push({ slug: f.replace(/\.md$/, ''), title, isPR, total: items.filter((x) => !/差し替えない/.test(x.asp)).reduce((s, x) => s + x.n, 0), items });
  }
  return out.sort((a, b) => b.total - a.total || a.slug.localeCompare(b.slug));
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const inv = buildInventory();
  const withAny = inv.filter((x) => x.total > 0);
  console.log(`記事 ${inv.length} 本・成果リンクあり ${withAny.length} 本`);
  const unknown = inv.flatMap((x) => x.items.filter((i) => /照合できない/.test(i.item)).map((i) => `${x.slug} ${i.item} ×${i.n}`));
  console.log(`照合できない A8: ${unknown.length} 件`); unknown.slice(0, 20).forEach((x) => console.log('  ' + x));
  if (process.argv.includes('--json')) console.log(JSON.stringify(inv.slice(0, 3), null, 1));
}
