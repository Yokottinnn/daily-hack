# 詰まりを実測する ＋ ポーラー自体も見張る

**このレポートが作られた時刻: 2026-09-13 03:09:12 JST**

## 1. いま詰まっているか（**実測**）

```
  --- 走っている ops 系プロセス ---
    28676       00:06 /bin/bash /var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-run-tasks-latest.sh
    28938       00:00 /bin/bash /var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-run-tasks-latest.sh
    28939       00:00 /bin/bash /var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x49-unjam-and-watch-poller.sh
    28950       00:00 /bin/bash /var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x49-unjam-and-watch-poller.sh
    28951       00:00 /bin/bash /var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x49-unjam-and-watch-poller.sh
    28952       00:00 /bin/bash /var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x49-unjam-and-watch-poller.sh

  --- ロックらしきもの ---

  --- 取り出されたタスクの一時ファイル（新しい順 8 件） ---
    total 832
    -rw-r--r--  1 ny  staff   8965 Sep 13 03:09 x49-unjam-and-watch-poller.sh
    -rw-r--r--  1 ny  staff  13463 Sep 13 03:09 x48-calendar-and-nosleep.sh
    -rw-r--r--  1 ny  staff  17845 Sep 13 03:02 x47-daily-supervisor.sh
    -rw-r--r--  1 ny  staff  25657 Sep 13 03:02 x46-install-mutual-prune.sh
    -rw-r--r--  1 ny  staff  20785 Sep 13 02:34 x44-teach-the-model-what-is-banned.sh
    -rw-r--r--  1 ny  staff  15529 Sep 13 02:30 x43-repair-v2-heredoc.sh
    -rw-r--r--  1 ny  staff  12021 Sep 13 02:14 x41-repair-instead-of-discard.sh
    -rw-r--r--  1 ny  staff  12023 Sep 13 01:41 x40-post-now-and-name-the-unloader.sh
```

## 2. ポーラーは生きているか（**いちばん上流**）

**ポーラーが止まっていたら、タスクは 1 件も届かない。**
いちばん上流なのに、いままで誰も見ていなかった。

```
  com.dailyhack.ops-poller           ロード済み
  com.dailyhack.ops-heartbeat        ロード済み
  com.dailyhack.rc-keeper            ロード済み
  ai.openclaw.daily-supervisor       ロード済み
  ai.openclaw.caffeinate             ロード済み
  ai.openclaw.mutual-prune           plist 無し
```

## 3. 番人の監視対象に `com.dailyhack.*` を足す

番人は `ai.openclaw.*` の 9 本しか見ていなかった。
**タスクを運ぶポーラーが死んだら、番人の指示も届かない。**

```
  bash -n: OK
  --- 入った所 ---
    35:JOBS_UPSTREAM="com.dailyhack.ops-poller com.dailyhack.ops-heartbeat"
    90:  for u in $JOBS_UPSTREAM; do
    98:  [ "$m" -gt 0 ] && { fixed="$fixed upstream:$m"; log "  上流 ${m} 本を載せ直した"; }
```

## 4. 番人をその場で 1 回 走らせる

**追い上げで `comment-warmup` が走ると返信の生成が起きる（最大 4 件・$0.012）。**
他は LLM を呼ばないので $0。

```
  番人がまだ置かれていない。
```

### `status.json`

```json
  {
    "generated_at": "2026-09-12T18:05:57Z",
    "date_jst": "2026-09-13",
    "cdp_healthy": true,
    "login_lock": false,
    "fixed": "",
    "not_run": "mutual-prune",
    "jobs": [{"job":"comment-warmup","loaded":true,"ran_today":true,"attempts":1,"needs_cdp":true},{"job":"competitor-follower-follow","loaded":true,"ran_today":true,"attempts":1,"needs_cdp":true},{"job":"hashtag-follow","loaded":true,"ran_today":true,"attempts":1,"needs_cdp":true},{"job":"badge-followback","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":true},{"job":"reply-followback-check","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":true},{"job":"reply-followers-cleanup","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":true},{"job":"mutual-prune","loaded":false,"ran_today":false,"attempts":0,"needs_cdp":true},{"job":"incoming-reply-watcher","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":false},{"job":"pipeline-heartbeat","loaded":true,"ran_today":true,"attempts":1,"needs_cdp":false}]
  }
```

## 5. 費用

| | 金額 |
| --- | --- |
| 詰まりの実測・ポーラーの監視追加 | **$0**（LLM 不使用） |
| 番人の追い上げ（`comment-warmup` を走らせた時のみ） | 1 回 最大 $0.012 ／ 1 日 最大 $0.024 ／ 1 か月 最大 $0.72 |
| 定時の返信ループ（**推定**） | 1 回 $0.003 ／ 1 日 約 $0.19 ／ 1 か月 約 $5.8 |

推定の前提: Haiku 4.5・通過率 25%・生成 64 回/日。
追い上げの額は「定時が走らなかった日」だけ発生する上限で、実績ではない。
