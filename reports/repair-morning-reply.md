# [2/2] を出し直す（2026-09-23 21:22 JST・$0）

**このレポートが作られた時刻: 2026-09-23 21:22:55 JST**

> **`x137` が返した `reply_tweet_id` は実在しなかった**（利用者が URL を開いて確認）。
> **DOM を見て、自分の返信が無ければ出し直す。**

## 1. Chrome は健全か（**口は 18810**）

```
{"ok":true,"healthy":true,"round_trip_ms":267,"product":"Chrome/140.0.7339.207","tabs":1}
(rc=0)
```

## 2. `[1/2]` の実物を見る

**見るのは 2 つ。** 1 本目が実在するか。**自分の返信が既にぶら下がっていないか。**

```json
{"id":"2102732457930064353","exists":true,"articles":1,"photos":0,"head":"朝マックのマフィン180円が最安、って思ってない？","replies":[]}
```

- `[1/2]` は実在する
- **自分の返信はぶら下がっていない。出し直す。**

## 3. 画像を `origin/main` から取り直す

```
  取得  cover-a.jpg  179000 bytes
```

## 4. `post-comment.js` を直接 叩く（**画像つき**）

`run-publish.sh` は通さない。**1 本目はもう出ているので、返信だけを足す。**

```
[step] connect t=0ms
[step] navigate-target t=176ms
[step] find-reply-textarea t=6326ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6366ms
[step] type-text t=6366ms
[step] attach-image n=1 t=10374ms
[step] arm-response-listener t=12803ms
[step] submit t=12804ms
[step] wait-response-or-confirm t=12913ms
[step] wait-textarea-clear t=13713ms
{"ok":true,"reply_tweet_id":"2102735550893736203","url":"https://x.com/heng_ji31590/status/2102735550893736203","captured_via":"graphql_response"}
(rc=0)
```

## 5. **出たかを DOM で確かめる**（`reply_tweet_id` は信用しない）

**今回 外したのがまさにそこ。** 返り値ではなく、ぶら下がっているかを見る。

```json
{"id":"2102732457930064353","exists":true,"articles":2,"photos":0,"head":"朝マックのマフィン180円が最安、って思ってない？","replies":[{"mine":true,"photos":1,"head":"なか卯の目玉焼き朝食、300円。"}]}
```

### 最終状態

- ぶら下がっている自分の返信: **1 件**（実行前 0 件）
- その返信の画像: **1 枚**（期待 1 枚）

**[2/2] が DOM 上に在る。** 画像の枚数も上のとおり。

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
