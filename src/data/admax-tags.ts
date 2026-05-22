// 忍者AdMAX 広告タグ ID マッピング
// 各 slot ID に対応する admax の「広告コード」を貼る。
// admax 管理画面 → タグを作成 → 表示される <script>...</script> コードを丸ごとここに貼る。
// プレースホルダのまま（'PLACEHOLDER' 開始）の場合、AdMax コンポーネントは何もレンダリングしない。

export const ADMAX_TAGS: Record<string, string> = {
  'dailyhack-article-top': 'PLACEHOLDER_TAG_HERE',
  'dailyhack-article-bottom': 'PLACEHOLDER_TAG_HERE',
  'dailyhack-sidebar-sticky': 'PLACEHOLDER_TAG_HERE',
  'dailyhack-home-below-hero': 'PLACEHOLDER_TAG_HERE',
  'dailyhack-sticky-mobile': 'PLACEHOLDER_TAG_HERE',
};

export type AdMaxSlot = keyof typeof ADMAX_TAGS;

export function isAdMaxConfigured(slot: string): boolean {
  const t = ADMAX_TAGS[slot];
  return !!t && !t.startsWith('PLACEHOLDER');
}
