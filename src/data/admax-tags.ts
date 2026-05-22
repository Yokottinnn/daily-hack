// 忍者AdMAX 広告タグ ID マッピング
// /s/ = 単一タグ（PC専用 or SP専用）
// /o/ = PC/SP切替タグ（admax 側で User-Agent 判定して自動切替）
// プレースホルダのまま（'PLACEHOLDER' 開始）の場合、AdMax コンポーネントは何もレンダリングしない。

export const ADMAX_TAGS: Record<string, string> = {
  // 記事冒頭（PC/SP 自動切替）
  'dailyhack-article-top':
    '<script src="https://adm.shinobi.jp/o/555a47585725f470386659e29c9a0219"></script>',

  // 記事末尾（PC/SP 自動切替）
  'dailyhack-article-bottom':
    '<script src="https://adm.shinobi.jp/o/9b44a340d3a0eba82ee421d63470d060"></script>',

  // ホーム Hero 直下（PC/SP 自動切替）
  'dailyhack-home-below-hero':
    '<script src="https://adm.shinobi.jp/o/1908adb671f615f5516614713585fe9c"></script>',

  // PC サイドバー — PC 専用、SP では非表示（CSS）
  'dailyhack-sidebar-sticky':
    '<script src="https://adm.shinobi.jp/s/5c402299304c5c1277f408f99997f78a"></script>',

  // スマホ フッター固定 — SP 専用、PC では非表示（CSS）
  'dailyhack-sticky-mobile':
    '<script src="https://adm.shinobi.jp/s/5496d5523dab7e28f9d54710923f7f6e"></script>',
};

export type AdMaxSlot = keyof typeof ADMAX_TAGS;

export function isAdMaxConfigured(slot: string): boolean {
  const t = ADMAX_TAGS[slot];
  return !!t && !t.startsWith('PLACEHOLDER');
}
