export type ReferralCategory =
  | 'bank'
  | 'securities'
  | 'mobile'
  | 'creditcard'
  | 'pointsite'
  | 'taxi'
  | 'ec'
  | 'wallet';

export interface Referral {
  id: string;
  serviceName: string;
  category: ReferralCategory;
  code?: string;
  url: string;
  affiliateUrl?: string;
  reward: string;
  description: string;
  isActive: boolean;
  conditions?: string;
  expiresAt?: string;
}

export const referrals: Referral[] = [
  // 🏦 銀行
  {
    id: 'rakuten-bank',
    serviceName: '楽天銀行',
    category: 'bank',
    code: 'P02545868',
    url: 'https://www.rakuten-bank.co.jp/',
    reward: '紹介者 最大2,000pt/人、被紹介者 200pt',
    description: 'ハッピープログラム登録 + 残高10万円以上で楽天ポイント付与',
    conditions: 'ハッピープログラム登録必須、残高10万円以上',
    isActive: true,
  },
  {
    id: 'olive-smbc',
    serviceName: 'Olive（三井住友銀行）',
    category: 'bank',
    code: 'FF31794-9555509',
    url: 'https://www.smbc.co.jp/kojin/redirect/referral04/index.html',
    reward: '1,000円相当のポイント',
    description: '三井住友銀行の総合金融サービスOliveの紹介プログラム',
    conditions: '契約日の翌月末時点で残高10,000円以上',
    isActive: true,
  },
  {
    id: 'mizuho-bank',
    serviceName: 'みずほ銀行',
    category: 'bank',
    code: 'M478340355',
    url: 'https://www.mizuhobank.co.jp/campaign/referral/index.html',
    reward: '紹介者・被紹介者ともに特典あり',
    description: '口座開設後にエントリーフォームで紹介コードを入力',
    isActive: true,
  },
  {
    id: 'mufg-bank',
    serviceName: '三菱UFJ銀行',
    category: 'bank',
    code: 's297512618',
    url: 'https://www.bk.mufg.jp/kouza/lp/kouza_shoukai/index.html',
    reward: '紹介してもされても1,500円',
    description: '口座紹介プランで両者に特典',
    conditions: '条件・留意事項あり',
    isActive: true,
  },
  {
    id: 'jre-bank',
    serviceName: 'JRE BANK',
    category: 'bank',
    code: 'J94101753',
    url: 'https://www.rakuten-bank.co.jp/rd/app/jre/introduction_code/s001.html',
    reward: 'JR東日本グループのおトクな特典・ポイント',
    description: '楽天銀行が提供するJR東日本グループ専用の銀行サービス',
    isActive: true,
  },
  {
    id: 'cq-bank',
    serviceName: 'CQ BANK',
    category: 'bank',
    code: 'yokotin1989', // ペイフォワードID
    url: 'https://app.adjust.com/1o154w35',
    reward: 'ペイフォワードプログラム特典',
    description: 'CQBANKアプリ口座開設時にペイフォワードIDを入力',
    isActive: true,
  },

  // 📈 証券
  {
    id: 'sbi-securities',
    serviceName: 'SBI証券',
    category: 'securities',
    url: 'https://www.sbisec.co.jp/',
    reward: '被紹介者 現金2,500円',
    description: '2万円入金 + SBIハイブリッド預金設定で2,500円',
    conditions: '2万円入金 + SBIハイブリッド預金設定',
    isActive: false, // 紹介コード要記入
  },
  {
    id: 'monex-securities',
    serviceName: 'マネックス証券',
    category: 'securities',
    url: 'https://www.monex.co.jp/',
    reward: '被紹介者 最大3,000dpt',
    description: 'dアカウント連携で500pt × 6ヶ月',
    conditions: 'dアカウント連携',
    isActive: false, // 紹介コード要記入
  },

  // 📱 格安SIM・通信
  {
    id: 'rakuten-mobile',
    serviceName: '楽天モバイル',
    category: 'mobile',
    url: 'https://network.mobile.rakuten.co.jp/',
    reward: '紹介者 7,000pt、被紹介者 13,000pt',
    description: 'MNP + 初めてのプラン申込で楽天ポイント',
    conditions: 'MNP + 初めてのプラン申込',
    isActive: false, // 紹介コード要記入（my楽天モバイルアプリで確認）
  },

  // 💳 クレジットカード
  {
    id: 'rakuten-card',
    serviceName: '楽天カード',
    category: 'creditcard',
    url: 'https://www.rakuten-card.co.jp/',
    reward: '被紹介者 最大5,000pt',
    description: '楽天市場・楽天サービス連携で還元率アップ',
    isActive: false, // 紹介コード要記入（楽天e-NAVIで確認）
  },
  {
    id: 'smbc-card-nl',
    serviceName: '三井住友カード(NL)',
    category: 'creditcard',
    url: 'https://www.smbc-card.com/',
    reward: '被紹介者 最大8,000pt',
    description: 'ナンバーレスでセキュリティ重視、コンビニ・飲食店で7%還元',
    isActive: false, // 紹介コード要記入（Vpassアプリで確認）
  },
  {
    id: 'recruit-card',
    serviceName: 'リクルートカード',
    category: 'creditcard',
    url: 'https://recruit-card.jp/',
    reward: '時期により変動',
    description: '基本還元率1.2%の高還元カード',
    isActive: false, // 紹介コード要記入（時期により変動）
  },
  {
    id: 'saison-mitsui-sp',
    serviceName: 'セゾン三井SP',
    category: 'creditcard',
    url: 'https://www.saisoncard.co.jp/',
    reward: '時期により変動',
    description: 'セゾンカードの三井ショッピングパーク特化型',
    isActive: false,
  },

  // 🛒 EC・アプリ
  {
    id: 'rakuten-ichiba-app',
    serviceName: '楽天市場アプリ',
    category: 'ec',
    url: 'https://r10.to/hg20Ks',
    reward: '条件達成で最大1,000ポイント',
    description:
      '楽天市場アプリではじめて、または久しぶりのお買い物で最大1,000ポイント',
    isActive: true,
  },

  // 💰 ウォレット
  {
    id: 'air-wallet',
    serviceName: 'エアウォレット',
    category: 'wallet',
    code: 'zsqt8m6',
    url: 'https://coinplus.go.link/jH372',
    reward: '招待プログラム特典',
    description:
      'COIN+を利用してチャージ・支払い・送金・出金が無料でできるアプリ',
    isActive: true,
  },

  // 🚕 タクシーアプリ
  {
    id: 'go-taxi',
    serviceName: 'GO（タクシーアプリ）',
    category: 'taxi',
    code: 'mf-stra3u',
    url: 'https://go.mo-t.com/',
    reward: '紹介者 2,000円クーポン、被紹介者 500円OFF',
    description: 'タクシー配車アプリの紹介プログラム',
    isActive: true,
  },
  {
    id: 'sride',
    serviceName: 'S.RIDE（タクシーアプリ）',
    category: 'taxi',
    code: 'sr-3ifuun',
    url: 'https://coupon.sride.jp/friend/ja/index.html?expire_datetime=2026.06.23&price=2000&code=sr-3ifuun&ad_set_name=referral&media_source=referral&campaign=referral&submit_date=20211201',
    reward: '2,000円クーポン',
    description: 'タクシー配車アプリの友達紹介プログラム',
    expiresAt: '2026-06-23',
    isActive: true,
  },
];

export function getReferralById(id: string): Referral | undefined {
  return referrals.find((r) => r.id === id);
}

export function getReferralsByCategory(
  category: ReferralCategory,
): Referral[] {
  return referrals.filter((r) => r.category === category && r.isActive);
}

export function getActiveReferrals(): Referral[] {
  return referrals.filter((r) => r.isActive);
}
