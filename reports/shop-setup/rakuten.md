# 3 店ボタンの Mac 側の準備: rakuten（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:42:37.199Z**

- 画面: https://webservice.rakuten.co.jp/app/list

- 「More Details」を押した: https://webservice.rakuten.co.jp/app/list
- Application ID: 36 文字（Keychain の値と同じ）
- Access Key が画面に見つからない（「表示」ボタンで隠れている可能性）。ボタン一覧を下に出す
## アプリ一覧の画面

- 画面: https://webservice.rakuten.co.jp/app/list（Your Applications）

見出し:
- Your Applications
- dailyhack
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
