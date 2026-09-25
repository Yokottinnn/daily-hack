// **ブランド名が並んでいるのにロゴが無い箇所を、全記事から洗い出す。**
//
// 最上位ルール 17 は「**もれなく全て**」と決めている。だが
// **一度やった記事にしかロゴが入らない**のが実際に起きている
// （2026-09-04 と 2026-09-20 に同じ指摘を 2 回 受けた）。
// **どこが残っているかを、目ではなく数で出す。**
//
//   node scripts/find-missing-logos.mjs               # 全記事
//   node scripts/find-missing-logos.mjs --slug=foo    # 1 記事だけ
//   node scripts/find-missing-logos.mjs --loose       # 絞り込みを緩めて拾いすぎ側で見る
//
// **`scripts/check-logos.mjs` とは役割が違う。** あちらは
// **入れたロゴが壊れていないか**を見る（ビルド後のページを開く）。
// こちらは **入れていない箇所を探す**（Markdown を読む）。
//
// ## 何を「並べている」と見なすか
//
// **ブランド名が本文の中に出てくるだけの行は対象にしない。** 実際に
// 「松屋アプリ事前注文 × d払い」のような説明文まで拾って 530 箇所 出た。
// **セル・見出しの文字数に対してブランド名が占める割合**で絞る。
//
//   ✅ `**PayPay**` / `🐂 松屋（60周年）` / `<h3>楽天でんき</h3>`
//   ❌ `松屋アプリ事前注文 × d払い` / `すき家・なか卯メイン`
import fs from 'node:fs';
import path from 'node:path';

const POSTS = 'src/content/posts';
const IMAGES = 'public/images';
const args = process.argv.slice(2);
const LOOSE = args.includes('--loose');
const ONLY = (args.find((a) => a.startsWith('--slug=')) || '').split('=')[1] || null;
// **ブランド名がその箇所の何割を占めていれば「並べている」と見るか**
const RATIO = LOOSE ? 0.25 : 0.5;

// --- ① 在庫の棚卸し: ブランド名 -> リポジトリ内のロゴ ---
// **`_manifest.json` の `brand` が一次情報。** ファイル名だけでは
// 「`au.png` が au なのか auでんき なのか」が言えない。
const stock = new Map();
const norm = (s) => s.toLowerCase().replace(/[\s　・()（）]/g, '');
const addStock = (brand, slug, file) => {
  if (!brand) return;
  const k = norm(brand);
  if (k.length < 2) return;
  if (!stock.has(k)) stock.set(k, []);
  stock.get(k).push({ slug, file, brand });
};

for (const slug of fs.readdirSync(IMAGES)) {
  const dir = path.join(IMAGES, slug, 'logos');
  const man = path.join(dir, '_manifest.json');
  if (!fs.existsSync(man)) continue;
  let m;
  try { m = JSON.parse(fs.readFileSync(man, 'utf8')); } catch { continue; }
  for (const [k, v] of Object.entries(m)) {
    if (!v || typeof v !== 'object' || k.startsWith('_')) continue;
    const file = v.file || (k.includes('.') ? k : null);
    if (!file || !fs.existsSync(path.join(dir, file))) continue;
    addStock(v.brand, slug, file);
    // **App Store のアプリ名は長い**（「dヘルスケア -歩数でdポイントがたまる…」）。
    // 記号の手前までを別名として足す
    const short = String(v.brand || '').split(/[-–—｜|:：(（【]/)[0].trim();
    if (short && short !== v.brand) addStock(short, slug, file);
  }
}

// --- ② 1 つの「箇所」を見て、ブランドが主役かを判定する ---
const strip = (s) => s
  .replace(/<[^>]*>/g, ' ')                       // HTML タグ（属性ごと落とす）
  .replace(/\]\([^)]*\)/g, '] ')                  // Markdown リンクの URL
  .replace(/https?:\/\/\S+/g, ' ')
  .replace(/[*_`#|]/g, ' ')                       // 強調・表の区切り
  .replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]/gu, ' ')  // 絵文字
  .replace(/\s+/g, ' ').trim();

function hits(text) {
  const t = strip(text);
  const tn = norm(t);
  if (!tn) return [];
  const out = [];
  for (const [k, entries] of stock) {
    if (/^[a-z0-9.]+$/.test(k) && k.length <= 4) {
      // **短い英字は語境界を要求する。** `au` が「SHIBAURA」に当たる
      const re = new RegExp(`(^|[^a-z0-9])${k.replace(/\./g, '\\.')}([^a-z0-9]|$)`, 'i');
      if (!re.test(t)) continue;
    } else if (!tn.includes(k)) continue;
    // **ブランド名がその箇所の主役か。** 説明文の中の言及は対象にしない
    if (k.length / tn.length < RATIO) continue;
    out.push(entries);
  }
  return out;
}

// --- ③ 記事を読む ---
const results = [];
for (const f of fs.readdirSync(POSTS).filter((f) => f.endsWith('.md'))) {
  const slug = f.replace(/\.md$/, '');
  if (ONLY && slug !== ONLY) continue;
  // frontmatter は見ない（tags にブランド名がずらりと並ぶ）
  const body = fs.readFileSync(path.join(POSTS, f), 'utf8').replace(/^---\n[\s\S]*?\n---\n/, '');

  const miss = [];
  const seen = new Set();
  for (const raw of body.split('\n')) {
    const t = raw.trim();
    let kind = null, cells = null;
    if (/^#{2,4}\s/.test(t) || /^<h[234][\s>]/.test(t)) { kind = '見出し'; cells = [t]; }
    else if (t.startsWith('|') && t.endsWith('|')) {
      if (/^\|[\s:|-]+\|$/.test(t)) continue;    // 区切り行
      kind = '表のセル'; cells = t.split('|').slice(1, -1);
    } else if (/^<tr[\s>]/.test(t)) {
      kind = '表のセル'; cells = t.split(/<\/?t[dh][^>]*>/).filter((c) => c.trim());
    }
    if (!cells) continue;

    for (const cell of cells) {
      // **そのセルに既にロゴが在るなら何もしない**
      if (/brand-logo|cell-brand|sd-icon|chip-logo/.test(cell)) continue;
      for (const entries of hits(cell)) {
        const own = entries.find((e) => e.slug === slug);
        const brand = entries[0].brand;
        const key = `${brand}\u0000${t}`;
        if (seen.has(key)) continue;
        seen.add(key);
        miss.push({
          kind, brand, here: !!own,
          stock: own ? `自記事に在る（${own.file}）` : `${entries[0].slug} に在る（${entries[0].file}）`,
          line: t.slice(0, 100),
        });
      }
    }
  }
  if (miss.length) results.push({ slug, miss });
}

// --- ④ 出す ---
results.sort((a, b) => b.miss.length - a.miss.length);
let total = 0, here = 0;
for (const r of results) {
  total += r.miss.length;
  here += r.miss.filter((m) => m.here).length;
  console.log(`\n## ${r.slug}  （${r.miss.length} 箇所）`);
  for (const m of r.miss) {
    console.log(`  [${m.kind}] ${m.brand}  ← ${m.stock}`);
    console.log(`      ${m.line}`);
  }
}
console.log(`\n---`);
console.log(`**${results.length} 記事 / ${total} 箇所。** うち **${here} 箇所は自記事の logos に在庫が在る**（すぐ入れられる）。`);
console.log(`在庫のブランド語彙 ${stock.size} 件 / 判定のしきい値 ${RATIO}（\`--loose\` で緩められる）。`);
console.log(`\n**これは候補であって結論ではない。** 運営会社を子ブランドに当てるなどは機械では弾けない。`);
console.log(`**入れる前に、その行が本当にブランドを並べている箇所かを見ること**（最上位ルール 17）。`);
