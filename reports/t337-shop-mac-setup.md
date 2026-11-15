# 3 店ボタンの Mac 側の準備・6 回目（t337・**$0**）

生成: **2026-10-25T16:46:54+0900**

```text
moshimo: ログイン済み
rakuten: ログイン済み / 楽天ID 0 件
```
- rakuten: rc=0
  - ログの末尾:
    - 楽天 API（2026-07-01 版）の試し: HTTP 400・{
      "errors": {
        "errorCode": 400,
        "errorMessage": "accessKey must be present as a query parameter or in the header"
      }
    }
# 3 店ボタンの Mac 側の準備: rakuten（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:47:10.485Z**

- 画面: https://webservice.rakuten.co.jp/app/list

- 「More Details」を押した: https://webservice.rakuten.co.jp/app/list
- Application ID: 36 文字（Keychain の値と同じ）
- Access Key が画面に見つからない（「表示」ボタンで隠れている可能性）。ボタン一覧を下に出す
- 入力欄の形（値は文字数だけ）:
  - input[type=hidden name=captcha-key id=refresh-captcha-key] 値0文字
  - input[type=text name=captcha id=refresh-captcha] 値0文字
  - input[type=hidden name=captcha-key id=edit-captcha-key] 値0文字
  - input[type=text name=app_name id=edit-app_name] 値0文字
  - input[type=url name=app_site id=edit-app_site] 値0文字
  - textarea[type=textarea name=origins id=edit-origins] 値0文字
  - textarea[type=textarea name=app_description id=edit-app_description] 値0文字
  - textarea[type=textarea name=usage_purpose id=edit-usage_purpose] 値0文字
  - input[type=text name=expected_qps id=edit-expected_qps] 値0文字
  - input[type=checkbox name=api_scopes[] id=edit-ichiba-checkbox] 値6文字
  - input[type=checkbox name=api_scopes[] id=edit-travel-checkbox] 値6文字
  - input[type=checkbox name=api_scopes[] id=edit-books-checkbox] 値5文字
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

- moshimo-status: rc=0
  - ログの末尾:
    
    生成: **2026-10-25T07:47:25.496Z**
    
    - Amazon（170）の詳細: 「提携申請する」ボタン 2 個・画面の状態の語 申請中 / 提携中 / 否認中
    - apply_status=1 で絞った一覧: ? 件・Amazon.co.jp の行 0
    - apply_status=2 で絞った一覧: ? 件・Amazon.co.jp の行 0
# 3 店ボタンの Mac 側の準備: moshimo-status（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:47:25.496Z**

- Amazon（170）の詳細: 「提携申請する」ボタン 2 個・画面の状態の語 申請中 / 提携中 / 否認中
- apply_status=1 で絞った一覧: ? 件・Amazon.co.jp の行 0
- apply_status=2 で絞った一覧: ? 件・Amazon.co.jp の行 0

- yahoo: rc=0
  - ログの末尾:
    
    入力欄:
    
    ボタン:
    - Yahoo! JAPAN IDでログイン
    
# 3 店ボタンの Mac 側の準備: yahoo（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:47:38.248Z**

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


rc=0 /     4032 bytes
