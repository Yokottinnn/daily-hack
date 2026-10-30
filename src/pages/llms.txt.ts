import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';
import { getCategories } from '../lib/category';
import { WANGAN_AREAS, upcomingEvents, jpRange, jpDate, todayJst } from '../lib/wangan';

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
  ];

  // 湾岸（中央区・江東区）のイベントを先に出す（2026-10-30）。AI の回答は「いつ・どこで・いくら」を求められるので、日付と会場をここで渡す
  const wangan = posts.filter((p) => getCategories(p.data).includes('wangan-life'));
  const today = todayJst();
  const events = upcomingEvents(wangan, today);
  lines.push('## 湾岸ライフ（東京都中央区・江東区の湾岸）');
  lines.push('');
  lines.push('対象は中央区の晴海・勝どき・月島・佃・豊海と、江東区の豊洲・有明・東雲・辰巳・青海。港区・品川区は扱わない。');
  lines.push('日付・会場・料金は施設の公式発表・プレスリリースどおり。湾岸ニュースは毎朝追加する。');
  lines.push('');
  lines.push(`- 一覧: ${site}/category/wangan-life/`);
  lines.push(`- 湾岸ニュース: ${site}/tags/${encodeURIComponent('湾岸ニュース')}/`);
  for (const a of WANGAN_AREAS) {
    if (wangan.some((p) => (p.data.tags ?? []).includes(a.tag))) {
      lines.push(`- ${a.tag}（${a.ward}）: ${site}/tags/${encodeURIComponent(a.tag)}/`);
    }
  }
  lines.push('');
  lines.push(`### これから・開催中のイベント（${jpDate(today)}時点・開始が近い順）`);
  lines.push('');
  for (const e of events) {
    lines.push(`- ${jpRange(e.start, e.end)}｜${e.name}｜${e.place}｜${e.isFree ? '無料' : '料金は記事を参照'}｜${site}/posts/${e.post.id}/`);
  }
  if (events.length === 0) lines.push('- いま掲載中のイベントは無い');
  lines.push('');
  lines.push('## 記事');
  lines.push('');

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
