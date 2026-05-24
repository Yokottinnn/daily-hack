// 記事 frontmatter（category/tags/keywords）と BannerEntry のマッチングロジック
// 採用: 候補スコア = カテゴリ完全一致(+10) + キーワード重複数(+1ずつ) + ジャンル弱マッチ(+2)
import { BANNER_CATALOG, type BannerEntry } from '../data/banner-catalog';

export interface ArticleContext {
  slug: string;          // 記事 ID
  category: string[];    // frontmatter category（複数可）
  tags: string[];        // frontmatter tags
  title?: string;        // タイトル文字列（補助）
  description?: string;  // description（補助）
}

// 記事カテゴリ → バナーカテゴリ群 のマッピング
const ARTICLE_TO_BANNER_CATEGORIES: Record<string, string[]> = {
  // 記事 frontmatter category → 親和性ある banner category 群
  campaigns: ['utility-electric', 'utility-gas', 'internet-fiber', 'internet-mobile', 'mobile-sim', 'travel-hotel', 'travel-air'],
  services:  ['utility-electric', 'utility-gas', 'internet-fiber', 'internet-mobile', 'mobile-sim', 'pointkatsu'],
  comparisons: ['utility-electric', 'utility-gas', 'internet-fiber', 'internet-mobile', 'mobile-sim'],
  roundups:  ['travel-hotel', 'travel-air', 'travel-package', 'utility-electric', 'utility-gas'],
  howto:     ['utility-electric', 'utility-gas', 'internet-fiber', 'pointkatsu'],
  'wangan-life': [],  // 湾岸ライフはアフィ親和性なしと判定
};

// 記事 tag → banner キーワードに変換するマッピング（曖昧マッチ補強）
const TAG_TO_BANNER_KEYWORDS: Record<string, string[]> = {
  '光回線':       ['光回線', 'インターネット'],
  'インターネット': ['光回線', 'インターネット', 'WiFi'],
  '格安SIM':     ['SIM', '格安SIM', 'スマホ'],
  'スマホ':       ['SIM', 'スマホ'],
  'WiFi':         ['WiFi', 'ポケットWiFi'],
  '電気代':       ['電気', '電気代', '新電力'],
  'ガス代':       ['ガス', 'ガス代', 'プロパン'],
  '固定費':       ['固定費'],
  '節約':         ['節約', '固定費'],
  '夏旅':         ['夏旅', '国内旅行', 'ホテル'],
  '旅行':         ['旅行', '国内旅行', 'ホテル'],
  'ホテル':       ['ホテル', '宿', '旅館'],
  '宿':           ['ホテル', '宿', '旅館'],
  'ポイ活':       ['ポイ活', 'ポイントサイト'],
  'ポイントサイト': ['ポイ活', 'ポイントサイト'],
  '楽天':         ['楽天'],
  'PayPay':       ['PayPay'],
  'JR':           ['JR', '新幹線'],
  '新幹線':       ['新幹線', 'JR'],
  '海外':         ['海外', 'eSIM'],
};

export interface MatchResult {
  banner: BannerEntry;
  score: number;
  reason: string;
}

/**
 * Pure scoring function: 記事コンテキストと 1 バナーの相関スコアを計算
 */
export function scoreBanner(article: ArticleContext, banner: BannerEntry): MatchResult {
  let score = 0;
  const reasons: string[] = [];

  // カテゴリ親和性スコア
  for (const ac of article.category) {
    const matchingBannerCats = ARTICLE_TO_BANNER_CATEGORIES[ac] ?? [];
    if (matchingBannerCats.includes(banner.category)) {
      score += 10;
      reasons.push(`cat:${ac}→${banner.category}`);
      break;
    }
  }

  // タグ → banner キーワードへの曖昧マッチ
  const expandedKeywords = new Set<string>();
  for (const tag of article.tags) {
    const expanded = TAG_TO_BANNER_KEYWORDS[tag] ?? [tag];
    expanded.forEach((kw) => expandedKeywords.add(kw));
    // 元のタグも候補に入れる
    expandedKeywords.add(tag);
  }

  let kwHits = 0;
  for (const bk of banner.keywords) {
    if (expandedKeywords.has(bk)) {
      kwHits += 1;
    }
  }
  if (kwHits > 0) {
    score += kwHits * 3;
    reasons.push(`kws+${kwHits}`);
  }

  // タイトル・description にバナー名から推測されるキーワードが含まれていれば微加点
  const text = `${article.title ?? ''} ${article.description ?? ''}`;
  for (const bk of banner.keywords) {
    if (bk.length >= 3 && text.includes(bk)) {
      score += 1;
      reasons.push(`text:${bk}`);
      break;
    }
  }

  return { banner, score, reason: reasons.join(',') || 'no-match' };
}

/**
 * Get top-N banners matching this article context, sorted by score desc.
 * threshold: minimum score required (default 10 = category match required)
 */
export function matchBanners(article: ArticleContext, opts: { topN?: number; threshold?: number } = {}): MatchResult[] {
  const { topN = 5, threshold = 10 } = opts;
  return BANNER_CATALOG
    .map((b) => scoreBanner(article, b))
    .filter((r) => r.score >= threshold)
    .sort((a, b) => b.score - a.score)
    .slice(0, topN);
}

/**
 * Render banner as ready-to-insert HTML for markdown body.
 */
export function renderBannerHtml(banner: BannerEntry): string {
  return `<div class="a8-banner"><a href="${banner.a8url}" target="_blank" rel="sponsored noopener nofollow"><img src="${banner.image}" alt="${banner.name}" width="${banner.imageWidth}" height="${banner.imageHeight}" loading="lazy"></a></div>`;
}
