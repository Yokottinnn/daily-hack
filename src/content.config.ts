import { defineCollection } from 'astro:content';
import { z } from 'astro:schema';
import { glob } from 'astro/loaders';

const posts = defineCollection({
  loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/posts' }),
  schema: ({ image }) =>
    z.object({
      title: z.string().min(1).max(100),
      description: z.string().min(50).max(160),
      publishDate: z.coerce.date(),
      updatedDate: z.coerce.date().optional(),
      // 1記事 = 単一 enum or array of enum を両方許容
      // 表示・フィルタ側は src/lib/category.ts の getCategories(data) 経由で統一的に string[] として扱う
      category: z.union([
        z.enum([
          'campaigns',
          'services',
          'comparisons',
          'roundups',
          'howto',
          'wangan-life',
        ]),
        z
          .array(
            z.enum([
              'campaigns',
              'services',
              'comparisons',
              'roundups',
              'howto',
              'wangan-life',
            ]),
          )
          .min(1),
      ]),
      tags: z.array(z.string()).optional(),
      eyecatch: image().optional(),
      eyecatchUrl: z.string().optional(),
      eyecatchAlt: z.string().optional(),
      relatedReferrals: z.array(z.string()).optional(),
      parentPillar: z.string().optional(),
      isPR: z.boolean().default(false),
      draft: z.boolean().default(false),
      featured: z.boolean().default(false),
      author: z.string().default('hacker-ko'),
    }),
});

const weeklyQuotes = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/weekly-quotes' }),
  schema: z.object({
    quote: z.string().min(1).max(200),
    publishDate: z.coerce.date(),
    expression: z
      .enum([
        'wave',
        'pout',
        'bashful',
        'cheer',
        'smug',
        'shock',
        'gasp',
        'cry',
        'arms-crossed',
      ])
      .optional(),
  }),
});

export const collections = {
  posts,
  'weekly-quotes': weeklyQuotes,
};
