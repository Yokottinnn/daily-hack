# FUNDS 紹介のスレッドを投稿する（2026-10-11 08:24 JST・費用 $0）

**このレポートが作られた時刻: 2026-10-11 08:24:20 JST**

> **[1/2] 画像 4 枚・[2/2] 本文だけの 2 投稿。** 文面は承認済みのものを 1 文字も変えていない（最上位ルール 18）。

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. 添付まわり（確認用）

```
57:    await page.waitForSelector(textareaSelector, { timeout: 30000 });
68:      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
69:      if (!fileInput) fileInput = await page.$('input[type="file"]');
71:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
83:          const box = document.querySelector('[data-testid="attachments"]');
86:          const removes = document.querySelectorAll('[aria-label*="削除"], [data-testid="removeMedia"]').length;
117:      const btn = document.querySelector('[data-testid="tweetButton"]')
118:               || document.querySelector('[data-testid="tweetButtonInline"]');
125:      out({ ok: false, step, error: "X refused to enable the post button — nothing was posted",
```

## 2. X の重み（**280 を超えていたら積まない**）

```
  [1/2] 271 / 280（余裕 9）
  [2/2] 270 / 280（余裕 10）
```

## 3. 画像 4 枚を `origin/main` から取り出す

```
  取得  1-gift.jpg       141127 bytes
  取得  2-service.jpg    165958 bytes
  取得  3-fund.jpg       146495 bytes
  取得  4-story.jpg      150468 bytes
  対象 4 枚 / 取れた 4 枚
```

## 4. キューに積む

```json
{"ok":true,"id":"blog-promo-20261010-funds"}
```

## 5. Chrome は健全か（**口は 18810**）

```
{"ok":true,"healthy":true,"round_trip_ms":4303,"product":"Chrome/140.0.7339.207","tabs":24}
(rc=0)
```

## 6. 出す（**`cut` で切らない**）

```
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
[step] connect t=0ms
[step] navigate-target t=4630ms
[step] find-reply-textarea t=11274ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=11318ms
[step] type-text t=11319ms
[x154] like 付いた
[step] arm-response-listener t=14779ms
[step] submit t=14781ms
[step] wait-response-or-confirm t=14903ms
[step] wait-textarea-clear t=15278ms
{"ok":true,"tweet_id":"2109062647786455517","url":"https://x.com/heng_ji31590/status/2109062647786455517","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2109062647786455517","url":"https://x.com/heng_ji31590/status/2109062647786455517","image_attached":true,"captured_via":"graphql_response"},{"index":1,"role":"body","ok":true,"reply_tweet_id":"2109062747602469352","url":"https://x.com/heng_ji31590/status/2109062747602469352","captured_via":"graphql_response"}],"captured_via":"graphql_response"}
(rc=0)
```

## 7. 出たか。**出たならキューに書き戻す**

```
  [1/2] tweet_id = 2109062647786455517
  [2/2] tweet_id = 2109062747602469352（ID が返っても出ているとは限らない。x255 で実物を見る）
  キューを posted に書き戻した
```

### 最終状態

- 投稿済みエントリ: **1 件**（開始前 0 件）

```json
{
 "id": "blog-promo-20261010-funds",
 "status": "posted",
 "x_tweet_id": "2109062647786455517",
 "weight": 291,
 "top_images": 4,
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "weight": 291,
   "images": 4,
   "tweet_id": "2109062647786455517",
   "posted": true
  },
  {
   "n": 2,
   "role": "body",
   "weight": 270,
   "images": 0,
   "tweet_id": "2109062747602469352",
   "posted": true
  }
 ],
 "error": null
}
```

**一次情報は `x_tweet_id` と投稿 URL の実物だけ**（最上位ルール 11）。画像 4 枚と [2/2] が付いているかは x255 で X 上の実物を見て確かめる。

---

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
