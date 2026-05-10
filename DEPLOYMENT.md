# Daily Hack — デプロイ・外部連携マニュアル

このドキュメントは Claude Code が自動化できない、Jordan が手動で行う必要がある作業を整理しています。**Phase 7・9・10・12・14 が対象**です。

---

## Phase 7: GitHub & Cloudflare Pages 連携

### 7.1 GitHub CLI のインストール（ホストPCで初回のみ）

```bash
brew install gh
gh auth login
# 「GitHub.com」→「HTTPS」→「Login with a web browser」を選択
# ブラウザに表示される認証コードを入力
```

### 7.2 GitHub リポジトリの作成

```bash
cd ~/projects/anta-baka-x/blog
gh repo create daily-hack --private --source=. --remote=origin --push
```

> ⚠️ **注意**: 現在ローカルブランチは `main` にリネーム済み。`master` のままだと `gh repo create` 実行時に main ブランチがプッシュされないので注意。

### 7.3 ブランチ保護の設定（ガードレール4 / 必須）

GitHub の Web UI で:
1. リポジトリ → Settings → Branches
2. "Add branch protection rule"
3. Branch name pattern: `main`
4. 以下にチェック:
   - ☑ Require a pull request before merging
   - ☑ Require status checks to pass before merging
     - 「test-build」を必須チェックに追加
   - ☑ Require branches to be up to date before merging
   - ☑ Do not allow bypassing the above settings

> これで OpenClaw は **直接 main に push できなくなり、必ず PR 経由になる**。本番サイトを保護する最後の砦。

### 7.4 Cloudflare Pages 接続

1. https://dash.cloudflare.com/ にログイン
2. Workers & Pages → Pages → "Create application" → "Connect to Git"
3. GitHub リポジトリ `daily-hack` を選択
4. Build settings:
   - Framework preset: **Astro**
   - Build command: `npm run build`
   - Output directory: `dist`
   - Node version: `22`（Build environment variables で `NODE_VERSION=22` を設定）
5. "Save and Deploy" をクリック

### 7.5 PR Preview Deployments の有効化（ガードレール5 / 必須）

Cloudflare Pages のプロジェクト設定:
- Settings → Builds & deployments → Preview branches → "All non-Production branches" を選択
- これで PR を作成するたびに自動的に `<branch>.daily-hack.pages.dev` のプレビュー URL が生成されます

---

## Phase 9: カスタムドメイン設定

### 9.1 Squarespace で CNAME レコードを追加

1. https://account.squarespace.com/domains にログイン
2. `fieldbeside.com` の DNS設定を開く
3. 以下の CNAME レコードを追加:

| Type | Host | Value |
|---|---|---|
| CNAME | `daily-hack` | `daily-hack.pages.dev`（Cloudflare Pages のデフォルトドメインに置換） |

### 9.2 Cloudflare Pages 側で カスタムドメインを設定

1. Pages → daily-hack project → Custom domains
2. "Set up a custom domain" → `daily-hack.fieldbeside.com` を入力
3. DNS の検証完了を待つ（数分〜数時間）

✅ 完了後、`https://daily-hack.fieldbeside.com` で本番サイトにアクセス可能になります。

---

## Phase 10: Cloudflare R2 画像ホスティング

### 10.1 R2 バケットの作成

1. Cloudflare Dashboard → R2 → "Create bucket"
2. バケット名: `daily-hack-images`
3. Location: Asia-Pacific
4. Storage Class: Standard

### 10.2 パブリックアクセスとカスタムドメイン

1. バケット設定 → Settings → Custom Domains
2. `images.fieldbeside.com` を追加（Squarespace で `images` の CNAME を Cloudflare R2 のエンドポイントに向ける）

### 10.3 R2 API トークンの取得

1. R2 → "Manage R2 API Tokens" → "Create API token"
2. 権限: `Object Read & Write` for `daily-hack-images`
3. 取得した `accessKeyId` / `secretAccessKey` / エンドポイント URL を OpenClaw のリモートPC環境変数に設定:

```bash
# リモートPC（192.168.2.102）の ~/.zshrc に追記
export R2_ACCESS_KEY_ID="..."
export R2_SECRET_ACCESS_KEY="..."
export R2_ENDPOINT="https://<account>.r2.cloudflarestorage.com"
```

### 10.4 アップロードスクリプト

Phase 10 用に `scripts/upload-image.js` を別途実装予定。OpenClaw が記事アイキャッチを R2 へアップロードする際に呼び出します。

---

## Phase 12: Cloudflare Web Analytics

### 12.1 Web Analytics の有効化

1. Cloudflare Dashboard → Web Analytics → "Add a site"
2. ドメイン: `daily-hack.fieldbeside.com`
3. 提供される `<script>` snippet をコピー
4. `src/layouts/BaseLayout.astro` の `<head>` 内、コメント `<!-- Cloudflare Web Analytics -->` の下に貼り付け（`Cookie 不要なので Privacy Policy も既存記述で十分`）

> **既存実装メモ**: BaseLayout には現時点で snippet を組み込んでいません。Web Analytics 取得後に Edit で挿入してください。

---

## Phase 14: アクセストレード審査申請

### 14.1 申請前の最終チェック

- ☑ daily-hack.fieldbeside.com で実サイトにアクセスできる
- ☑ About / Privacy / Disclaimer / Contact ページが整備されている（実装済み）
- ☑ 記事が10〜15本以上公開されている（現在5本、さらに5〜10本投入が必要）
- ☑ 各記事に PR表記が適切に入っている
- ☑ サイトマップ・RSS が機能している

### 14.2 申請手順

1. https://www.accesstrade.ne.jp/ にアクセス
2. 「サイト登録」フォームに以下を入力:
   - サイト名: Daily Hack
   - サイトURL: https://daily-hack.fieldbeside.com
   - 法人名: 合同会社FieldBeside
   - 担当者: 横田直紀
   - 連絡先: n-yokota@fieldbeside.com
3. 審査開始（数営業日〜2週間）

### 14.3 審査落ちた場合

よくある原因と対処:
- **記事数不足**: 10本以上に増やす
- **PR表記不備**: Privacy Policy・Disclaimer の文言を強化
- **運営者情報が薄い**: About ページに法人情報を追記
- **連絡先が機能していない**: Contact フォームの返信メールが届くか確認

---

## Phase 8 残タスク: GitHub ブランチ保護の確認テスト

すべて完了したら、ガードレールが期待通り動くか検証してください:

1. ローカルで `git push origin main` を直接試す → **拒否されるはず**（成功してしまったらブランチ保護を再確認）
2. `scripts/blog-publish.sh test "テスト記事"` で意図的にビルドエラーを起こす → **PR が作成されないはず**
3. 適当なブランチで PR を作成 → **GitHub Actions のビルドテストが走るはず**
4. プレビューデプロイの URL が PR コメントに自動投稿されるはず

✅ 4つすべて確認できたらガードレール完備。

---

## OpenClaw への引き渡し

Phase 7・9 完了後、OpenClaw 側のリモートPC（192.168.2.102）で以下を実行:

```bash
# リポジトリのクローン
mkdir -p ~/repos
cd ~/repos
git clone git@github.com:<user>/daily-hack.git
cd daily-hack

# 依存インストール（リモートPCの Node 22 が前提）
npm ci

# ローカルでビルド確認
npm run build

# blog-publish.sh の動作確認
./scripts/blog-publish.sh test-post "テスト記事"
```

OpenClaw のスキル `blog_publisher.md` から `~/repos/daily-hack/scripts/blog-publish.sh` を呼び出すよう設定します。
