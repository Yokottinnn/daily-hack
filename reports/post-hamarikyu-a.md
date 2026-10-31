# チームラボ 浜離宮の告知を出す（2026-10-31 14:20:07 JST・$0）

## 関所の付いた X 系の処理が残っていないか
## 送り方（x369 の直し）が入っているか
- 入っている
[x-action-pacer] tweet: 取れた

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. 文面を origin/main から取る

```
  [1/2] rc=0 / 文字 1376
  [2/2] rc=0 / 文字 281
```

## 2. 画像 4 枚を origin/main から取り出す（300円の夜の公開を 2 枚目に）

- 1-cover.jpg: 286846 bytes
- 4-yoru-300.jpg: 137603 bytes
- 2-access.jpg: 163174 bytes
- 3-vs-toyosu.jpg: 125939 bytes
## 3. キューに積んで出す

```
{"ok":true,"id":"blog-promo-20261031-hamarikyu-a"}
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
[x-action-pacer] tweet: 空いた
[step] connect t=0ms
[step] navigate-target t=1598ms
[step] find-reply-textarea t=7818ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=7871ms
[step] type-text t=7871ms
[x154] like 付いた
[step] arm-response-listener t=11430ms
[step] submit t=11432ms
[step] wait-response-or-confirm t=11519ms
[step] wait-textarea-clear t=11878ms
{"ok":true,"tweet_id":"2116399877550936189","url":"https://x.com/heng_ji31590/status/2116399877550936189","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2116399877550936189","url":"https://x.com/heng_ji31590/status/2116399877550936189","image_attached":true,"captured_via":"graphql_response"},{"index":1,"role":"cta","ok":true,"reply_tweet_id":"2116400104148259005","url":"https://x.com/heng_ji31590/status/2116400104148259005","captured_via":"graphql_response"}],"captured_via":"graphql_response"}
(rc=0)
```

## 4. キューへ書き戻す

```
  x_tweet_id=2116399877550936189 [2/2] x_tweet_id=取れていない ok=true
```

## 5. 実物を読む（permalink）

```
{"items":[{"href":"/heng_ji31590/status/2116399877550936189","len":534,"head":"豊洲のチームラボに行ったことあるあんた。\n今度は、夜の浜離宮がまるごとチームラボ","media":4},{"href":"/heng_ji31590/status/2116400104148259005","len":75,"head":"「浜離宮のチームラボって、豊洲のチームラボと何が違うの？」\n地元からの行き方と、","media":0}]}
```

URL: https://x.com/heng_ji31590/status/2116399877550936189

**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
