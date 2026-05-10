# Daily Hack — お得情報メディア

合同会社FieldBeside運営。「お得を毎日、ハック。」をスローガンに、ポイ活・節約・固定費削減のリアル最新情報を毎日アップデートする情報メディアです。

- 本番URL: https://daily-hack.fieldbeside.com（公開後）
- 連動Xアカウント: [@heng_ji31590](https://x.com/heng_ji31590)
- 運営: 合同会社FieldBeside（代表: 横田直紀 / n-yokota@fieldbeside.com）

## 技術スタック

- **Frontend**: Astro 6.x + Tailwind CSS v4
- **Content**: Markdown + Astro Content Collections + Zod schema
- **Hosting**: Cloudflare Pages（無料枠）
- **Images**: Cloudflare R2（無料枠 10GB）
- **Search**: Pagefind（クライアントサイド）
- **Analytics**: Cloudflare Web Analytics（Cookie不要）
- **CI/CD**: GitHub Actions（ビルドテスト） + Cloudflare Pages（自動デプロイ）

## 開発

```bash
npm install
npm run dev    # http://localhost:4321
npm run build  # ./dist/ にビルド
npm run preview
```

## ガードレール（不可逆な失敗を防ぐ仕組み）

1. **Zod スキーマ**: `src/content.config.ts` で frontmatter を厳密検証
2. **Pre-commit hook**: Husky + lint-staged + markdownlint-cli2
3. **GitHub Actions**: PR時に必ずビルドテスト
4. **ブランチ保護**: main への直接 push を禁止（GitHub Web UIで設定）
5. **PR Preview Deploy**: PR毎に `<branch>.daily-hack.pages.dev` 生成（Cloudflare Pages設定）
6. **`scripts/blog-publish.sh`**: OpenClaw 用の自己復旧スクリプト

## ディレクトリ

```
src/
├── content/
│   ├── posts/             # ブログ記事（Markdown）
│   └── weekly-quotes/     # 今週のひとこと
├── components/            # Astroコンポーネント
├── layouts/               # BaseLayout, PostLayout
├── pages/                 # ルーティング
│   ├── index.astro        # トップページ
│   ├── posts/[...slug].astro
│   ├── category/[category].astro
│   ├── about.astro / privacy.astro / disclaimer.astro / contact.astro
│   ├── search.astro       # Pagefind検索
│   └── rss.xml.js
├── data/
│   └── referrals.ts       # 全サービスのリファラル情報
├── styles/
│   └── global.css         # Tailwind v4 + デザイントークン
└── content.config.ts      # Zodスキーマ（ガードレール1）

scripts/
└── blog-publish.sh        # OpenClaw連携スクリプト（ガードレール6）

.github/workflows/
└── test-build.yml         # GitHub Actionsビルドテスト（ガードレール3）

.husky/
└── pre-commit             # 構文チェック（ガードレール2）

DEPLOYMENT.md              # 外部連携手順（Phase 7, 9, 10, 12, 14）
```

## 記事の書き方

`src/content/posts/<slug>.md` に Markdown ファイルを作成。frontmatter は以下のスキーマに従ってください:

```yaml
---
title: "記事タイトル（100文字以内）"
description: "メタ説明（50〜160文字）"
publishDate: 2026-05-11
category: "campaigns" | "services" | "comparisons" | "roundups" | "howto"
tags: ["タグ1", "タグ2"]
isPR: true | false
draft: true | false
featured: true | false  # トップページ「編集部おすすめ」に表示
parentPillar: "親ピラー記事のslug"  # ピラー×クラスター構造のクラスター側に指定
relatedReferrals: ["referral-id-1", "referral-id-2"]  # AffiliateLinkコンポーネントで参照可能なID
---
```

## 関連ドキュメント

- `~/projects/anta-baka-x/docs/01_DailyHackブログ構築_全体引き継ぎ.md` — 全体引き継ぎ
- `~/projects/anta-baka-x/docs/あんたバカ速報_設計引き継ぎ資料v3.md` — ブランド・キャラクター仕様
- `~/projects/anta-baka-x/docs/ClaudeDesign向け/` — 各ページの情報設計（デザイン依頼書）
- `DEPLOYMENT.md` — 手動デプロイ手順
