// 記事の category フィールドは単一 string か string[] のどちらかの形式を取りうる。
// 表示・フィルタ・SEO 等で常に「該当カテゴリの配列」として扱いたいので
// この helper 経由で取得する。

import type { CollectionEntry } from 'astro:content';

export type CategorySlug =
  | 'campaigns'
  | 'services'
  | 'comparisons'
  | 'roundups'
  | 'howto'
  | 'wangan-life';

export const CATEGORY_LABELS: Record<CategorySlug, string> = {
  campaigns: 'キャンペーン速報',
  services: 'サービス紹介',
  comparisons: '比較',
  roundups: 'まとめ',
  howto: 'ハウツー',
  'wangan-life': '湾岸ライフ',
};

type PostData = CollectionEntry<'posts'>['data'];

/** 記事のカテゴリ slug 配列を返す。単一 string でも array でも常に配列で返す。 */
export function getCategories(data: PostData): CategorySlug[] {
  const c = (data as { category: CategorySlug | CategorySlug[] }).category;
  return Array.isArray(c) ? c : [c];
}

/** プライマリカテゴリ（記事ヘッダー等 1つ表示する場面で使う） */
export function getPrimaryCategory(data: PostData): CategorySlug {
  return getCategories(data)[0];
}

/** ある category slug にこの記事が属するか判定 */
export function postBelongsToCategory(
  data: PostData,
  category: CategorySlug,
): boolean {
  return getCategories(data).includes(category);
}
