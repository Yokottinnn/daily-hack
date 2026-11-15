# 3 店ボタンの Mac 側の準備・8 回目（t339・**$0**）

生成: **2026-10-25T16:58:26+0900**

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

生成: **2026-10-25T07:58:42.068Z**

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
- 「Access Key」の行のまわりの HTML（値は伏せる）:
```html
<div id="［41文字・伏せた］" class="card mb-4"> <div class="card-header d-flex ［23文字・伏せた］ p-4 mb-3 gap"> <div class="d-flex flex-column gap"> <h2 id="［45文字・伏せた］" class="headlineLv2">dailyhack</h2> <div class="text-secondary"> <span id="［47文字・伏せた］" class="status-badge active px-2 py-1 mr-2"> ACTIVE </span> Expires: <span id="［47文字・伏せた］" data-iso-date="2027-10-14T23:18:16+09:00">14 Oct 2027</span> </div> </div> <div class="d-flex ［18文字・伏せた］ gap"> <button id="［51文字・伏せた］" type="button" class="btn ［18文字・伏せた］" onclick="［16文字・伏せた］('［36文字・伏せた］')" disabled=""><i class="fa fa-sync-alt text-dark mr-2"></i>Refresh</button> <button id="［51文字・伏せた］" type="button" class="btn ［18文字・伏せた］" onclick="［16文字・伏せた］('［36文字・伏せた］')">More Details</button> <button id="［48文字・伏せた］" type="button" class="btn ［18文字・伏せた］" onclick="openEditModal('［36文字・伏せた］')"><i class="fa fa-edit text-dark mr-2"></i>Edit</button> </div> </div> <div class="card-body row no-gutters px-4 pt-3 pb-4"> <div class="col-sm-6 p-2"> <span id="［50文字・伏せた］" class="d-block text-secondary mb-1">Application URL</span> <a href="https://daily-hack.fieldbeside.com/" target="_blank" id="［40文字・伏せた］" class="text-primary">https://daily-hack.fieldbeside.com/</a> </div> <div class="col-sm-6 p-2"> <span id="［49文字・伏せた］" class="d-block text-secondary mb-1">Application ID</span> <div class="d-flex"> <code id="［43文字・伏せた］" class="flex-grow-1">［36文字・伏せた］</code> <button type="button" id="［48文字・伏せた］" class="btn icon-button" onclick="copyToClipboard('［36文字・伏せた］')"><i class="fa fa-clone"></i></button> </div> </div> <div class="col-sm-6 p-2"> <span id="［53文字・伏せた］" class="d-block text-secondary mb-1">Access Key</span> <div class="d-flex"> <code class="flex-grow-1" id="［47文字・伏せた］">［伏せ字］</code> <button type="button" id="［20文字・伏せた］
```
- カードの文字（値は伏せる）:
  - dailyhack
  - ACTIVE Expires: 14 Oct 2027
  - Refresh
  - More Details
  - Edit
  - Application URL
  - https://daily-hack.fieldbeside.com/
  - Application ID
  - ［36文字・伏せた］
  - Access Key
  - ［伏せ字］
  - Affiliate ID
  - 587f2635.77bb335f.587f2636.e34c8733
- カードの中のボタン:
  - button 「Refresh」 aria= title= data=
  - button 「More Details」 aria= title= data=
  - button 「Edit」 aria= title= data=
  - a 「https://daily-hack.fieldbeside」 aria= title= data=
  - button 「」 aria= title= data=
  - button 「」 aria= title= data=
  - button 「」 aria= title= data=
  - button 「」 aria= title= data=
- 楽天 API（2026-07-01 版）の試し: HTTP 400・{
  "errors": {
    "errorCode": 400,
    "errorMessage": "accessKey must be present as a query parameter or in the header"
  }
}

- moshimo-apply: rc=0
  - ログの末尾:
    ボタン:
    - 提携申請する ／ 提携申請する
    
    ## 「申請中」で絞った一覧の Amazon の行
    
    
# 3 店ボタンの Mac 側の準備: moshimo-apply（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:58:56.796Z**

## 確認の画面の文字

- プロモーション期間 2010年 9月 29日 ～ プロモーション内容 2024年8月7日より紹介料上限なしで報酬アップとなりました。 高額報酬商品の成果実績（2025年4月中旬から5月中旬）データPDFを配布中です。 ※もしもアフィリエイト実績をもとにしたデータです。 Amazon全体のデータではございません。 ※このデータは紹介商品選定目的での参考情報としてお役立てください。それ以外の利用を一切禁止しています。コピーや転載も禁止です。違反すると提携解除などの対処になる場合がございます。 「Amazonで成果を伸ばすノウハウ」ページを公開しました。 提携前に以下の内容を必ずご確認ください ※提携申請時にはコンテンツは直近のもの (一般的に 60 日以内に更新されているもの) である必要があります。なお、10記事以上のコンテンツが必要です。10記事に満たない場合は提携できかねます。※ ※肖像権にご注意ください※ ※芸能人の画像を勝手に使用することは禁じられております※ Amazon.co.jp（アマゾン）での商品購入に際して、アフィリエイト報酬を得ることができるプログラムです。 スマートフォンでの購入も成果となります。ただし、レポート上ではPCの成果として表示されます。ご了承下さい。 ［21文字・伏せた］ ■提携について ［21文字・伏せた］ ・提携審査には数週間かかる場合がございます。 ・アマゾンアソシエイト審査基準をもとに厳重に審査しています。 Amazonアソシエイト・プログラム運営規約について 申請の審査プロセスについて ・作成されたばかりの未完成サイトや、運営がされていないサイトは提携できません。 少なくとも10記事以上あることが必要です。 ・過去に問題があり提携解除された方は、他のサイトであっても再提携できません。 ※審査の規定により、未成年者様の提携はできません※ ＜提携できないサイトの例＞ ・リベートサイト（当該サイトのリンクを経由してショッピングを行うことと引き換えに、エンドカスタマーに対してポイント、キャッシ

- 確認の画面の「提携申請する」を押した（https://af.moshimo.com/af/shop/promotion/detail）
- 出たダイアログ: confirm「提携申請には、あなたのサイトやブログを登録する必要があります。
メディア登録ページに移動しますか？」（moshimo-apply では「OK」を押す）
## 押したあとの画面

- 画面: https://af.moshimo.com/af/shop/promotion/detail（プロモーション詳細(「Amazon.co.jp」商品購入（商品カテゴリによって報酬率が異なります）) ｜ もしもアフィリ）

見出し:

入力欄:
- select[type=select-one name=shop_site_id] 「」
- input[type=text name=words] 「プロモーション条件を詳細に設定して検索できます」
- input[type=submit name=] 「」

ボタン:
- 提携申請する ／ 提携申請する

## 「申請中」で絞った一覧の Amazon の行



- moshimo-status: rc=0
  - ログの末尾:
    
    生成: **2026-10-25T07:59:15.273Z**
    
    - Amazon（170）の詳細: 「提携申請する」ボタン 2 個・画面の状態の語 申請中 / 提携中 / 否認中
    - apply_status=1 で絞った一覧: ? 件・Amazon.co.jp の行 0
    - apply_status=2 で絞った一覧: ? 件・Amazon.co.jp の行 0
# 3 店ボタンの Mac 側の準備: moshimo-status（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:59:15.273Z**

- Amazon（170）の詳細: 「提携申請する」ボタン 2 個・画面の状態の語 申請中 / 提携中 / 否認中
- apply_status=1 で絞った一覧: ? 件・Amazon.co.jp の行 0
- apply_status=2 で絞った一覧: ? 件・Amazon.co.jp の行 0

- yahoo: rc=0
  - ログの末尾:
    
    入力欄:
    
    ボタン:
    - Yahoo! JAPAN IDでログイン
    
# 3 店ボタンの Mac 側の準備: yahoo（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T07:59:27.715Z**

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


rc=0 /    10431 bytes
