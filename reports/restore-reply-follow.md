# 返信・フォローの 3 件を戻す（2026-08-31 01:36:11 JST）

> **原因は未特定。だから 3 件だけ戻す。** 投稿系は止めたままにする
> （再開直後にまとめて出る事故が 2026-08-15 に起きている）。

## 1. 戻す前の状態

- `ai.openclaw.comment-warmup`: ロード=**0** 件 / plist=あり
- `ai.openclaw.competitor-follower-follow`: ロード=**0** 件 / plist=あり
- `ai.openclaw.hashtag-follow`: ロード=**0** 件 / plist=あり

## 2. 積まれたまま待っているものを数える（**戻す前に**）

| status | 件数 |
| --- | --- |
| `awaiting_approval` | 16 |
| `cancelled` | 12 |
| `cancelled_no_blog_link` | 1 |
| `cancelled_redundant` | 1 |
| `cancelled_stale` | 23 |
| `cancelled_stale_audit_20260627` | 22 |
| `deleted_by_user_request` | 1 |
| `deleted_low_eng` | 9 |
| `dm_sent` | 1 |
| `pending` | 3 |
| `posted` | 870 |
| `posted_pre_queue` | 2 |
| `skipped` | 36 |
| `skipped_aged` | 1 |
| `skipped_consecutive_errors` | 12 |
| `skipped_expired_ttl_7d` | 27 |
| `skipped_stale` | 10 |
| `skipped_text_too_long` | 1 |

## 3. comment-warmup の返信量を確かめる（**2 を超えていたら戻さない**）

- `MAX_PICKS_PER_FIRE`: **2**
- 起動間隔: StartInterval=**** / Calendar=[{"Hour":16,"Minute":0},{"Hour":12,"Minute":0},{"Hour":22,"Minute":0},{"Hour":19,"Minute":0}]

## 4. 戻す

> **plist は読むだけ。書き換えない。** 壊れているものは飛ばす。
- `ai.openclaw.comment-warmup`: **ロード成功**
- `ai.openclaw.competitor-follower-follow`: **ロード成功**
- `ai.openclaw.hashtag-follow`: **ロード成功**

## 5. 戻したあとの状態

- `ai.openclaw.comment-warmup`: ロード=**1** 件
- `ai.openclaw.competitor-follower-follow`: ロード=**1** 件
- `ai.openclaw.hashtag-follow`: ロード=**1** 件

### いま載っているもの（全体）
```
PID	Status	Label
58790	0	com.dailyhack.ops-poller
-	0	com.dailyhack.rc-keeper
-	0	ai.openclaw.comment-warmup
53365	1	ai.openclaw.tab-guard
-	0	com.dailyhack.openclaw.heartbeat
850	0	com.dailyhack.openclaw.listener
-	0	com.dailyhack.ops-heartbeat
-	0	ai.openclaw.competitor-follower-follow
-	0	com.dailyhack.weekly-blog-report
-	0	ai.openclaw.hashtag-follow
```

## 6. まだ戻していないもの

**投稿系はわざと止めたままにしている。** 再開直後にまとめて出る事故を避けるため。
```
未ロード: ai.openclaw.auto-detect-and-unfollow-inactive
未ロード: ai.openclaw.auto-thread-chainifier
未ロード: ai.openclaw.badge-followback
未ロード: ai.openclaw.blog-rss-watcher
未ロード: ai.openclaw.bookmark-analyzer
未ロード: ai.openclaw.bookmark-watcher
未ロード: ai.openclaw.canary-silent-gap
未ロード: ai.openclaw.celebrate-100
未ロード: ai.openclaw.chrome-cdp-heal
未ロード: ai.openclaw.chrome-cdp
未ロード: ai.openclaw.chrome-restart-hook
未ロード: ai.openclaw.cookie-backup
未ロード: ai.openclaw.cost-monitor-health
未ロード: ai.openclaw.cost-monitor
未ロード: ai.openclaw.cost-report-daily
未ロード: ai.openclaw.crd-detect-daemon
未ロード: ai.openclaw.daily-action-norm
未ロード: ai.openclaw.daily-follow-summary
未ロード: ai.openclaw.daily-must-rule-review
未ロード: ai.openclaw.daily-task-audit
未ロード: ai.openclaw.draft-eve
未ロード: ai.openclaw.draft-late
未ロード: ai.openclaw.draft-noon
未ロード: ai.openclaw.engage-daily
未ロード: ai.openclaw.fire-watchdog
未ロード: ai.openclaw.follow-watchdog
未ロード: ai.openclaw.follower-daily-report
未ロード: ai.openclaw.follower-monitor
未ロード: ai.openclaw.follower-snapshot
未ロード: ai.openclaw.gateway
```

**費用**: `comment-warmup` 8 件/日 × $0.00417（実測）= $0.033/日 = **$1.00/月**。
フォロー 2 件は LLM を呼ばないので **$0**。**止まる前の水準に戻すだけで、増額ではない。**
