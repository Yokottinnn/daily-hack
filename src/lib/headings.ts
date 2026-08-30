import type { MarkdownHeading } from 'astro';

/**
 * 記事の見出しを、Markdown と生 HTML の両方から**文書順に**集める。
 *
 * Astro が渡してくる `headings` は **Markdown の見出しだけ**で、
 * `.section-with-mascot` の中に `<h2>` を生 HTML で書いた節が丸ごと落ちる。
 * rehype 側では直せない（見出しの収集はユーザーのプラグインより前に終わっている）ので、
 * 記事のソースそのものを見て組み立て直す。
 *
 * - Markdown の `## 〜` は Astro が振った slug をそのまま使う（照合はテキスト）
 * - 生 HTML の `<h2 id="〜">` は書いてある id を使う。id が無いものは目次に出せないので落とす
 */
const MD_HEADING = /^(#{2,3})\s+(.+?)\s*$/;
const HTML_HEADING = /<h([23])\b([^>]*)>([\s\S]*?)<\/h\1\s*>/gi;
const ID_ATTR = /\bid\s*=\s*["']([^"']+)["']/i;

const stripTags = (s: string) =>
  s
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();

/** Markdown の見出しテキストから装飾記号を落として、Astro の heading.text と突き合わせる */
const normalize = (s: string) =>
  stripTags(s)
    .replace(/\*\*/g, '')
    .replace(/`/g, '')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .trim();

export function collectHeadings(
  body: string | undefined,
  astroHeadings: MarkdownHeading[],
): MarkdownHeading[] {
  if (!body) return astroHeadings;

  // コードブロックの中身は見出しではない
  const src = body.replace(/^```[\s\S]*?^```/gm, '');

  const bySlug = new Map(astroHeadings.map((h) => [h.slug, h]));
  const remaining = [...astroHeadings];
  const out: MarkdownHeading[] = [];

  const lines = src.split('\n');
  let cursor = 0;

  for (const line of lines) {
    const md = MD_HEADING.exec(line);
    if (md) {
      const text = normalize(md[2]);
      const idx = remaining.findIndex((h) => normalize(h.text) === text);
      if (idx >= 0) {
        out.push(remaining[idx]);
        remaining.splice(idx, 1);
      }
      cursor += line.length + 1;
      continue;
    }
    cursor += line.length + 1;
  }

  // 生 HTML の見出しを、行番号ではなく文書中の位置で差し込み直す
  const positioned: Array<{ at: number; h: MarkdownHeading }> = [];
  let at = 0;
  for (const line of lines) {
    const md = MD_HEADING.exec(line);
    if (md) {
      const text = normalize(md[2]);
      const h = astroHeadings.find((x) => normalize(x.text) === text);
      if (h) positioned.push({ at, h });
    }
    at += line.length + 1;
  }

  HTML_HEADING.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = HTML_HEADING.exec(src)) !== null) {
    const text = stripTags(m[3]);
    const id = ID_ATTR.exec(m[2])?.[1];
    if (!text || !id) continue;
    if (bySlug.has(id)) continue;
    positioned.push({ at: m.index, h: { depth: Number(m[1]), slug: id, text } });
  }

  positioned.sort((a, b) => a.at - b.at);
  const seen = new Set<string>();
  const merged = positioned
    .map((p) => p.h)
    .filter((h) => (seen.has(h.slug) ? false : (seen.add(h.slug), true)));

  return merged.length >= out.length ? merged : astroHeadings;
}
