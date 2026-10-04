# JAL マイル2倍の [2/2] を出す（2026-10-04 20:09 JST・$0）

**このレポートが作られた時刻: 2026-10-04 20:09:44 JST**

## ① キューを先に書き戻す（[1/2] の二重投稿を防ぐ）

```
  前: {"status":"posted","auto_publish":false,"x_tweet_id":"2106699830819258421"}
  後: {"status":"posted","auto_publish":false,"x_tweet_id":"2106699830819258421","reply":null}
```

## ② [1/2] の実物と、ぶら下がっている自分の返信

```
{"ok":true,"healthy":true,"round_trip_ms":397,"product":"Chrome/140.0.7339.207","tabs":3}
{"id":"2106699830819258421","exists":true,"replies":[],"articles":1,"photos":4,"head":"先に言っとくわね。"}
```

- [1/2] は在る。**自分の返信は無い。出す。**

## ③ [2/2] を出す（`post-comment.js` を直接・画像なし）

```
[step] connect t=0ms
[step] navigate-target t=127ms
[step] find-reply-textarea t=6449ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6497ms
[step] type-text t=6497ms
[x154] すでに いいね済み。触らない
[step] arm-response-listener t=10339ms
[step] submit t=10341ms
[step] wait-response-or-confirm t=10446ms
[step] wait-textarea-clear t=11028ms
{"ok":true,"reply_tweet_id":"2106703392739610923","url":"https://x.com/heng_ji31590/status/2106703392739610923","captured_via":"graphql_response"}
(rc=0)
```

## ④ 出たかを実物で確かめる（返り値の ID は信用しない）

```
{"id":"2106699830819258421","exists":true,"replies":[{"href":"/heng_ji31590/status/2106703392739610923","photos":0,"head":"正直、歩いてポイ活ってアツいのよ。"}],"articles":2,"photos":4,"head":"先に言っとくわね。"}
```

**[2/2] が在る → https://x.com/heng_ji31590/status/2106703392739610923**

```
  前: {"status":"posted","auto_publish":false,"x_tweet_id":"2106699830819258421"}
  後: {"status":"posted","auto_publish":false,"x_tweet_id":"2106699830819258421","reply":"2106703392739610923"}
```

## ⑤ 1 回目（19:55）が [2/2] を出せなかった手がかり

```
  --- publish-payid-oneshot.log（該当 1 行・末尾 12 行）
    {"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"QkFTReOBp+S9nOOCieOCjOOBn+OCt+ODp+ODg+ODl+KAlOKAlOOBguOBruWAi+S6uuWVhuW6l+OBv+OBn+OBhOOBquODjeODg+ODiOOCt+ODp+ODg+ODl+OBjOOAgeOBnOOCk+OBtuOBk+OBruOC
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
