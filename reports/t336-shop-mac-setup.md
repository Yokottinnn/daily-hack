# 3 店ボタンの Mac 側の準備・5 回目（t336・**$0**）

生成: **2026-10-25T16:42:21+0900**

```text
moshimo: ログイン済み
rakuten: ログイン済み / 楽天ID 0 件
```
- rakuten: rc=0
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

- moshimo-apply: rc=1
（moshimo-apply の出力が無い）

- yahoo: rc=0
# 3 店ボタンの Mac 側の準備: yahoo（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:42:59.961Z**

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


rc=0 /     2094 bytes
