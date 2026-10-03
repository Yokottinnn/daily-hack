# 相互フォローのそっと外す（mutual-prune）は動いているか（2026-10-03 23:02 JST・$0）

**このレポートが作られた時刻: 2026-10-03 23:02:40 JST**

> **外さない。フォローしない。設定を変えない（$0／回・$0／日・$0／月）。**

## ① launchd

```
  載っている  state=running runs=2 last_exit=
      "ABS_MIN" => "300"
      "GRACE_DAYS" => "14"
      "INACTIVE_DAYS" => "30"
      "MAX_UNFOLLOW" => "8"
      "RATIO" => "0.20"
        "Hour" => 6
        "Minute" => 0
        "Hour" => 18
        "Minute" => 0
  本体: 在る（314 行）
```

## ② 実行ごとの結果（直近 14 回）

```
  ログ: 344884 bytes・更新 10/03 05:13

  [2026-09-18T20:14:10.083Z] === mutual-prune done: 1 件 外した ===
  [2026-09-19T16:18:08.179Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-20T20:03:07.488Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-20T20:12:02.730Z] 見たプロフィール: 125 件 / **外す候補: 2 件**
  [2026-09-20T20:12:10.065Z] === mutual-prune done: 0 件 外した ===
  [2026-09-21T20:03:15.737Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-21T20:11:48.745Z] 見たプロフィール: 118 件 / **外す候補: 1 件**
  [2026-09-21T20:12:00.910Z] === mutual-prune done: 1 件 外した ===
  [2026-09-22T20:03:18.484Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-22T20:11:20.979Z] 見たプロフィール: 95 件 / **外す候補: 0 件**
  [2026-09-22T20:11:21.006Z] === mutual-prune done: 0 件 外した ===
  [2026-09-23T20:03:06.815Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-24T20:03:08.492Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-24T20:12:34.109Z] 見たプロフィール: 135 件 / **外す候補: 0 件**
  [2026-09-24T20:12:34.124Z] === mutual-prune done: 0 件 外した ===
  [2026-09-25T20:02:20.206Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-25T20:11:50.095Z] 見たプロフィール: 135 件 / **外す候補: 0 件**
  [2026-09-25T20:11:50.316Z] === mutual-prune done: 0 件 外した ===
  [2026-09-26T20:02:21.832Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-26T20:11:44.785Z] 見たプロフィール: 135 件 / **外す候補: 2 件**
  [2026-09-26T20:11:52.144Z] === mutual-prune done: 0 件 外した ===
  [2026-09-27T20:03:07.707Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-27T20:13:13.374Z] 見たプロフィール: 144 件 / **外す候補: 0 件**
  [2026-09-27T20:13:13.407Z] === mutual-prune done: 0 件 外した ===
  [2026-09-28T20:03:16.919Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-28T20:12:39.920Z] 見たプロフィール: 131 件 / **外す候補: 0 件**
  [2026-09-28T20:12:40.004Z] === mutual-prune done: 0 件 外した ===
  [2026-09-29T20:03:28.950Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-29T20:15:01.160Z] 見たプロフィール: 148 件 / **外す候補: 1 件**
  [2026-09-29T20:15:04.956Z] === mutual-prune done: 0 件 外した ===
  [2026-09-30T20:03:37.587Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-30T21:00:03.232Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-30T21:10:32.855Z] 見たプロフィール: 153 件 / **外す候補: 4 件**
  [2026-09-30T21:10:47.473Z] === mutual-prune done: 0 件 外した ===
  [2026-10-01T20:02:19.900Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-10-01T20:13:09.204Z] 見たプロフィール: 156 件 / **外す候補: 6 件**
  [2026-10-01T20:13:31.249Z] === mutual-prune done: 0 件 外した ===
  [2026-10-02T20:03:09.238Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-10-02T20:13:20.811Z] 見たプロフィール: 146 件 / **外す候補: 7 件**
  [2026-10-02T20:13:46.803Z] === mutual-prune done: 0 件 外した ===
```

## ③ 外した記録（mutual-prune-state.json）

```
  合計 11 件
  2026-09-14  6 件
  2026-09-16  3 件
  2026-09-19  1 件
  2026-09-22  1 件

  理由の内訳:
    11 件  休眠 N 日
```

## ④ いま外せそうな相互（DRY_RUN・外さない）

```
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x222-mutual-prune-health.sh: line 41: 16068 Terminated: 15          "$@" > "$outf" 2>&1
  rc=124 / かかった秒数 275
  （4 分で打ち切った。ここまでの判定を出す）

  [2026-10-03T14:02:41.673Z] === mutual-prune start (dry=true max=20 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-10-03T14:03:53.595Z] 相互フォロー: 183 件

  外す候補（✂ や「外す」の行）: 0 件
```

**外していない。フォローしていない。設定を変えていない（$0／回・$0／日・$0／月）。**
