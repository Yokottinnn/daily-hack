# X に出せなくなった原因の分析（2026-10-30 00:29:47 JST・読むだけ・$0）

## 1. 返信の結果の推移（comment-warmup.log・日ごと・成功と失敗の段）
```
20261021 {"ok":22}
20261022 {"ok":20}
20261023 {"ok":19}
20261024 {"ok":19}
20261025 {"ok":24}
20261026 {"ok":10}
```

## 2. 返信のログの最後 25 行（10/27 以降の失敗の中身）
```
[2026-10-29T16:00:02] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-10-29T16:03:07] picked 5 / max 5 (from 7 candidates)
[2026-10-29T16:03:07] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
[2026-10-29T16:03:07] today's reply-connected follows: 1 / 30
[2026-10-29T16:03:07] --- processing #1/5 for @<伏せ> ---
[2026-10-29T16:03:09]   → chosen template_id: unknown
[2026-10-29T16:03:10] enqueue: {"ok":true,"id":"comment-20261029-1603-0"}
[2026-10-29T19:00:00] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-10-29T19:03:06] picked 5 / max 5 (from 12 candidates)
[2026-10-29T19:03:06] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
[2026-10-29T19:03:06] today's reply-connected follows: 2 / 30
[2026-10-29T19:03:06] --- processing #1/5 for @<伏せ> ---
[2026-10-29T19:03:08] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手の投稿は励ましと感謝で、金銭・節約・AI副業の具体的な内容がない。ハッシュタグに該当ワードはあるが、本文に足がかりがな�
[2026-10-29T19:03:08] --- processing #2/5 for @<伏せ> ---
[2026-10-29T19:03:10] gen failed (#2): {"ok":false,"error":"噛み合い検査で弾いた: 同じ語の繰り返し「で食べるの」＝日本語が壊れている","skip":true,"reason":"噛み合い検査で弾いた: 同じ語の繰り返し「で食べ�
[2026-10-29T19:03:10] --- processing #3/5 for @<伏せ> ---
[2026-10-29T19:03:12]   → chosen template_id: unknown
[2026-10-29T19:03:12] enqueue: {"ok":true,"id":"comment-20261029-1903-2"}
[2026-10-29T22:00:05] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-10-29T22:03:13] picked 5 / max 5 (from 15 candidates)
[2026-10-29T22:03:14] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
[2026-10-29T22:03:14] today's reply-connected follows: 2 / 30
[2026-10-29T22:03:14] --- processing #1/5 for @<伏せ> ---
[2026-10-29T22:03:16]   → chosen template_id: unknown
[2026-10-29T22:03:16] enqueue: {"ok":true,"id":"comment-20261029-2203-0"}
```

## 3. 返信の入力欄が開けなかったときの画面（最新の保存 HTML から、見えている文字）
```
ファイル: /tmp/post-comment-no-textarea-1793279219252.html（8 件）
title: Xユーザーのナゴヤヒロさん: 「都城市から宮崎牛が到着😄
牛肩ローススライス１㎏👍
＃ふるさと納税 https://t.co/2WoXZXpCLQ」 / X
Xユーザーのナゴヤヒロさん: 「都城市から宮崎牛が到着😄 | 牛肩ローススライス１㎏👍 | ＃ふるさと納税 https://t.co/2WoXZXpCLQ」 / X | JavaScriptを使用できません。 | ヘルプセンター | 利用規約 | プライバシーポリシー | Cookieのポリシー | インプリント | 広告情報 | © 2026 X Corp. | キーボードショートカットを表示するには、はてなマークを押してください。 | キーボードショートカットを表示 | 返信できない理由 | この作成者はあなたをブロックしているため、この操作を実行できません | OK | ホーム | 話題を検索 | 通知 | チャット | 通話 | Grok | プレミアム | 履歴 | 記事 | プロフィール | もっと見る | ポストする | あんたバカぁ？まだ損してるの？速報💸 | @heng_ji31590 | ポスト | 新しいポストを表示 | 会話 | ナゴヤヒロ | @<伏せ> | 都城市から宮崎牛が到着😄 | 牛肩ローススライス１㎏👍 | #ふるさと納税 | 午後9:15 · 2026年10月29日 | · | 284 | 件の表示 | 40 | 一部のアカウントのみが返信できます。 | 関連性の高いアカウント | ナゴヤヒロ | @<伏せ> | フォロー | クリックして164kdrさんをフォロー | 自由な名古屋人😁｜不動産賃貸業｜株主優待｜高配当株｜現物派｜ふるさと納税｜備忘録｜名古屋グランパス｜中日ドラゴンズ｜家庭菜園｜ラーメン｜カツ丼｜ディズニー｜ホラー映画｜ガンダム｜バーニーズマウンテンドッグ👍 | 問題が発生しました。再読み込みしてください。 | やりなおす | 速報 | 「いま」を見つけよう | NIKKE4周年 | 終章を見届け、新たな旅へ。最大259回分のガチャが無料！ | Promoted by 【公式】勝利の女神：NIKKE | テクノロジー · トレンド | Mac Studio | 音楽 · トレンド
```

## 4. 投稿キューの 10/27 以降（状態と失敗の段）
```
{"comment:pending":19,"thread:pending":4}
comment-20261029-2203-0 pending 
blog-promo-20261029-cinema-toyosu pending 
blog-promo-20261029-cinema-toyosu-r2 pending 
blog-promo-20261029-cinema-toyosu-r3 pending 
blog-promo-20261029-cinema-toyosu-r4 pending 
```

## 5. 自分の最新の投稿が見えるか（ログインしていない状態の公開 API で）
```

```

## 6. Chrome のログイン状態（X の cookie があるか・値は出さない）
```
cookie: auth_token=あり ct0=あり twid=あり
auth_token の期限: 2027-09-07T15:14:37.840Z
```
**読んだだけ。押していない（$0）。**
