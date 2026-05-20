import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import { getCategories } from '../lib/category';

export async function GET(context) {
  const posts = await getCollection('posts', ({ data }) => !data.draft);
  const sorted = posts.sort(
    (a, b) => b.data.publishDate.getTime() - a.data.publishDate.getTime(),
  );
  return rss({
    title: 'Daily Hack',
    description: 'お得を毎日、ハック。ポイ活・節約・固定費削減のリアル最新情報を、毎日アップデート。',
    site: context.site,
    items: sorted.map((post) => ({
      title: post.data.title,
      pubDate: post.data.publishDate,
      description: post.data.description,
      link: `/posts/${post.id}/`,
      categories: [...getCategories(post.data), ...(post.data.tags ?? [])],
    })),
    customData: '<language>ja</language>',
  });
}
