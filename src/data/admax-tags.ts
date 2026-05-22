// 忍者AdMAX 広告タグ ID マッピング
// 各 slot ID に対応する admax の「広告コード」を貼る。
// admax 管理画面 → タグを作成 → 表示される <script>...</script> コードを丸ごとここに貼る。
// プレースホルダのまま（'PLACEHOLDER' 開始）の場合、AdMax コンポーネントは何もレンダリングしない。

export const ADMAX_TAGS: Record<string, string> = {
  // 記事冒頭（PC向け） — リード文直下
  'dailyhack-article-top':
    '<script src="https://adm.shinobi.jp/s/f0c6d38cc9b16edd10d1147791b55d38"></script>',

  // 記事末尾（PC向け） — 本文と関連記事の間
  'dailyhack-article-bottom':
    '<script src="https://adm.shinobi.jp/s/97c7bf3063818d989e02688038f24ddc"></script>',

  // PC サイドバー — TOC 下
  'dailyhack-sidebar-sticky':
    '<script src="https://adm.shinobi.jp/s/5c402299304c5c1277f408f99997f78a"></script>',

  // ホーム Hero 直下 — UrgentCampaigns の上
  'dailyhack-home-below-hero':
    '<script src="https://adm.shinobi.jp/s/9263019aed27eda818d7fbf74b2cb8df"></script>',

  // スマホ フッター固定 — モバイルのみ
  'dailyhack-sticky-mobile':
    '<script src="https://adm.shinobi.jp/s/5496d5523dab7e28f9d54710923f7f6e"></script>',
};

export type AdMaxSlot = keyof typeof ADMAX_TAGS;

export function isAdMaxConfigured(slot: string): boolean {
  const t = ADMAX_TAGS[slot];
  return !!t && !t.startsWith('PLACEHOLDER');
}
