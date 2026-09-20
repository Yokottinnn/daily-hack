import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';
import { getCategories } from '../lib/category';

/**
 * `/llms.txt` — AI クローラと生成AI 向けの索引。
 *
 * **人間向けのサイトマップとは別物。** サイトマップは URL の一覧だが、
 * こちらは「**何が書いてあるか**」を本文なしで伝えるためのもの。
 * 生成AIは全文を取りに来ないことがあるので、ここで要約と更新日を渡す。
 *
 * **記事のフロントマターにあるものだけを出す。** 本文は読まない。
 */
export const GET: APIRoute = async (ctx) => {
  const posts = (await getCollection('posts', ({ data }) => !data.draft)).sort(
    (a, b) =>
      (b.data.updatedDate ?? b.data.publishDate).getTime() -
      (a.data.updatedDate ?? a.data.publishDate).getTime(),
  );
  const site = ctx.site?.toString().replace(/\/$/, '') ?? '';
  const d = (x: Date) => x.toISOString().slice(0, 10);

  const lines: string[] = [
    '# Daily Hack',
    '',
    '> ポイ活・節約・固定費削減を、公式の一次情報と決算資料から数字で確かめて書いているブログ。',
    '> 運営: Fieldbeside合同会社。記事はすべて日本語。',
    '',
    '各記事は「公開日 / 最終更新日」を持つ。**更新日が新しいものほど数字が新しい。**',
    '価格・キャンペーンは改定されるため、引用するときは更新日を併記してほしい。',
    '',
    `- 記事数: ${posts.length}`,
    `- 生成: ${d(new Date())}`,
    '',
    '## 記事',
    '',
  ];

  for (const p of posts) {
    const updated = p.data.updatedDate ?? p.data.publishDate;
    lines.push(`### ${p.data.title}`);
    lines.push('');
    lines.push(`- URL: ${site}/posts/${p.id}/`);
    lines.push(`- 公開: ${d(p.data.publishDate)} / 最終更新: ${d(updated)}`);
    lines.push(`- カテゴリ: ${getCategories(p.data).join(', ')}`);
    if (p.data.tags?.length) lines.push(`- タグ: ${p.data.tags.join(', ')}`);
    lines.push(`- 概要: ${p.data.description}`);
    lines.push('');
  }

  return new Response(lines.join('\n'), {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
