# 文字数オーバーを直して出す（2026-09-05 22:33 JST・費用 $0）

> **原因は文面だけだった。** `[1/2]` の X 重みが **293**（上限 280）で、
> 投稿ボタンが有効にならず `post-via-playwright.js` が中止していた。
> Chrome も CDP（18810）も画像も正常。

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. 本文を書き換える（**280 を超えていたら書かない**）

「しかも牛丼チェーンは朝4:00から開いてる。」を削除した（2026-09-05 に利用者が指定）。
朝 4:00 の話は **4 枚目の画像**で伝わるので、本文から落としても情報は落ちない。

```
  [1/2] の重み: 252 / 280
  [2/2] の重み: 194 / 280
  書き換えた: 293 → 252
```

## 2. 画像を取り直す

```
  1-summary.jpg    250062 bytes
  2-matsuya.jpg    157075 bytes
  3-komeda.jpg     171572 bytes
  4-sukiya.jpg     212141 bytes
```

## 3. 出す

```
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
[step] connect t=0ms
[step] navigate-target t=129ms
[step] find-reply-textarea t=6250ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6298ms
[step] type-text t=6298ms
[step] arm-response-listener t=9591ms
[step] submit t=9593ms
[step] wait-response-or-confirm t=9697ms
[step] wait-textarea-clear t=10093ms
{"ok":true,"tweet_id":"2096230281909006590","url":"https://x.com/heng_ji31590/status/2096230281909006590","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2096230281909006590","url":"https://x.com/heng_ji31590/status/2096230281909006590","image_attached":true,"captured_via":"graphql_response"},{"index":1,"role":"cta","ok":true,"reply_tweet_id":"2096230358161482222","url":"https://x.com/heng_ji31590/status/2096230358161482222","captured_via":"graphql_response"}],"captured_via":"graphql_response"}
(rc=0)
```

## 4. [1/2] と [2/2] は両方 出たか

- 投稿済みエントリ: **0 件**（開始前 0 件）

```json
{
 "id": "blog-promo-20260905-morning-500-2026",
 "status": "pending",
 "x_tweet_id": null,
 "weight": 252,
 "images": 4,
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "weight": 252,
   "tweet_id": null,
   "posted": false
  },
  {
   "n": 2,
   "role": "cta",
   "weight": 194,
   "tweet_id": null,
   "posted": false
  }
 ],
 "error": null
}
```

**2 本とも `posted: true` でなければ、出ていないか片肺。**

---

**LLM を呼んでいない（$0）。** **X 上の手動投稿はキューからは見えない。**
