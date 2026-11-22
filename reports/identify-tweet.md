# `2103379894306750770` は何者か（2026-09-25 22:23 JST・$0）

**このレポートが作られた時刻: 2026-09-25 22:23:08 JST**

> **読むだけ。消していない。直していない。**
> 消すかどうかは利用者が決める。勝手に消すと何が起きたか分からなくなる。

## 1. 投稿の実物（**一次情報**）

cookie を送らない公開エンドポイントで取る。**ログイン状態に左右されない。**

```
  HTTP 200   768 bytes
```

### 本文（**改行も含めてそのまま。1 文字も直していない**）

```
    1 | シも今年は結局満額いったわ😉
  
    文字数: 14   X の重み: 28 / 280
```

### そのほか

```
    投稿時刻            2026-09-25T07:03:40.000Z
    画像              0 枚
    動画              なし
    親               （なし＝スレッドの返信ではない）
    引用              （なし）
    リンク             （なし）
    いいね             0
    会話id            0
```

## 2. どのジョブが出したか（**id で引く**）

キューとログの両方を id で引く。**当たった行がどのファイルに在るかが答え。**

```
  post_queue.json                            1 行  更新 09-25 22:05
  comment-warmup.log                         1 行  更新 09-25 22:05
```

当たった行（**前後 2 行。秘密とハンドルは伏せる**）:

```
  ===== post_queue.json =====
    20269-      "status": "posted",
    20270-      "created_at": "2026-09-25T07:03:28.652Z",
    20271:      "x_tweet_id": "2103379894306750770",
    20272-      "posted_at": "2026-09-25T07:03:42.814Z",
    20273-      "published_via": "auto-reply-no-approval"

  ===== comment-warmup.log =====
    7655-[2026-09-25T16:03:28]   → chosen template_id: unknown
    7656-[2026-09-25T16:03:28] enqueue: {"ok":true,"id":"comment-20260925-1603-2"}
    7657:{"ok":true,"entry_id":"comment-20260925-1603-2","x_tweet_id":"2103379894306750770","url":"https://x.com/heng_ji31590/status/2103379894306750770","slack_report_ts":"silenced"}
    7658-[2026-09-25T16:03:46]   follow @<伏せ>: already_following
    7659-[2026-09-25T16:03:46] --- processing #4/6 for @<伏せ> ---

```

## 3. その時刻に動いていたジョブ

id で当たらなかったときの手がかり。**投稿時刻の前後に書き込みが在るログ**を出す。

```
  badge-followback.log                     更新 09-25 00:51  (36057 bytes)
  comment-orchestrator.log                 更新 09-25 22:05  (515437 bytes)
  comment-warmup-err.log                   更新 09-25 22:05  (244538 bytes)
  comment-warmup.log                       更新 09-25 22:05  (673722 bytes)
  competitor-follower-follow.log           更新 09-25 18:47  (391481 bytes)
  daily-supervisor.log                     更新 09-25 17:00  (18724 bytes)
  ensure-x-login.log                       更新 09-25 20:00  (379339 bytes)
  follower-snapshot.log                    更新 09-25 00:35  (20792 bytes)
  hashtag-follow.log                       更新 09-25 17:03  (139836 bytes)
  incoming-reply-watcher.log               更新 09-25 22:14  (1402670 bytes)
  mutual-prune.log                         更新 09-25 05:12  (187862 bytes)
  ops-heartbeat-err.log                    更新 09-25 22:14  (149870 bytes)
  ops-heartbeat.log                        更新 09-25 22:14  (95685 bytes)
  pipeline-heartbeat-err.log               更新 09-25 20:00  (3363 bytes)
  pipeline-heartbeat.log                   更新 09-25 20:00  (109014 bytes)
  reply-followback-check.log               更新 09-25 13:15  (88656 bytes)
  reply-followers-cleanup.log              更新 09-25 05:02  (17547213 bytes)
  x-impressions.log                        更新 09-25 20:59  (3120 bytes)
  x-loop-guardian.log                      更新 09-25 22:14  (92989 bytes)
```

## 4. 承認を通ったか

**通っていないなら、それ自体が事故。** 8/15 に同じことが起きている。

```
  post_queue.json                     1037192 bytes  更新 09-25 22:05
```

---

## 読み方

| §1 の本文 | 意味 |
| --- | --- |
| 途中で切れている | **重み 280 の超過か、生成側の打ち切り。** §2 でどちらか分かる |
| プレースホルダが残っている | **テンプレの埋め込みが失敗**。生成側の不具合 |
| 文としては通っている | 文面の質の問題。**スキルの §6 に指摘を写す話**になる |
| HTTP 404 | **もう消えている**（利用者が消したか、X が消したか） |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
