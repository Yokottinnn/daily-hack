// 記事 frontmatter（category/tags/keywords）と バナーのマッチングロジック
// Phase 2 (multi-size): プログラムをスコアリング → position に応じて適切な size variant を選定
import {
  BANNER_CATALOG,
  BANNER_ENTRIES,
  type BannerEntry,
  type BannerProgram,
  type BannerVariant,
  type BannerSizeBucket,
} from '../data/banner-catalog';

export interface ArticleContext {
  slug: string;          // 記事 ID
  category: string[];    // frontmatter category（複数可）
  tags: string[];        // frontmatter tags
  title?: string;        // タイトル文字列（補助）
  description?: string;  // description（補助）
}

// 記事カテゴリ → バナーカテゴリ群 のマッピング
const ARTICLE_TO_BANNER_CATEGORIES: Record<string, string[]> = {
  campaigns: ['utility-electric', 'utility-gas', 'internet-fiber', 'internet-mobile', 'mobile-sim', 'travel-hotel', 'travel-air'],
  services:  ['utility-electric', 'utility-gas', 'internet-fiber', 'internet-mobile', 'mobile-sim', 'pointkatsu'],
  comparisons: ['utility-electric', 'utility-gas', 'internet-fiber', 'internet-mobile', 'mobile-sim'],
  roundups:  ['travel-hotel', 'travel-air', 'travel-package', 'utility-electric', 'utility-gas'],
  howto:     ['utility-electric', 'utility-gas', 'internet-fiber', 'pointkatsu'],
  'wangan-life': [],
};

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

export interface ProgramMatchResult {
  program: BannerProgram;
  score: number;
  reason: string;
}

/** Pure scoring on legacy BannerEntry (for back-compat). */
export function scoreBanner(article: ArticleContext, banner: BannerEntry): MatchResult {
  let score = 0;
  const reasons: string[] = [];

  for (const ac of article.category) {
    const matchingBannerCats = ARTICLE_TO_BANNER_CATEGORIES[ac] ?? [];
    if (matchingBannerCats.includes(banner.category)) {
      score += 10;
      reasons.push(`cat:${ac}→${banner.category}`);
      break;
    }
  }

  const expandedKeywords = new Set<string>();
  for (const tag of article.tags) {
    const expanded = TAG_TO_BANNER_KEYWORDS[tag] ?? [tag];
    expanded.forEach((kw) => expandedKeywords.add(kw));
    expandedKeywords.add(tag);
  }

  let kwHits = 0;
  for (const bk of banner.keywords) {
    if (expandedKeywords.has(bk)) kwHits += 1;
  }
  if (kwHits > 0) {
    score += kwHits * 3;
    reasons.push(`kws+${kwHits}`);
  }

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

/** Same scoring logic but operates on BannerProgram (multi-variant). */
export function scoreProgram(article: ArticleContext, prog: BannerProgram): ProgramMatchResult {
  const fakeBanner: BannerEntry = {
    id: prog.id,
    programId: prog.programId,
    name: prog.name,
    category: prog.category,
    keywords: prog.keywords,
    image: '', imageWidth: 0, imageHeight: 0, a8url: '',
  };
  const r = scoreBanner(article, fakeBanner);
  return { program: prog, score: r.score, reason: r.reason };
}

/** Legacy: top-N BannerEntry. */
export function matchBanners(article: ArticleContext, opts: { topN?: number; threshold?: number } = {}): MatchResult[] {
  // Default threshold 13 = category match (10) + 1 keyword hit (3).
  // Prevents weak category-only matches (e.g., gas banner on QR payment article).
  const { topN = 5, threshold = 13 } = opts;
  return BANNER_ENTRIES
    .map((b) => scoreBanner(article, b))
    .filter((r) => r.score >= threshold)
    .sort((a, b) => b.score - a.score)
    .slice(0, topN);
}

/** New: top-N programs (multi-variant aware). */
export function matchPrograms(article: ArticleContext, opts: { topN?: number; threshold?: number } = {}): ProgramMatchResult[] {
  // For section-break / sidebar insertion, require a stronger signal (cat + 2 kw hits)
  const { topN = 5, threshold = 16 } = opts;
  return BANNER_CATALOG
    .map((p) => scoreProgram(article, p))
    .filter((r) => r.score >= threshold)
    .sort((a, b) => b.score - a.score)
    .slice(0, topN);
}

// ---------- Variant selection ----------

export type BannerPosition =
  | 'inline-grid'      // 記事末尾 / 関連サービス枠（rectangle 優先）
  | 'section-break'    // 中段 H2 直前など（horizontal-banner 優先）
  | 'sidebar'          // サイドバー（skyscraper 優先）
  | 'inline-text'      // 本文内テキストリンク（text-link 優先）
  | 'mobile';          // モバイル特化（mobile-banner 優先）

/** 優先順序を返す（先頭が最優先）。 */
function preferenceOrder(position: BannerPosition): BannerSizeBucket[] {
  switch (position) {
    case 'inline-grid':   return ['rectangle', 'horizontal-banner', 'mini', 'mobile-banner', 'text-link'];
    case 'section-break': return ['horizontal-banner', 'rectangle', 'mobile-banner', 'mini', 'text-link'];
    case 'sidebar':       return ['skyscraper', 'rectangle', 'mini', 'text-link'];
    case 'inline-text':   return ['text-link', 'mini'];
    case 'mobile':        return ['mobile-banner', 'rectangle', 'mini', 'text-link'];
    default:              return ['rectangle', 'horizontal-banner', 'mini', 'text-link'];
  }
}

/**
 * Pick the best variant in `program.variants` for the given position.
 * Returns undefined if no suitable variant exists.
 */
export function pickVariant(program: BannerProgram, position: BannerPosition = 'inline-grid'): BannerVariant | undefined {
  const order = preferenceOrder(position);
  for (const size of order) {
    const v = program.variants.find((v) => v.size === size && (v.image || v.html));
    if (v) return v;
  }
  return program.variants[0];
}

// ---------- HTML rendering ----------

/**
 * Render a variant as ready-to-insert HTML for the markdown body.
 * For images: <div class="a8-banner a8-banner--{size}"><a><img></a></div>
 * For text-link: <span class="a8-textlink"><a>text</a></span>
 */
export function renderVariantHtml(program: BannerProgram, variant: BannerVariant): string {
  if (variant.size === 'text-link') {
    const text = variant.anchorText ?? program.name;
    return `<span class="a8-textlink"><a href="${variant.a8url}" target="_blank" rel="sponsored noopener nofollow">${escapeHtml(text)}</a></span>`;
  }
  const w = variant.width ?? 0;
  const h = variant.height ?? 0;
  const sizeClass = `a8-banner--${variant.size}`;
  return `<div class="a8-banner ${sizeClass}"><a href="${variant.a8url}" target="_blank" rel="sponsored noopener nofollow"><img src="${variant.image ?? ''}" alt="${escapeHtml(program.name)}" width="${w}" height="${h}" loading="lazy"></a></div>`;
}

/** Back-compat: render a legacy BannerEntry. */
export function renderBannerHtml(banner: BannerEntry): string {
  return `<div class="a8-banner a8-banner--rectangle"><a href="${banner.a8url}" target="_blank" rel="sponsored noopener nofollow"><img src="${banner.image}" alt="${escapeHtml(banner.name)}" width="${banner.imageWidth}" height="${banner.imageHeight}" loading="lazy"></a></div>`;
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
