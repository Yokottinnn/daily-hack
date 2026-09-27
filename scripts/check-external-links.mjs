// **記事の外部リンクが生きているかを一括で見る。**
//
// 2026-09-26 に 1 日で 3 本 見つかった。**どれも気づく仕組みが無かった。**
//
//   `https://www.bang.co.jp/auto/`            → title が "404 Not Found"
//   `https://www.softbank.jp/internet/hikari/` → **別商品（Yahoo! BB 光）に転送**
//   `https://www.jal.co.jp/.../jalpay/`        → 404
//
// **ビルドもリンク切れ検査も素通りする。** 外部リンクは誰も見ていない。
//
//   node scripts/check-external-links.mjs            # 全部
//   node scripts/check-external-links.mjs --budget=240 --out=/tmp/links.json
//   node scripts/check-external-links.mjs --resume=/tmp/links.json   # 続きから
//
// **クラウドからは走らせられない**（egress が塞がれている）。`ops/tasks` で Mac に回す。
//
// ## 判定の作法
//
// - **`403` を「死んでいる」と書かない。** bot を弾いているだけのことが多い
// - **転送先が別物になっていないかを見る。** ソフトバンク光がこれだった。
//   最終 URL とパスの食い違いを出して、**判断は人がする**
// - HEAD を拒むサーバがあるので、**HEAD が 405/501 なら GET の 1 バイトで試す**
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const opt = (k, d) => {
  const a = args.find((x) => x.startsWith(`--${k}=`));
  return a ? a.split('=').slice(1).join('=') : d;
};
const BUDGET = Number(opt('budget', 240)) * 1000;
const OUT = opt('out', '/tmp/external-links.json');
const RESUME = opt('resume', null);
const CONC = Number(opt('conc', 8));
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
         + '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

// **見ても仕方ないものは最初から外す。** bot を弾くのが前提のホスト
const SKIP = /^(twitter\.com|x\.com|www\.youtube-nocookie\.com|www\.youtube\.com|platform\.twitter\.com|px\.a8\.net|cdn\.syndication\.twimg\.com)$/;

function collect() {
  const map = new Map();          // url -> Set(slug)
  const dir = 'src/content/posts';
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.md'))) {
    const s = fs.readFileSync(path.join(dir, f), 'utf8');
    for (let u of new Set(s.match(/https?:\/\/[^\s"'<>)\]]+/g) || [])) {
      u = u.replace(/[.,;:]+$/, '');
      if (u.includes('daily-hack')) continue;
      let host; try { host = new URL(u).host; } catch { continue; }
      if (SKIP.test(host)) continue;
      if (!map.has(u)) map.set(u, new Set());
      map.get(u).add(f.replace(/\.md$/, ''));
    }
  }
  return [...map].map(([url, slugs]) => ({ url, slugs: [...slugs].sort() }))
                 .sort((a, b) => a.url.localeCompare(b.url));
}

async function probe(url) {
  const common = { redirect: 'follow', headers: { 'user-agent': UA, accept: '*/*' } };
  const run = async (method, extra) => {
    const c = new AbortController();
    const t = setTimeout(() => c.abort(), 12000);
    try {
      const r = await fetch(url, { ...common, ...extra, method, signal: c.signal });
      return { status: r.status, final: r.url };
    } finally { clearTimeout(t); }
  };
  try {
    let r = await run('HEAD');
    // **HEAD を実装していないサーバが在る。** GET の 1 バイトで試し直す
    if ([405, 501, 403, 400].includes(r.status)) {
      try { r = await run('GET', { headers: { ...common.headers, range: 'bytes=0-0' } }); }
      catch { /* HEAD の結果を使う */ }
    }
    return r;
  } catch (e) {
    return { status: 0, final: null, err: String(e.message || e).slice(0, 80) };
  }
}

const all = collect();
const done = RESUME && fs.existsSync(RESUME)
  ? new Map(JSON.parse(fs.readFileSync(RESUME, 'utf8')).results.map((r) => [r.url, r]))
  : new Map();
const todo = all.filter((x) => !done.has(x.url));
console.log(`対象 ${all.length} 件 / 済 ${done.size} 件 / これから ${todo.length} 件`);

const started = Date.now();
let i = 0, stopped = false;
async function worker() {
  while (true) {
    if (Date.now() - started > BUDGET) { stopped = true; return; }
    const j = i++;
    if (j >= todo.length) return;
    const item = todo[j];
    const r = await probe(item.url);
    done.set(item.url, { ...item, ...r });
  }
}
await Promise.all(Array.from({ length: CONC }, worker));

const results = all.map((x) => done.get(x.url)).filter(Boolean);
fs.writeFileSync(OUT, JSON.stringify({ total: all.length, results }, null, 1));

// **`403` を死んだ扱いにしない。** 分けて出す
const bucket = (r) => {
  if (r.status === 0) return 'つながらない';
  if (r.status === 404 || r.status === 410) return '**切れている**';
  if (r.status === 403 || r.status === 401) return '弾かれた（生死は不明）';
  if (r.status >= 500) return 'サーバ側のエラー';
  if (r.status >= 400) return 'その他の 4xx';
  return 'OK';
};
const by = {};
for (const r of results) (by[bucket(r)] ||= []).push(r);
console.log('');
for (const k of Object.keys(by).sort()) console.log(`${k}: ${by[k].length}`);
console.log('');
for (const k of ['**切れている**', 'その他の 4xx', 'つながらない']) {
  for (const r of (by[k] || []).slice(0, 40)) {
    console.log(`${k} ${r.status}  ${r.url}`);
    console.log(`    ← ${r.slugs.join(' / ')}`);
  }
}
// **転送先が別物になっていないか。** ソフトバンク光がこれだった
console.log('\n## 転送でパスが変わったもの（**別商品に飛んでいないか見る**）');
let n = 0;
for (const r of results) {
  if (!r.final || r.final === r.url) continue;
  try {
    const a = new URL(r.url), b = new URL(r.final);
    if (a.host === b.host && a.pathname.replace(/\/$/, '') === b.pathname.replace(/\/$/, '')) continue;
    if (n++ >= 30) break;
    console.log(`  ${r.url}\n    -> ${r.final}\n    ← ${r.slugs.join(' / ')}`);
  } catch { /* 無視 */ }
}
console.log(stopped ? `\n⏱️ 時間切れ。**${results.length}/${all.length} 件まで。** --resume で続きから`
                    : `\n✅ 全部 見た（${results.length} 件）`);
