# 自分の最新の投稿と CAMP のエラー（2026-11-22 12:47:53 JST・読むだけ・$0）

## エラー行（本文の base64 を除く）
```
{"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js <本文> \"https://x.com/heng_ji31590/status/2124340481173975432\" \"null\"\n[x-action-pacer] tweet: 空いた\n[step] connect t=0ms\n[step] navigate-target t=2651ms\n[step] find-reply-textarea t=8918ms\n[textarea] found via primary sel: div[data-testid^=\"tweetTextarea_\"][contenteditable=\"true\"] t=8961ms\n[step] type-text t=8961ms\n[x154] like 付いた\n","child_stdout":"{\"ok\":false,\"step\":\"text-mismatch\",\"error\":\"欄の中身が打った文と違う。送らない\",\"want_len\":117,\"got_len\":0,\"want_head\":\"2〜3人の組で月を受け持\",\"got_head\":\"\"}\n","child_stderr":"[x-action-pacer] tweet: 空いた\n[step] connect t=0ms\n[step] navigate-target t=2651ms\n[step] find-reply-textarea t=8918ms\n[textarea] found via primary sel: div[data-testid^=\"tweetTextarea_\"][contenteditable=\"true\"] t=8961ms\n[step] type-text t=8961ms\n[x154] like 付いた\n","thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2124340481173975432","url":"https://x.com/heng_ji31590/status/2124340481173975432","image_attached":true,"captured_via":"graphql_response"}]}
{"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js <本文> \"https://x.com/heng_ji31590/status/2124340963200086271\" \"null\"\n[x-action-pacer] tweet: 空いた\n[step] connect t=0ms\n[step] navigate-target t=2338ms\n[step] find-reply-textarea t=8587ms\n[textarea] found via primary sel: div[data-testid^=\"tweetTextarea_\"][contenteditable=\"true\"] t=11526ms\n[step] type-text t=11527ms\n[x154] like 付いた\n","child_stdout":"{\"ok\":false,\"step\":\"type-text\",\"error\":\"elementHandle.click: Element is not attached to the DOM\\nCall log:\\n  - attempting click action\\n    - waiting for element to be visible, enabled and stable\\n\"}\n","child_stderr":"[x-action-pacer] tweet: 空いた\n[step] connect t=0ms\n[step] navigate-target t=2338ms\n[step] find-reply-textarea t=8587ms\n[textarea] found via primary sel: div[data-testid^=\"tweetTextarea_\"][contenteditable=\"true\"] t=11526ms\n[step] type-text t=11527ms\n[x154] like 付いた\n","thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2124340963200086271","url":"https://x.com/heng_ji31590/status/2124340963200086271","image_attached":true,"captured_via":"graphql_response"}]}
```

## 自分のプロフィールの最新の投稿
```
[固定] 2026-06-08T13:41:37.000Z /heng_ji31590/status/2063979763619021022 画像1 ｜ あんた、ポイ活で消耗してない？w 楽天・PayPay・d・V・Ponta…全部使い倒したアタシが言うわ。大事なのは『どれをやるか』じゃなく『
2026-11-22T03:15:28.000Z /heng_ji31590/status/2124340963200086271 画像2 ｜ 豊洲のSCSK本社で、子どもがタダで2027年のカレンダーを作れるの、知らなかったでしょ？  📅 12/6（日）13〜17時 👦 小1〜
2026-11-22T03:13:33.000Z /heng_ji31590/status/2124340481173975432 画像2 ｜ 豊洲のSCSK本社で、子どもがタダで2027年のカレンダーを作れるの、知らなかったでしょ？  📅 12/6（日）13〜17時 👦 小1〜
2026-11-21T04:47:22.000Z /heng_ji31590/status/2124001703401844981 画像1 ｜ ブラックフライデー、店のセールだけ見てたらもったいないわよ。 払い方で戻ってくるキャンペーンが、いま乱立してるの。11/15に各社の公式で確
```

**読むだけ。何も押していない。LLM 不使用（$0）。**
