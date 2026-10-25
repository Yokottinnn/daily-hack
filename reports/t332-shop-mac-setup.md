# 3 店ボタンの Mac 側の準備・1 回目（t332・**$0**）

生成: **2026-10-25T16:21:48+0900**

```text
moshimo: ログイン済み
rakuten: ログイン済み / 楽天ID 0 件
```
- rakuten: rc=0
# 3 店ボタンの Mac 側の準備: rakuten（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:22:22.320Z**

- 画面: https://login.account.rakuten.com/session/upgrade

- Application ID: 見つからない
- Access Key が画面に見つからない（「表示」ボタンで隠れている可能性）。ボタン一覧を下に出す
## アプリ一覧の画面

- 画面: https://login.account.rakuten.com/session/upgrade（ログイン - 楽天）

見出し:

入力欄:

ボタン:
- 次へ ／ パスワードをお忘れの方 ／ 別の楽天IDでログイン

- 楽天 API（2026-07-01 版）の試し: HTTP 400・{
  "errors": {
    "errorCode": 400,
    "errorMessage": "accessKey must be present as a query parameter or in the header"
  }
}

- moshimo: rc=0
# 3 店ボタンの Mac 側の準備: moshimo（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:22:28.578Z**

- 「Amazon」で検索した画面: https://af.moshimo.com/af/shop/promotion/search

## Amazon を含むプロモーション

- 2 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=1&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- 3 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=2&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- 4 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=3&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- 5 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=4&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- 次 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=1&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- 最後 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=4&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- プロモーション詳細 — https://af.moshimo.com/af/shop/promotion/detail?promotion_id=170
  - Amazonと提携するためには多くの提携基準を守る必要があります。 プロモーション詳細を熟読してください。 ！提携基準の例 メディア内にAmazonとの関係を明記する必要があります。 記事例： 「Amazonのアソシエイトとして、当メディアは適格販売により収入を得ています。」 「このサイトはアフィリエイト広告（Amazonアソシエイト含む）を掲載しています。」 など ※ご自身のメディアのプロフィールやポリシーページ等に記載した上で提携申請をしてください。 審査時点で記載がない
- 2 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=1&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- 3 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=2&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- 4 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=3&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- 5 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=4&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 
- 次 — https://af.moshimo.com/af/shop/promotion/search?words=Amazon&order=open_datetime_d&page=1&limit=10
  - 提携対象：を選択中 "Amazon" の検索結果: 49 件 のプロモーションがヒットしました。 49件中: 1件～10件を表示中 提携 すべて 申請中 提携中 否認中 未提携 表示件数 10件 50件 100件 最初 前 1 2 3 4 5 次 最後 SellBridge Cloud｜Shopee 7カ国の出品・注文・利益管理を日本語で一元化する越境EC管理SaaSの有料プラン申込 サイト 成果 100% 有料プラン（月払い）の初回決済完了（Stripe経由）: 100% 

## 先頭のプロモーションの詳細（押していない）

- 画面: https://af.moshimo.com/af/shop/promotion/search（プロモーション検索 ｜ もしもアフィリエイト）

見出し:

入力欄:
- select[type=select-one name=shop_site_id] 「」
- input[type=text name=words] 「プロモーション条件を詳細に設定して検索できます」
- input[type=submit name=] 「」
- select[type=select-one name=apply_status] 「」
- select[type=select-one name=limit] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=checkbox name=lump[]] 「」
- input[type=submit name=] 「」

ボタン:
- 提携申請する ／ 提携申請する ／ 提携申請する ／ 提携申請する ／ 提携申請する ／ 提携申請する ／ 提携申請する ／ 提携申請する ／ 提携申請する ／ 提携申請する ／ 提携する ／ 全選択 ／ 選択解除 ／ 選択済のプロモーションに提携申請する


- yahoo: rc=0
# 3 店ボタンの Mac 側の準備: yahoo（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:22:43.250Z**

## アプリケーションの管理

- 画面: https://e.developer.yahoo.co.jp/dashboard/（アプリケーションの管理：Yahoo!デベロッパーネットワーク）

見出し:
- アプリケーションの管理
- 続けるには、Yahoo! JAPAN IDでログインする必要があります。
- 開発のヒント

入力欄:

ボタン:
- Yahoo! JAPAN IDでログイン

## 新しいアプリケーションを開発（登録の画面・送っていない）

- 画面: https://e.developer.yahoo.co.jp/register（アプリケーションの管理：Yahoo!デベロッパーネットワーク）

見出し:
- アプリケーションの管理
- 続けるには、Yahoo! JAPAN IDでログインする必要があります。
- 開発のヒント

入力欄:

ボタン:
- Yahoo! JAPAN IDでログイン


rc=0 /    11051 bytes
