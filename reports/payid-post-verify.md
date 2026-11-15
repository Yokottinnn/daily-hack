# PAY ID パターン A は出たか（2026-09-27 15:44 JST・$0）

**このレポートが作られた時刻: 2026-09-27 15:44:56 JST**

> **読むだけ。** 投稿もキューの書き換えもしていない。

## 1. キューの行（**一次情報 ①**）

```json
  id              blog-promo-20260927-payid-a
  status          awaiting_approval
  kind            thread
  auto_publish    true
  scheduled_at    2026-09-27T03:00:00.000Z
  thread_chain    3 本
    [1/3] tweet_id=**無い**
    [2/3] tweet_id=**無い**
    [3/3] tweet_id=**無い**
```

> **`x_tweet_id` が空なら、出ていない。** それが答えになる。

## 2. 投稿 URL の実物（**一次情報 ②**）

**§1 で取れた id だけを当たる。** 取れなければ、ここは空で終わる。

```
  **tweet id が 1 本も取れない。投稿 URL は確かめられない。**
```

## 3. 1 回だけの plist はどうなったか

**走ったら自分を外して消える**作りにした。**消えていれば走った合図**になる
（ただし合図であって一次情報ではない。判断は §1・§2 で行う）。

```
  載っていない（外れている）
  plist: **まだ在る** 09-27 00:33
```

## 4. publisher のログの末尾（**参考。一次情報ではない**）

```
  === auto-x-publisher: **ログが無い** ===

  === publish-payid-oneshot（更新 09-27 12:00）===
    [run-publish] thread_chain mode
    [post-via-playwright] attached 4/4 image(s)
    [step] connect t=0ms
    [step] navigate-target t=103ms
    [step] find-reply-textarea t=6236ms
    [textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6280ms
    [step] type-text t=6280ms
    [x154] like 付いた
    {"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"QkFTReOBp+S9nOOCieOCjOOBn+OCt+ODp+ODg+ODl+KAlOKAlOOBguOBruWAi+S6uuWVhuW6l+OBv+OBn+OBhOOB
    [2026-09-27 12:00:30] done rc=0

```

---

## 読み方

| §1 の `x_tweet_id` | §2 の本文 | 結論 |
| --- | --- | --- |
| 在る | 在る | **出ている。** URL をそのまま報告する |
| 在る | 空 | **出たが消えている／見えない。** 原因を追う |
| 空・id ごと無い | — | **出ていない。** §4 で止まった場所を探す |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
