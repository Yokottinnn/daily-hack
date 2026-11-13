# 3 店ボタンの Mac 側の準備・Amazon の入り直し（t617・**$0**）

生成: **2026-11-14T07:29:56+0900**

```text
a8: ログイン済み
```
- amazon-login: rc=0
  - ログの末尾:
    - input[type=submit name=] 「」
    - input[type=checkbox name=continueCheck] 「私は人間です」
    
    ボタン:
    - ショートカットの表示/非表示 Shift + opt + Z ／ お届け先: 中央区 132-8501 場所を更新する ／ 検索 ／ すべて ／ Continue ／ トップへ戻る ／ 日本
    
# 3 店ボタンの Mac 側の準備: amazon-login（scripts/shop/mac-setup.mjs）

生成: **2026-11-13T22:30:14.438Z**

- Keychain の dailyhack-asp-amazon: 2 件（新しい順に試す・ID の形: メール・24文字 ／ メール・23文字）
- 最初の状態: signin（https://www.amazon.co.jp/ap/signin）
- 1 件目の ID で試す
  - 入れたあとの状態: other（https://www.amazon.co.jp/ax/claim）・Amazon がこの ID を知らない（「初めてご利用」）
## ログインの途中で止まった画面（押していない）

- 画面: https://www.amazon.co.jp/checkpoint/continue（Amazon.co.jp）

見出し:
- 次に移動
- キーボードショートカット
- お客様へのおすすめ商品を表示

入力欄:
- select[type=select-one name=url] 「検索するカテゴリーを選択します。」
- input[type=text name=field-keywords] 「Amazon.co.jpを検索」
- input[type=submit name=] 「」
- input[type=checkbox name=continueCheck] 「私は人間です」

ボタン:
- ショートカットの表示/非表示 Shift + opt + Z ／ お届け先: 中央区 132-8501 場所を更新する ／ 検索 ／ すべて ／ Continue ／ トップへ戻る ／ 日本


rc=0 /     1741 bytes
