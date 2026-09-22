/**
 * 記事本文から AIO（AI 検索・生成AIに引用されるための）構造化データを作る。
 *
 * **本文に書いてあるものだけを拾う。** 要約も言い換えもしない。
 * 生成AIは「答えの形になっているもの」を引用するので、
 * すでに記事にある FAQ と手順を、機械が読める形で二重に出す。
 *
 * - `faq-table` の行            → `FAQPage`
 * - `① ② ③` が並ぶ手順の表     → `HowTo`
 * - 本文の h2 見出し            → `Article.articleSection`
 *
 * **取れなければ出さない。** 空の FAQPage を出すと、かえって評価を落とす。
 *
 * **`post.body` は `string | undefined`。** 型を絞らずに渡して CI の
 * `astro check` が落ちた（2026-09-20）。`npm run build` だけでは通ってしまう。
 */

const TAG = /<[^>]+>/g;

/** HTML タグを落として、実体参照を戻す */
function plain(s: string): string {
  return s
    .replace(TAG, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/\s+/g, ' ')
    .trim();
}

type Row = { th: string; td: string };

/** `<table class="… X …">` の本体から `<tr><th>..</th><td>..</td></tr>` を取り出す */
function rowsOfTables(body: string, needClass: string): Row[][] {
  const out: Row[][] = [];
  const re = /<table[^>]*class="([^"]*)"[^>]*>([\s\S]*?)<\/table>/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(body))) {
    if (!m[1].split(/\s+/).includes(needClass)) continue;
    const rows: Row[] = [];
    // **`<th>` の表と `<td>` 2 列の表、どちらも拾う。**
    // FAQ は記事によって `<th>質問</th><td>答え</td>` とも
    // `<td><strong>質問</strong></td><td>答え</td>` とも書かれている。
    // **`<th>` だけを見ていたせいで、表になっている FAQ を取りこぼしていた**
    // （2026-09-22。16 記事が FAQPage を出せていなかった）。
    const rre = /<tr[^>]*>\s*<t([hd])[^>]*>([\s\S]*?)<\/t\1>\s*<td[^>]*>([\s\S]*?)<\/td>/g;
    let r: RegExpExecArray | null;
    while ((r = rre.exec(m[2]))) {
      const th = plain(r[2]);
      const td = plain(r[3]);
      if (th && td) rows.push({ th, td });
    }
    if (rows.length) out.push(rows);
  }
  return out;
}

export function faqJsonLd(body: string | undefined) {
  if (!body) return null;
  const tables = rowsOfTables(body, 'faq-table');
  const rows = tables.flat();
  // **3 件 未満なら出さない。** 1〜2 件の FAQPage は意味がない
  if (rows.length < 3) return null;
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: rows.map((r) => ({
      '@type': 'Question',
      name: r.th,
      acceptedAnswer: { '@type': 'Answer', text: r.td },
    })),
  };
}

export function howToJsonLd(body: string | undefined, name: string) {
  if (!body) return null;
  // 手順の表は 1 列目が ① ② ③ … になっている（bullets-to-spec-table / 手で書いたもの）
  const re = /<table[^>]*class="[^"]*cmp-table[^"]*"[^>]*>([\s\S]*?)<\/table>/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(body))) {
    const steps: { name: string; text: string }[] = [];
    const rre = /<tr[^>]*>([\s\S]*?)<\/tr>/g;
    let r: RegExpExecArray | null;
    while ((r = rre.exec(m[1]))) {
      const cells = [...r[1].matchAll(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/g)].map((c) => plain(c[1]));
      if (cells.length < 2) continue;
      if (!/^[①②③④⑤⑥⑦⑧⑨⑩]$/.test(cells[0])) continue;
      steps.push({ name: cells[1], text: cells.slice(1).filter(Boolean).join(' ') });
    }
    if (steps.length >= 3) {
      return {
        '@context': 'https://schema.org',
        '@type': 'HowTo',
        name,
        step: steps.map((s, i) => ({
          '@type': 'HowToStep',
          position: i + 1,
          name: s.name,
          text: s.text,
        })),
      };
    }
  }
  return null;
}

/** 本文の h2（Markdown と生 HTML の両方）を節名として並べる */
export function sections(body: string | undefined): string[] {
  if (!body) return [];
  const out: string[] = [];
  for (const m of body.matchAll(/^##\s+(.+)$/gm)) out.push(plain(m[1]));
  for (const m of body.matchAll(/<h2[^>]*>([\s\S]*?)<\/h2>/g)) out.push(plain(m[1]));
  return out.filter(Boolean).slice(0, 40);
}
