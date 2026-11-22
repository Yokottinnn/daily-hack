# フォロー・アンフォロー・返信の今日（2026-09-06 17:14 JST・費用 $0）

> **ロードされていても「動いている」証拠にならない。**
> 判定に使えるのは「いつ・何件 やったか」だけ。**何も触らずに数える。**

## 0. 3 系統のジョブはロードされているか

```
  ロード      competitor-follower-follow             PID=-        最後のrc=0
  ロード      hashtag-follow                         PID=-        最後のrc=0
  ロード      reply-followback-check                 PID=-        最後のrc=0
  ロード      auto-detect-and-unfollow-inactive      PID=-        最後のrc=0
  ロード      badge-followback                       PID=-        最後のrc=0
  **未ロード** comment-warmup                        
  **未ロード** incoming-reply-watcher                
  **未ロード** quick-reply-watcher                   
```

**最後の rc が 0 以外なら失敗している。** `-` は「まだ一度も走っていない」。

## 1. フォローの日別実績（直近 7 日）

```
  [competitor-follower-follow.log] 最終更新 2026-09-06 11:47
    [2026-08-29T09:36:40.174Z] === end: 0/10 OK ===
    [2026-09-01T02:35:52.168Z] === end: 1/10 OK ===
    [2026-09-01T09:35:52.027Z] === end: 1/10 OK ===
    [2026-09-02T02:35:52.090Z] === end: 0/10 OK ===
    [2026-09-02T09:35:50.372Z] === end: 1/10 OK ===
    [2026-09-03T02:35:58.779Z] === end: 0/10 OK ===
    [2026-09-03T09:35:59.073Z] === end: 0/10 OK ===
    [2026-09-04T02:35:59.367Z] === end: 0/10 OK ===
    [2026-09-04T09:35:58.455Z] === end: 1/10 OK ===
    [2026-09-05T02:35:49.558Z] === end: 0/10 OK ===
    [2026-09-05T09:14:58.505Z] === end: 4/30 OK ===
    [2026-09-05T09:46:46.179Z] === end: 0/30 OK ===
    [2026-09-05T10:10:10.935Z] === end: 1/30 OK ===
    [2026-09-06T02:47:00.195Z] === end: 7/30 OK ===

  [hashtag-follow.log] 最終更新 2026-09-06 17:06
    [2026-09-01T01:19:44.655Z] === end: 0/3 OK ===
    [2026-09-01T08:04:07.605Z] === end: 0/2 OK ===
    [2026-09-02T01:20:16.933Z] === end: 0/4 OK ===
    [2026-09-02T08:04:44.511Z] === end: 0/3 OK ===
    [2026-09-03T01:19:44.632Z] === end: 0/3 OK ===
    [2026-09-03T08:06:57.023Z] === end: 1/7 OK ===
    [2026-09-04T01:19:44.031Z] === end: 0/3 OK ===
    [2026-09-04T08:05:16.994Z] === end: 0/4 OK ===
    [2026-09-05T01:20:52.170Z] === end: 1/5 OK ===
    [2026-09-05T08:04:45.833Z] === end: 1/3 OK ===
    [2026-09-05T09:01:44.089Z] === end: 1/1 OK ===
    [2026-09-05T09:56:58.921Z] === end: 0/1 OK ===
    [2026-09-06T01:20:19.350Z] === end: 1/4 OK ===
    [2026-09-06T08:06:59.113Z] === end: 2/7 OK ===

```

**`N/M OK` の N が実際にフォローした数。** 0 が続いていれば供給が詰まっている。

### 今日 弾いた理由の内訳

```
  [competitor-follower-follow.log]
       6 ❌ refollow blacklist (manually unfollowed
       2 ❌ random-looking handle (likely throwaway
       2 ❌ follower count out of range (4, need 10
       2 ❌ follower count out of range (0, need 10
       1 ❌ off-niche bio (ダイエット/オタ�
       1 ❌ low-density bio (空 or テンプレキ
       1 ❌ inactive (last post 93d ago)
       1 ❌ inactive (last post 792d ago)
       1 ❌ inactive (last post 566d ago)
       1 ❌ inactive (last post 231d ago)

  [hashtag-follow.log]
       2 ❌ random-looking handle (likely throwaway
       2 ❌ low-density bio (空 or テンプレキ
       1 ❌ off-niche bio (ダイエット/オタ�
       1 ❌ inactive (last post 770d ago)
       1 ❌ follower count out of range (103000, ne
       1 ❌ Phase 1: no mutual-intent keyword & rat

```

### 今日 通ったもの

```
  competitor-follower-follow.log     13 件
  hashtag-follow.log                 3 件
```

## 2. アンフォローの実績

本体は **`reply-followback-check.js`**（24 時間後にフォロバを判定し、
無ければ 7〜14 日後にアンフォローを予約する）。**状態の内訳がそのまま実績になる。**

```
  総数: 303 件
    no          207 件
    revenge_ghost_already_unfollowed48 件
    pending     17 件
    unfollowed  16 件
    yes         14 件
    yes_late    1 件
  アンフォロー予約あり: 207 件（うち期限到来: 196 件）
  **期限が来ているのに残っている＝外す側が動いていない疑い**
  followed_at の日別（直近 7 日）:
    2026-09-06  10 件
    2026-09-05  8 件
    2026-09-04  1 件
    2026-09-03  1 件
    2026-09-02  1 件
    2026-09-01  3 件
    2026-08-31  1 件
```

### アンフォロー系ログの最終更新

```
  auto-detect-and-unfollow-inactive      2026-09-05 22:30  (279 行)
  reply-followback-check                 2026-09-06 13:15  (820 行)
  badge-followback                       2026-09-06 00:51  (315 行)
  unfollow-cleanup-evening               2026-08-06 20:30  (13 行)
  unfollow-daily                         2026-08-10 09:00  (234 行)
  revenge-unfollow                       2026-08-09 13:00  (101 行)
```

**数日 更新が無いものは、回っていない。**

## 3. 返信の実績

```
  comment-warmup                 最終更新 2026-09-02 12:03
  comment-orchestrator           最終更新 2026-09-02 12:03
  incoming-reply-watcher         最終更新 2026-08-30 23:55
  quick-reply-watcher            最終更新 2026-08-15 19:28
```

### キューに積まれた返信の状態

```
  comment / reply のエントリ: 908 件
    posted            848 件
    skipped           32 件
    awaiting_approval 15 件
    cancelled_stale   6 件
    skipped_consecutive_errors3 件
    pending           3 件
    cancelled_redundant1 件
  日別（直近 7 日）:
    2026-09-02  2 件
    2026-09-01  8 件
    2026-08-31  6 件
    2026-08-30  7 件
    2026-08-29  6 件
    2026-08-28  8 件
    2026-08-27  8 件
```

## 4. フォロワー数の推移

```
```

---

**何も触っていない。フォローも アンフォローも 返信も 投稿もしていない（$0）。**
