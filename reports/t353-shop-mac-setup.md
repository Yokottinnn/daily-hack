# 3 店ボタンの Mac 側の準備・15 回目（t353・**$0**）

生成: **2026-10-25T21:25:48+0900**

```text
moshimo: ログイン済み
rakuten: ログイン済み / 楽天ID 0 件
```
- moshimo-media: rc=0
  - ログの末尾:
    - 確認の小窓の HTML:
    ```html
    <form name="［25文字・伏せた］" method="post" action="https://af.moshimo.com/af/shop/management/media/register" ［25文字・伏せた］="0"> <input type="hidden" name="form_name" value="［25文字・伏せた］"> <div class="［19文字・伏せた］"> <div class="［23文字・伏せた］"> <input class="input-form" name="media_url" placeholder="https://example.com" value="" type="text" ［31文字・伏せた］="0"> </div> <div class="［23文字・伏せた］"> <ul class="［24文字・伏せた］"> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］">ご自身で運営されているWebサイト、ブログ、アプリ、YouTubeチャンネル、Instagramアカウント、X(Twitter)アカウント等をご登録いただけます。ただし、プロモーション提携可能（広告掲載可能）なメディアは「Webサイト、ブログ、アプリ、YouTube、Instagram、X(Twitter)のいずれか」かつ「広告主が提携を認めた」場合です。</p> </li> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］">同じアカウント内で、過去に登録されたことがあるURLはご登録いただけません。過去に登録済みのURLを復活（有効）としたい場合や不明点がある場合は<a href="https://af.moshimo.com/af/shop/help?#faq967">よくある質問</a>をご確認ください。</p> </li> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］"><a class="media-link-text" href="https://af.moshimo.com/af/shop/support/snsGuideline">SNS・YouTube掲載におけるガイドライン</a></p> </li> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］"><a class="media-link-text" href="https://af.moshimo.com/af/shop/support/［16文字・伏せた］">プロフィールページのメディア登録ガイドライン</a></p> </li> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］"><a class="media-link-text" href="https://af.moshimo.com/af/shop/support/siteGuideline">メディア登録審査ガイドライン</a></p> </li> </ul> </div> <div class="［23文字・伏せた］"> <div class="［29文字・伏せた］"> <button class="media-button" id="open-modal" type="button">メディアを登録する</button> </div> </div> </div> <div id="［20文字・伏せた］"> <div id="modal_overlay" class="overlay active"> <div id="modal_area" class="modal-wrapper active"> <div class="modal"> <div class="modal-contents"> <div class="modal-header"> <h4>登録前にご確認ください。(<span id="progress">1/2</span>)</h4> <span id="close-modal" class="close-btn"></span> </div> <div class="modal-body"> <div id="q1" class="question"> <dl> <dd><p>1</p></dd> <dt><p>登録するメディアは5記事以上・5投稿以上である。</p></dt> </dl> <div class="question-body"> <div class="block"> <div class="btn-box"> <p id="q1_ans_no" class="btn-item no">いいえ</p> <p id="q1_ans_yes" class="btn-item yes">はい</p> </div> </div> <p class="info">5記事・5投稿未満で登録されますと登録後の審査で削除となります。<br>独自コンテンツのない記事・投稿は含まれません。<br>※現状、X（Twitter）の登録にはフォロワー数3,000人以上が必要です。</p> </div> </div> <div id="a1" class="question disapprove hidden"> <dl> <dt><p>登録するメディアが5記事未満の場合</p></dt> </dl> <div class="question-body"> <div class="block"> <p class="info">5記事以上にしてから登録を行ってください。<br>5記事未満で登録されますと、登録後の審査で削除となります。</p> </div> <div class="btn-box single"> <p id="a1_close" class="btn-item close">確認して閉じる</p> </div> </div> </div> <div id="q2" class="question hidden"> <dl> <dd><p>2</p></dd> <dt><p>登録するメディアは著作権・肖像権・翻訳権・翻案権を侵害していない。</p></dt> </dl> <div class="question-body"> <div class="block"> <div class="btn-box"> <p id="q2_ans_no" class="btn-item no">いいえ</p> <p id="q2_ans_yes" class="btn-item yes">はい</p> </div> </div> <p class="info">著作権・肖像権・翻訳権・翻案権侵害の恐れがあると<br>登録後の審査で登録削除となります。<br>X（Twitter）などのアイコンへの使用も含まれます。</p> </div> </div> <div id="a2" class="question disapprove hidden"> <dl> <dt><p>登録するメディアが著作権・肖像権・翻訳権・翻案権を侵害している場合</p></dt> </dl> <
    ```
    - 選択肢:
      - select[name=shop_site_id]: メディアを選択
# 3 店ボタンの Mac 側の準備: moshimo-media（scripts/shop/mac-setup.mjs）

生成: **2026-10-25T12:26:22.724Z**

## 申請の画面のメディアの選択肢

- ✔ メディアを選択（value 空）

## メディア登録へのリンク

- 登録メディア一覧（登録） — https://af.moshimo.com/af/shop/management/media
- メディア運営ツール — javascript: void(0)
- メディア育成ガイド — https://af.moshimo.com/af/shop/howToGrow
- メディア登録審査ガイドライン — https://af.moshimo.com/af/shop/support/siteGuideline
- メディア登録が削除となる事例 — https://af.moshimo.com/af/shop/support/［18文字・伏せた］
- メディア運営ガイドライン — https://af.moshimo.com/af/shop/support/［18文字・伏せた］
- プロフィールページのメディア登録ガイドライン — https://af.moshimo.com/af/shop/support/［16文字・伏せた］

## メディア一覧の画面

- 画面: https://af.moshimo.com/af/shop/management/media（メディア一覧 ｜ もしもアフィリエイト）

見出し:
- メディア一覧
- メディア登録

入力欄:
- select[type=select-one name=shop_site_id] 「」
- input[type=text name=words] 「表示中のページではプロモーション検索機能をご利用いただけません」
- input[type=submit name=] 「」
- input[type=text name=media_url] 「https://example.com」

ボタン:
- メディアを登録する

## URL を入れて「メディアを登録する」を押したあと（この先は送っていない）

- 画面: https://af.moshimo.com/af/shop/management/media（メディア一覧 ｜ もしもアフィリエイト）

見出し:
- メディア一覧
- メディア登録

入力欄:
- select[type=select-one name=shop_site_id] 「」
- input[type=text name=words] 「表示中のページではプロモーション検索機能をご利用いただけません」
- input[type=submit name=] 「」
- input[type=text name=media_url] 「https://example.com」

ボタン:
- メディアを登録する

- 画面の案内の文字:
  - メディアを選択
  - カテゴリで探す
  - メディア登録審査ガイドライン
  - メディア登録が削除となる事例
  - プロフィールページのメディア登録ガイドライン
  - メディア登録
  - ご自身で運営されているWebサイト、ブログ、アプリ、YouTubeチャンネル、Instagramアカウント、X(Twitter)アカウント等をご登録いただけます。ただし、プロモーション提携可能（広告掲載可能）なメディアは「Webサイト、ブログ、アプリ、YouTube、Instagram、X(Twitter)のいずれか」
  - 同じアカウント内で、過去に登録されたことがあるURLはご登録いただけません。過去に登録済みのURLを復活（有効）としたい場合や不明点がある場合はよくある質問をご確認ください。
  - プロフィールページのメディア登録ガイドライン
  - メディア登録審査ガイドライン
  - メディアを登録する
  - 登録前にご確認ください。(1/2)
  - 登録するメディアは5記事以上・5投稿以上である。
  - 5記事・5投稿未満で登録されますと登録後の審査で削除となります。
  - ※現状、X（Twitter）の登録にはフォロワー数3,000人以上が必要です。
  - 利用規約 会社概要 プライバシーポリシー カスタマーハラスメント対応ポリシー よくある質問
- 押せそうな要素（後ろの 30 個）:
  - a 「[上級者]任意パラメータ」
  - a.navi-knowhow 「ノウハウを学ぶ」
  - a 「成果をもっと伸ばすコツ」
  - a 「メディア育成ガイド」
  - a 「クリエイター向けノウハウページ」
  - a 「Amazonで成果を伸ばすノウハウ」
  - a.navi-guideline 「ガイドライン」
  - a 「ガイドライン一覧」
  - a 「メディア登録審査ガイドライン」
  - a 「メディア登録が削除となる事例」
  - a 「メディア運営ガイドライン」
  - a 「楽天の注意点まとめ」
  - a 「Amazonの注意点まとめ」
  - a 「SNS・YouTube掲載におけるガイドライン」
  - a 「プロフィールページのメディア登録ガイドライン」
  - a.navi-support 「サポート」
  - a 「よくある質問」
  - a 「もしもアフィリエイトの始め方」
  - a 「もしもアフィリエイトの特徴」
  - a 「理解しておきたい「広告主の気持ち」」
  - a 「W報酬」
  - a 「特単の条件」
  - a.media-link-text 「SNS・YouTube掲載におけるガイドライン」
  - a.media-link-text 「プロフィールページのメディア登録ガイドライン」
  - a.media-link-text 「メディア登録審査ガイドライン」
  - button.media-button 「メディアを登録する」
  - a 「利用規約」
  - a 「会社概要」
  - a 「プライバシーポリシー」
  - a 「カスタマーハラスメント対応ポリシー」
- 確認の小窓の HTML:
```html
<form name="［25文字・伏せた］" method="post" action="https://af.moshimo.com/af/shop/management/media/register" ［25文字・伏せた］="0"> <input type="hidden" name="form_name" value="［25文字・伏せた］"> <div class="［19文字・伏せた］"> <div class="［23文字・伏せた］"> <input class="input-form" name="media_url" placeholder="https://example.com" value="" type="text" ［31文字・伏せた］="0"> </div> <div class="［23文字・伏せた］"> <ul class="［24文字・伏せた］"> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］">ご自身で運営されているWebサイト、ブログ、アプリ、YouTubeチャンネル、Instagramアカウント、X(Twitter)アカウント等をご登録いただけます。ただし、プロモーション提携可能（広告掲載可能）なメディアは「Webサイト、ブログ、アプリ、YouTube、Instagram、X(Twitter)のいずれか」かつ「広告主が提携を認めた」場合です。</p> </li> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］">同じアカウント内で、過去に登録されたことがあるURLはご登録いただけません。過去に登録済みのURLを復活（有効）としたい場合や不明点がある場合は<a href="https://af.moshimo.com/af/shop/help?#faq967">よくある質問</a>をご確認ください。</p> </li> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］"><a class="media-link-text" href="https://af.moshimo.com/af/shop/support/snsGuideline">SNS・YouTube掲載におけるガイドライン</a></p> </li> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］"><a class="media-link-text" href="https://af.moshimo.com/af/shop/support/［16文字・伏せた］">プロフィールページのメディア登録ガイドライン</a></p> </li> <li class="［29文字・伏せた］ ［16文字・伏せた］"> <p class="［24文字・伏せた］"><a class="media-link-text" href="https://af.moshimo.com/af/shop/support/siteGuideline">メディア登録審査ガイドライン</a></p> </li> </ul> </div> <div class="［23文字・伏せた］"> <div class="［29文字・伏せた］"> <button class="media-button" id="open-modal" type="button">メディアを登録する</button> </div> </div> </div> <div id="［20文字・伏せた］"> <div id="modal_overlay" class="overlay active"> <div id="modal_area" class="modal-wrapper active"> <div class="modal"> <div class="modal-contents"> <div class="modal-header"> <h4>登録前にご確認ください。(<span id="progress">1/2</span>)</h4> <span id="close-modal" class="close-btn"></span> </div> <div class="modal-body"> <div id="q1" class="question"> <dl> <dd><p>1</p></dd> <dt><p>登録するメディアは5記事以上・5投稿以上である。</p></dt> </dl> <div class="question-body"> <div class="block"> <div class="btn-box"> <p id="q1_ans_no" class="btn-item no">いいえ</p> <p id="q1_ans_yes" class="btn-item yes">はい</p> </div> </div> <p class="info">5記事・5投稿未満で登録されますと登録後の審査で削除となります。<br>独自コンテンツのない記事・投稿は含まれません。<br>※現状、X（Twitter）の登録にはフォロワー数3,000人以上が必要です。</p> </div> </div> <div id="a1" class="question disapprove hidden"> <dl> <dt><p>登録するメディアが5記事未満の場合</p></dt> </dl> <div class="question-body"> <div class="block"> <p class="info">5記事以上にしてから登録を行ってください。<br>5記事未満で登録されますと、登録後の審査で削除となります。</p> </div> <div class="btn-box single"> <p id="a1_close" class="btn-item close">確認して閉じる</p> </div> </div> </div> <div id="q2" class="question hidden"> <dl> <dd><p>2</p></dd> <dt><p>登録するメディアは著作権・肖像権・翻訳権・翻案権を侵害していない。</p></dt> </dl> <div class="question-body"> <div class="block"> <div class="btn-box"> <p id="q2_ans_no" class="btn-item no">いいえ</p> <p id="q2_ans_yes" class="btn-item yes">はい</p> </div> </div> <p class="info">著作権・肖像権・翻訳権・翻案権侵害の恐れがあると<br>登録後の審査で登録削除となります。<br>X（Twitter）などのアイコンへの使用も含まれます。</p> </div> </div> <div id="a2" class="question disapprove hidden"> <dl> <dt><p>登録するメディアが著作権・肖像権・翻訳権・翻案権を侵害している場合</p></dt> </dl> <
```
- 選択肢:
  - select[name=shop_site_id]: メディアを選択

rc=0 /    15054 bytes
