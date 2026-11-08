// イベントマップのピンと小窓に使う小さな画像を作る（2026-11-07 利用者「スマホだととんでもなくローディングが遅い。根本的に設計が間違っている」）。
// それまではピン（直径 36px）に記事の表紙の元画像（1600×900・1 枚 40〜60 万バイト）をそのまま読み込んでいて、32 枚で 10.5 MB あった。
// ビルドの前に毎回回す（package.json の build）。湾岸ライフの記事の表紙だけを対象にし、作り済みで元画像より新しければ作り直さない。
// 出力: public/images/_wm/<slug>-pin.webp（96×96）と <slug>-pop.webp（640×360）。生成物なので git には入れない（.gitignore）
// 2026-11-07: 記事一覧のカード（PostCard）も同じ <slug>-pop.webp を使う。カードは全記事が対象なので、湾岸ライフに限らず全記事の表紙から作る
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const POSTS = path.join(ROOT, 'src/content/posts');
const OUT = path.join(ROOT, 'public/images/_wm');
fs.mkdirSync(OUT, { recursive: true });
let made = 0, kept = 0, missing = 0;
for (const f of fs.readdirSync(POSTS).filter((x) => /\.mdx?$/.test(x))) {
  const s = fs.readFileSync(path.join(POSTS, f), 'utf8');
  const fm = s.split(/\n---\s*\n/)[0];
  const isWangan = /wangan-life/.test(fm);
  const m = fm.match(/\neyecatchUrl:\s*"?([^"\n]+)"?/);
  if (!m || !m[1].startsWith('/')) continue;
  const src = path.join(ROOT, 'public', m[1]);
  if (!fs.existsSync(src)) { missing++; continue; }
  const slug = f.replace(/\.mdx?$/, '');
  const st = fs.statSync(src).mtimeMs;
  for (const [suf, w, h, q] of (isWangan ? [['pin', 96, 96, 70], ['pop', 640, 360, 72]] : [['pop', 640, 360, 72]])) {
    const out = path.join(OUT, `${slug}-${suf}.webp`);
    if (fs.existsSync(out) && fs.statSync(out).mtimeMs >= st) { kept++; continue; }
    await sharp(src).resize(w, h, { fit: 'cover', position: 'attention' }).webp({ quality: q }).toFile(out);
    made++;
  }
}
console.log(`[thumbs] 小さな画像: 作成 ${made} / そのまま ${kept} / 元画像なし ${missing}`);
