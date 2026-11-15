# 参考投稿の中身と、いいねの有無（2026-09-26 23:04 JST・$0）

**このレポートが作られた時刻: 2026-09-26 23:04:25 JST**

> **読むだけ。** いいねも押していない。投稿もしていない。

## 1. 参考投稿の実物（**型を写すために、1 文字も直さず出す**）

```
  HTTP 200   4808 bytes
```

### 本文（行番号つき）

```
    1 | PAY ID 
    2 | 登録した瞬間500円分くれるのww
    3 | 
    4 | けっこう食品多そうだったから、
    5 | 肉とか米とか餃子とかにしてみるか？🧐
    6 | 
    7 | まだの方いたらどぞ！
    8 | 
    9 | 招待コード：252Y8H
   10 | 
   11 | 招待コードを入力すると
   12 | 《500円分のPAY IDポイント》がもらえます！
   13 | #PR
   14 | 
   15 | ▽PAY IDアプリはこちら
   16 | https://t.co/u0N1ZM7n6x https://t.co/d0CQBPbnhd
  
    文字数: 194   X の重み: 290 / 280
```

### 付帯情報（**どう作られた投稿か**）

```
    投稿時刻          2026-09-25T02:28:11.000Z
    画像            3 枚
    動画            なし
    親             （なし）
    リンク           https://s.payid.jp/y0OYKalk
    ハッシュタグ        #PR
    いいね           22
```

## 2. 返信するときに「いいね」もしているか

経路は `comment-orchestrator.sh` → `post-comment.js`（`x149` で確定）。
**いいねに触れている箇所が 1 つも無ければ、押していない。**

```
  post-comment.js                いいね関連  0 箇所
  comment-orchestrator.sh        いいね関連  0 箇所
  post-via-playwright.js         いいね関連  0 箇所
  comment-state.js               いいね関連  0 箇所
  ---
  合計 0 箇所
```

- **1 箇所も無い。いいねは押していない。** 付けるなら実装から

ほかのスクリプトに いいねの実装が在るか（**在れば書き方を写せる**）:

```
  bookmark-watcher.js
  engage-via-playwright.js
  fetch-4-tweets.js
  fetch-ffbuncho.js
  incoming-reply-responder.js
  post-metrics-collector.js
  respond-to-2-replies.js
  scrape-tweet-engagement.js
  scrape-tweet-replies-2063979763619021022.js
  trend-detect.js
```

---

## 読み方

| §2 の出方 | 次の一手 |
| --- | --- |
| いいねが **0 箇所** | **実装する。** 返信の直前か直後に `[data-testid="like"]` を押す |
| いいねが在るのに押されていない | **条件で飛んでいる。** その条件を読む |
| 別のスクリプトに実装が在る | **その書き方を写す**（セレクタと待ちに実績がある） |

> **いいね自体は DOM 操作なので LLM を呼ばない。** 付けても課金は増えない。

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
