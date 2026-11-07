// 「編集部おすすめ」＝直近 28 日によく読まれた記事（2026-11-07 利用者の指示）。
// 数は src/data/popular-posts.json（scripts/gen-popular-posts.mjs が毎朝書き直す）。
import type { CollectionEntry } from 'astro:content';
import data from '../data/popular-posts.json';

const PV: Record<string, number> = (data as { pv: Record<string, number> }).pv ?? {};

export const popularWindow = (data as { window?: { last?: string | null } }).window ?? {};

export function pvOf(slug: string): number {
  return PV[slug] ?? 0;
}

/** 読まれた数の多い順に上位 n 本。1 人も読んでいない記事は出さない */
export function topByPv(posts: CollectionEntry<'posts'>[], n: number): CollectionEntry<'posts'>[] {
  return posts
    .filter((p) => pvOf(p.id) > 0)
    .sort((a, b) => pvOf(b.id) - pvOf(a.id) || b.data.publishDate.getTime() - a.data.publishDate.getTime())
    .slice(0, n);
}
