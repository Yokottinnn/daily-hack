# text-safety の上限を直して、感謝祭の告知を出す（2026-10-18 12:27:19 JST・$0）

## 0. まだ出ていないか

- キューの状態: **not**

## 1. text-safety.js の上限を直す

```
  書き換えた（退避: text-safety.js.bak-x322）
  105:  const maxWeighted = opts.maxWeighted ?? (Number(process.env.X_MAX_WEIGHTED) || 25000); // 2026-10-18 x322: 青バッジで上限 25,000
```

## 2. 直したあと、キューの本文が検査を通るか

```
  [1/2] 重み 2375 / ok=true 
  [2/2] 重み 131 / ok=true 
```

## 3. 出す

```
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
[step] connect t=0ms
[step] navigate-target t=3501ms
[step] find-reply-textarea t=9965ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=10558ms
[step] type-text t=10558ms
[x154] like 付いた
[step] arm-response-listener t=14319ms
[step] submit t=14322ms
[step] wait-response-or-confirm t=14404ms
[step] wait-textarea-clear t=14787ms
{"ok":true,"tweet_id":"2111660452979847604","url":"https://x.com/heng_ji31590/status/2111660452979847604","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2111660452979847604","url":"https://x.com/heng_ji31590/status/2111660452979847604","image_attached":true,"captured_via":"graphql_response"},{"index":1,"role":"cta","ok":true,"reply_tweet_id":"2111660549784342885","url":"https://x.com/heng_ji31590/status/2111660549784342885","captured_via":"graphql_response"}],"captured_via":"graphql_response"}
(rc=0)
```

## 4. キューへ書き戻す

```
[wb] t1=2111660452979847604 t2=2111660549784342885 ok=true
  status=posted x_tweet_id=2111660452979847604
  [1/2] x_tweet_id=2111660452979847604
  [2/2] x_tweet_id=2111660549784342885
```

**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。実物の確認は次のタスクで読む。**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
