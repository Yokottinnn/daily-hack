# 青バッジ取得の報告を投稿する（2026-10-12 20:33:09 JST・費用 $0）

> **1 投稿・GIF 1 枚。** 文面は承認済みのものを 1 文字も変えていない（最上位ルール 18）。

## 00. 同じ ID のエントリが残っていれば自動投稿を止める

```
  エントリは無い
```

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. 文面を origin/main から取り、ロックのハッシュと照合する

```
  ロック 一致 ／ 重み 216 / 280
```

## 3. GIF を origin/main から取り出す

```
  取得  2-card.gif       2596891 bytes
  対象 1 枚 / 取れた 1 枚
```

## 4. キューに積む（同じ ID の未投稿エントリは消してから積む）

```json
{"ok":true,"id":"blog-promo-20261012-blue-badge-2"}
```

## 5. Chrome は健全か

```
{"ok":true,"healthy":true,"round_trip_ms":549,"product":"Chrome/140.0.7339.207","tabs":2}
(rc=0)
```

## 6. 出す

```
[post-via-playwright] attached 1/1 image(s)
{"ok":false,"step":"parse-main-result","error":"main result not valid JSON","raw":""}
(rc=0)
```

## 7. 出たか。出たならキューに書き戻す

```
  ok:false。書き戻さない。 step=parse-main-result error=main result not valid JSON
```

## 8. 実物を読む（プロフィール → permalink。画像の枚数と alt）

### https://x.com/heng_ji31590/status/2109608374136689099

```
ついに青バッジ、付けたわよ✔️

ふん、見栄じゃないわよ。
あんたの損を、もっと遠くまで届けるためなんだから。

ポイ活・節約・お得情報、ここからもっと濃くしていくわ。
青バッジ同士、見かけたら仲良くしてあげてもいいわよ😏
```

**判定: 投稿 在る**

画面: x276-post.png

**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
