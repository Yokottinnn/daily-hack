# JAL マイル2倍の [2/2] を出す（2026-10-04 20:02 JST・$0）

**このレポートが作られた時刻: 2026-10-04 20:02:46 JST**

## ① キューを先に書き戻す（[1/2] の二重投稿を防ぐ）

```
  前: {"status":"pending","auto_publish":true,"x_tweet_id":null}
  後: {"status":"posted","auto_publish":false,"x_tweet_id":"2106699830819258421","reply":null}
```

## ② [1/2] の実物と、ぶら下がっている自分の返信

```
{"ok":true,"healthy":true,"round_trip_ms":325,"product":"Chrome/140.0.7339.207","tabs":2}
{"id":"2106699830819258421","exists":true,"replies":[],"articles":1,"photos":4,"head":"先に言っとくわね。"}
```

- [1/2] は在る。**自分の返信は無い。出す。**

## ③ [2/2] を出す（`post-comment.js` を直接・画像なし）

```
[step] connect t=0ms
[step] navigate-target t=98ms
[step] find-reply-textarea t=6274ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6336ms
[step] type-text t=6336ms
[x154] すでに いいね済み。触らない
{"ok":false,"step":"text-mismatch","error":"欄の中身が打った文と違う。送らない","want_len":180,"got_len":182,"want_head":"正直、歩いてポイ活ってア","got_head":"正直、歩いてポイ活ってア"}
(rc=1)
```

## ④ 出たかを実物で確かめる（返り値の ID は信用しない）

```
{"id":"2106699830819258421","exists":true,"replies":[],"articles":1,"photos":4,"head":"先に言っとくわね。"}
```

**まだ見えない。** 上の出力の全文を見ること。rc は証拠にならない（最上位ルール 13）

## ⑤ 1 回目（19:55）が [2/2] を出せなかった手がかり

```
  --- publish-payid-oneshot.log（該当 1 行・末尾 12 行）
    {"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"QkFTReOBp+S9nOOCieOCjOOBn+OCt+ODp+ODg+ODl+KAlOKAlOOBguOBruWAi+S6uuWVhuW6l+OBv+OBn+OBhOOBquODjeODg+ODiOOCt+ODp+ODg+ODl+OBjOOAgeOBnOOCk+OBtuOBk+OBruOC
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
