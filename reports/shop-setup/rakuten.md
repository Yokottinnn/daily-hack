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
