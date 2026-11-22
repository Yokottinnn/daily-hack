# 出したエントリを posted に直す（2026-09-06 17:13 JST・費用 $0）

> `t051` で **[1/2] と [2/2] の両方 出た**のに、キューは `pending` のまま。
> `run-publish.sh` は成功してもエントリに書き戻さない。
> **このままだと次のタスクが「まだ出ていない」と誤認して、もう一度 出す。**

## 書き換え

```
  前: status=pending / x_tweet_id=null
  後: status=posted / x_tweet_id=2096230281909006590
  chain[0]=2096230281909006590
  chain[1]=2096230358161482222
```

## 確認

```json
{
 "id": "blog-promo-20260905-morning-500-2026",
 "status": "posted",
 "x_tweet_id": "2096230281909006590",
 "posted_at": "2026-09-06T08:13:35.993Z",
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "tweet_id": "2096230281909006590",
   "posted": true
  },
  {
   "n": 2,
   "role": "cta",
   "tweet_id": "2096230358161482222",
   "posted": true
  }
 ]
}
```

## 同じ記事の重複エントリが無いか

```
  blog-promo-20260905-morning-500-2026  status=posted  tweet=2096230281909006590
```

---

**投稿していない。削除していない。LLM も呼んでいない（$0）。**
