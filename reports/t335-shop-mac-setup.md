# 3 店ボタンの Mac 側の準備・4 回目（t335・**$0**）

生成: **2026-10-25T16:36:48+0900**

```text
moshimo: ログイン済み
rakuten: ログイン済み / 楽天ID 0 件
```
- rakuten: rc=0
# 3 店ボタンの Mac 側の準備: rakuten（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:37:05.987Z**

- 画面: https://webservice.rakuten.co.jp/app/list

- Application ID: 36 文字（Keychain の値と同じ）
- Access Key が画面に見つからない（「表示」ボタンで隠れている可能性）。ボタン一覧を下に出す
## アプリ一覧の画面

- 画面: https://webservice.rakuten.co.jp/app/list（Your Applications）

見出し:
- Your Applications
- dailyhack
- Information

入力欄:

ボタン:
- TOOL BOX ／ New App ／ Refresh ／ More Details ／ Edit

- 楽天 API（2026-07-01 版）の試し: HTTP 400・{
  "errors": {
    "errorCode": 400,
    "errorMessage": "accessKey must be present as a query parameter or in the header"
  }
}

- moshimo-apply-open: rc=0
# 3 店ボタンの Mac 側の準備: moshimo-apply-open（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:37:14.257Z**

- 本番のトップに Amazon アソシエイトの記載: ある
- 画面の提携状態の語: 申請中 / 提携中 / 否認
## 「提携申請する」を押したあと（最後の送信は押していない）

- 画面: https://af.moshimo.com/af/shop/promotion/detail（プロモーション詳細(「Amazon.co.jp」商品購入（商品カテゴリによって報酬率が異なります）) ｜ もしもアフィリ）

見出し:
- ご確認ください
- ！提携基準の例

入力欄:
- select[type=select-one name=shop_site_id] 「」
- input[type=text name=words] 「プロモーション条件を詳細に設定して検索できます」
- input[type=submit name=] 「」

ボタン:
- 提携申請する ／ 提携申請する ／ 閉じる ／ 提携申請する

## 出た確認の画面の文字



- yahoo: rc=0
# 3 店ボタンの Mac 側の準備: yahoo（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:37:22.801Z**

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


rc=0 /     2923 bytes
