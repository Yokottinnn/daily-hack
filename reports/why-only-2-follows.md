# 枠 120 件/日 に対して 2 件 しか出ていない理由（2026-09-29 00:45 JST・$0）

**このレポートが作られた時刻: 2026-09-29 00:45:46 JST**

> **測るだけ。フォローしない。枠もフィルタも変えない。ブラウザも触らない。**
> **LLM を呼ばない（$0／回・$0／日・$0／月）。**

いま余っているのは**アンフォロー枠ではなくフォロー枠**。
実数 **173 / 296**、比率の上限は **192** なので **あと 19 件** フォローできる。

## 1. 実際にフォローした数（**一次情報**）

`data/followed.json` の日付。**ログの件数ではない**（最上位ルール 11）。

```
  記録 全体: 2 件（日時が無い/読めない: 2 件）

  **日付つきの記録が 1 件も無い**
```

## 2. ジョブは載っているか（**`list | grep` では足りない**）

```
  ai.openclaw.competitor-follower-follow
      	state = not running
      	runs = 6
      	last exit code = 0
      		state = active
      		state = active
      → **載っている**
  ai.openclaw.hashtag-follow
      	state = not running
      	runs = 6
      	last exit code = 0
      		state = active
      		state = active
      → **載っている**
```

## 3. いつ撃つか・枠とフィルタ（**設定の実物**）

```
  === competitor-follower-follow ===
    --- 起動時刻 ---
              Hour = 11
              Minute = 30
              Hour = 18
              Minute = 30
    --- 環境変数（**秘密は伏せる**）---
          COMPETITOR_FOLLOW_DAILY_CAP = 30
          PATH = /usr/local/bin:/usr/bin:/bin
          FORCE_RUN = 1

  === hashtag-follow ===
    --- 起動時刻 ---
              Hour = 10
              Minute = 15
              Hour = 17
              Minute = 0
    --- 環境変数（**秘密は伏せる**）---
          HASHTAG_FOLLOW_DAILY_CAP = 90
          PATH = /usr/local/bin:/usr/bin:/bin
          FORCE_RUN = 1

```

## 4. ファネル: 発火 → 集めた → 試した → 通った

**どこで減っているかで打つ手が変わる。**

### 4-A. 競合フォロワー刈り取り（枠 30/日）

```
    更新 09-28 18:47 / 436565 bytes

    日付       発火   SKIP 集めた 試した 通った
    2026-09-19        0      0       0     60      8
    2026-09-20        0      0       0    180     18
    2026-09-21        0      0       0    180     22
    2026-09-22        0      0       0    180     14
    2026-09-23        0      0       0    180     10
    2026-09-24        0      0       0    180     10
    2026-09-25        0      0       0    180     20
    2026-09-26        0      0       0    180     16
    2026-09-27        0      0       0    180     16
    2026-09-28        0      0       0    120      8

    --- 弾かれた理由（上位 10）---
      1329 follower count out of range
       661 inactive
       602 no follow button
       367 random-looking handle
       321 low-density bio
       206 refollow blacklist
       194 off-niche bio
       155 Phase 2: no relevant topic in bio
        50 follow button click didn't change to unfollow
        24 Phase 1: no mutual-intent keyword & ratio mismatch
```

### 4-B. ハッシュタグ（枠 90/日）

```
    更新 09-28 17:03 / 149501 bytes

    日付       発火   SKIP 集めた 試した 通った
    2026-09-19        4      0       6      6      0
    2026-09-20        6      0      14     14      2
    2026-09-21        6      0      10     10      2
    2026-09-22        6      0      14     14      0
    2026-09-23        6      0      10     10      0
    2026-09-24        6      0      10     10      4
    2026-09-25        6      0      22     22      4
    2026-09-26        6      0      26     26      0
    2026-09-27        6      0      14     14      2
    2026-09-28        4      0      12     12      2

    --- 弾かれた理由（上位 10）---
       178 follower count out of range
        62 inactive
        33 random-looking handle
        28 exec err: Command failed: /usr/local/bin/node /Users/ny/.ope
        27 low-density bio
        26 off-niche bio
        14 no follow button
        12 Phase 2: no relevant topic in bio
         7 Phase 1: no mutual-intent keyword & ratio mismatch
         6 follower>>following exclusion: ratio=0.11
```

## 5. 候補の在庫（**集まっているのか**）

```

  --- data/ に在る follow 関連（参考）---
    badge-followback-state.json
    follow-balance-lists.json
    follow-balance-notfollowing.json
    follow-balance-state.json
    follow-watchdog-state.json
    followed.json
    follower-daily-report-state.json
    follower-history.json
    follower-snapshots
    follower-target-config.json
    follower-target-config.json.bak
    following-snapshots
    post_queue.json.bak.20260515-hashtag-reduce
    refollow-blacklist.json
    refollow-may18-done.flag
    reply-followers.json
    reply-followers.json.bak-20260913-194151
    reply-followers.json.bak-20260913-194413
    reply-followers.json.bak-20260915-020121
    unfollow-cleanup-state.json
```

---

## 読み方（**A / B / C で打つ手が全く違う**）

| §4 の出方 | どれか | 次にやること |
| --- | --- | --- |
| **集めた**が小さい（0〜数件） | **A. 候補が来ていない** | タグ・シードの供給を直す。**枠を上げても無駄** |
| **試した**は多いが**通った**が小さい | **B. フィルタが厳しい** | §4 の理由の内訳を見て、効いている条件だけ緩める |
| **発火**が 0 | **C. 撃っていない** | §2 の `載っている` と §3 の起動時刻を見る |
| §1 の平均が §4 の`通った`と合わない | **記録か集計のどちらかが嘘** | `followed.json` を正とする（ルール 11）|

**どれであっても、フォローを増やすときは比率の上限 192 件 を超えない**（最上位ルール 19）。
いまの余地は **19 件**。それ以上 増やすならフォロワーが増えるのが先。

**フォローしていない。設定も変えていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
