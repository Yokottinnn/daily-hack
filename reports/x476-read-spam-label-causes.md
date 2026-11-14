# スパムのラベルの原因を読む（2026-11-14 19:11:51 JST・読むだけ・$0）

## 1〜4. ログから数えた操作

### 1. 日ごと（JST）
```
日付        follow  unfollow  reply  like  post
2026-11-06       3         0      0     0     0
2026-11-07      25        20      1     0     0
2026-11-08      37        25      1     0     0
2026-11-09      10         0      0     0     0
2026-11-10      17        37      0     0     0
2026-11-11      24        14      0     0     0
2026-11-12      24        23      0     0     0
2026-11-13      29        21      0     0     0
2026-11-14      15         1      1     0     0
2026-11-15       2         0      0     0     0
```

### 2. ジョブごと（8 日の合計）
```
follow-balance: unfollow=130
badge-followback: follow=73
comment-orchestrator: follow=36
comment-warmup: follow=36
competitor-follower-follow: follow=28 unfollow=2
incoming-reply-watcher: follow=13 reply=3
mutual-prune: unfollow=6
reply-followers-cleanup: unfollow=3
```

### 3. 30 分あたりの最大（種類ごと・その時刻 JST）と、前の回との間隔の最小
```
follow: 30分で最大 8 回（11-12 11:30）／最小の間隔 0 秒／8日で 186 回
unfollow: 30分で最大 7 回（11-08 11:55）／最小の間隔 119 秒／8日で 141 回
reply: 30分で最大 1 回（11-07 16:07）／最小の間隔 112260 秒／8日で 3 回
like: 30分で最大 0 回（-）／最小の間隔 -／8日で 0 回
follow+unfollow: 30分で最大 14 回（11-12 11:30）
```

### 4. 時刻（JST）ごとの操作の数（8 日の合計）
```
 0時 ############### 30
 1時 ###### 11
 2時 # 1
 3時  0
 4時 ###### 12
 5時 ##### 9
 6時 # 1
 7時 ####### 14
 8時 ############ 23
 9時 # 1
10時 # 1
11時 ############################ 55
12時 ############################ 55
13時 ### 5
14時 #### 8
15時 ########### 22
16時 ############### 30
17時 #### 8
18時 # 2
19時 ##### 9
20時 ######### 17
21時 ###### 12
22時  0
23時 ## 4
```

## 5. いま載っている X のジョブ（launchctl list の ai.openclaw.*）
```
ai.openclaw.badge-followback pid=- last=0
ai.openclaw.boost-watch pid=- last=0
ai.openclaw.caffeinate pid=44638 last=0
ai.openclaw.comment-warmup pid=- last=5
ai.openclaw.competitor-follower-follow pid=- last=0
ai.openclaw.daily-supervisor pid=- last=0
ai.openclaw.follow-balance pid=- last=0
ai.openclaw.follower-snapshot pid=- last=0
ai.openclaw.hashtag-follow pid=- last=0
ai.openclaw.incoming-reply-watcher pid=- last=0
ai.openclaw.mutual-prune pid=3033 last=1
ai.openclaw.pipeline-heartbeat pid=- last=0
ai.openclaw.reply-followback-check pid=- last=0
ai.openclaw.reply-followers-cleanup pid=- last=0
ai.openclaw.tab-guard pid=44034 last=1
ai.openclaw.x-loop-guardian pid=- last=0
```

## 6. 鍵（認証）以外で、X から返っている警告（直近 8 日のログ）
```
[2026-11-11T00:55:46.018Z]     ✅ posted: https://x.com/heng_ji31590/status/2120319527582142969
[2026-11-06T21:02:06.429Z]   @<伏せ>: フォロー中のボタンが無い（既に外れている可能性）
[2026-11-10T21:59:52.429Z]   ・ @<伏せ> — 認証済み
[2026-11-10T21:59:52.429Z]   ・ @<伏せ> — 認証済み
[2026-11-10T21:59:52.429Z]   ・ @<伏せ> — 認証済み
[2026-11-10T21:59:52.429Z]   ・ @<伏せ> — 認証済み
[2026-11-10T21:59:52.429Z]   ・ @<伏せ> — 認証済み
[2026-11-10T21:59:52.429Z]   ・ @<伏せ> — 認証済み
[2026-11-10T21:59:52.429Z]   ・ @<伏せ> — 認証済み
[2026-11-10T21:59:52.429Z]   ・ @<伏せ> — 認証済み
[2026-11-11T21:44:41.429Z]   @<伏せ>: ページが空。開き直す
[2026-11-12T21:46:19.429Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
[2026-11-12T21:46:19.429Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
[2026-11-12T21:46:19.429Z]   ・ @<伏せ> — 認証済み
[2026-11-12T21:46:19.429Z]   ・ @<伏せ> — 残す（1060 フォロワー / 2 日前に投稿）
[2026-11-12T21:46:19.429Z]   ・ @<伏せ> — 認証済み
[2026-11-12T21:46:19.429Z]   ・ @<伏せ> — 認証済み
[2026-11-12T21:46:19.429Z]   ・ @<伏せ> — 認証済み
[2026-11-12T21:46:19.429Z]   ・ @<伏せ> — 認証済み
[2026-11-12T21:46:19.429Z]   ・ @<伏せ> — 認証済み
[2026-11-10T10:56:05.429Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-11-10T14:22:15.429Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-11-12T08:22:06.429Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-11-13T12:25:41.429Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
[2026-11-13T00:46:58] unresolved: load-failed:comment-warmup load-failed:reply-followers-cleanup load-failed:incoming-reply-watcher load-failed:pipeline-heartbeat (consecutive=429)
```
