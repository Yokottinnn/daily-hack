# フォロワー増の現在地（2026-09-05 16:29:54 JST・費用 $0）

> **フォローしない。投稿しない。ジョブも触らない。LLM も呼ばない。**
> 手を打つ順番を決めるために、**どの経路が死んでいるか**を先に数字で出す。

## 1. フォロワー数の推移

```
```

## 2. フォロー実績（日別）

**打ち手が実際に出ているか。** 0 が続いていれば、そこが最短の直しどころ。

```
[badge-followback-state.json] 全 3 件 / 日付つき 0 / 更新 2026-08-29 15:50
    （日付つきの記録が無い）

[follow-watchdog-state.json] 全 8 件 / 日付つき 0 / 更新 2026-08-10 00:00
    （日付つきの記録が無い）
    フォロバ確認: 2 件 / 8（25.0%）

[followed.json] 全 2 件 / 日付つき 0 / 更新 2026-08-29 15:50
    （日付つきの記録が無い）
    フォロバ確認: 1 件 / 2（50.0%）

[follower-daily-report-state.json] 全 3 件 / 日付つき 0 / 更新 2026-08-09 23:00
    （日付つきの記録が無い）

[follower-history.json] 全 1 件 / 日付つき 0 / 更新 2026-05-23 15:30
    （日付つきの記録が無い）

[follower-target-config.json] 全 5 件 / 日付つき 0 / 更新 2026-08-22 10:37
    （日付つきの記録が無い）

[refollow-blacklist.json] 全 3 件 / 日付つき 0 / 更新 2026-08-02 11:45
    （日付つきの記録が無い）

[reply-followers.json] 全 286 件 / 日付つき 286 / 更新 2026-09-05 01:19
    2026-09-05  1 件
    2026-09-04  1 件
    2026-09-03  1 件
    2026-09-02  1 件
    2026-09-01  3 件
    2026-08-31  1 件
    2026-08-30  1 件
    2026-08-29  2 件
    2026-08-28  2 件
    2026-08-27  7 件
    2026-08-26  1 件
    2026-08-25  1 件
    2026-08-23  1 件
    2026-08-22  1 件
    フォロバ確認: 286 件 / 286（100.0%）

[unfollow-cleanup-state.json] 全 9 件 / 日付つき 1 / 更新 2026-08-10 00:31
    2026-08-10  1 件

[unfollow-whitelist.json] 全 5 件 / 日付つき 0 / 更新 2026-07-19 14:06
    （日付つきの記録が無い）

[unfollow_batch.json] 全 3 件 / 日付つき 0 / 更新 2026-05-08 16:15
    （日付つきの記録が無い）

```

## 3. 止まっている X 系ジョブ（**戻せば増える候補**）

```
  **停止** ai.openclaw.auto-detect-and-unfollow-inactive   (plist 2026-08-23)
  **停止** ai.openclaw.badge-followback   (plist 2026-08-23)
  **停止** ai.openclaw.comment-warmup   (plist 2026-08-23)
  ロード   ai.openclaw.competitor-follower-follow
  **停止** ai.openclaw.daily-follow-summary   (plist 2026-06-07)
  **停止** ai.openclaw.engage-daily   (plist 2026-05-09)
  **停止** ai.openclaw.follow-watchdog   (plist 2026-08-22)
  **停止** ai.openclaw.follower-daily-report   (plist 2026-07-04)
  **停止** ai.openclaw.follower-monitor   (plist 2026-06-04)
  **停止** ai.openclaw.follower-snapshot   (plist 2026-05-24)
  ロード   ai.openclaw.hashtag-follow
  **停止** ai.openclaw.incoming-reply-responder   (plist 2026-08-22)
  **停止** ai.openclaw.incoming-reply-watcher   (plist 2026-05-17)
  **停止** ai.openclaw.refollow-may18-once   (plist 2026-05-18)
  **停止** ai.openclaw.reply-followback-check   (plist 2026-05-13)
  **停止** ai.openclaw.reply-followers-cleanup   (plist 2026-05-13)
  **停止** ai.openclaw.revenge-unfollow   (plist 2026-08-22)
  **停止** ai.openclaw.unfollow-cleanup-evening   (plist 2026-08-22)
  **停止** ai.openclaw.unfollow-cleanup-morning   (plist 2026-08-22)
  **停止** ai.openclaw.unfollow-daily   (plist 2026-08-22)
  **停止** ai.openclaw.unfollow-evening   (plist 2026-08-22)
  **停止** ai.openclaw.unfollow-stats-monitor   (plist 2026-08-22)
```

## 4. フォロー系ログの末尾（**エラーで死んでいないか**）

### `auto-detect-and-unfollow-inactive-err.log` — 最終更新 **2026-08-23 22:30**

```
```

### `auto-detect-and-unfollow-inactive.log` — 最終更新 **2026-08-30 22:30**

```
 7. americangirl402      → https://x.com/mericangirl402
 8. money_yossy          → https://x.com/oney_yossy
 9. 422200               → https://x.com/22200
10. R80455959            → https://x.com/80455959

⏭️  After noting dates, update followed.json using:
   node update_activity_manual.js

✅ No inactive accounts detected.

```

### `badge-followback.log` — 最終更新 **2026-08-30 00:50**

```
followed back @<伏せ>
[2026-08-28T15:50:42.876Z] followed back @<伏せ>
followed back @<伏せ>
{"ok":true,"scanned":214,"verified":68,"followed_back":2,"handles":["NV_ShogoTakino","xuwhky"]}
[silence-enforce] this script kind=badge-followback-error is silent, slack HTTP calls suppressed
[2026-08-29T15:50:35.898Z] scanned=215 verified=67 new_candidates=1 DRY_RUN=false BASELINE_ONLY=false
scanned=215 verified=67 new_candidates=1 DRY_RUN=false BASELINE_ONLY=false
[2026-08-29T15:50:39.195Z] followed back @<伏せ>
followed back @<伏せ>
{"ok":true,"scanned":215,"verified":67,"followed_back":1,"handles":["oyadani7799"]}
```

### `badge-followback.stderr.log` — 最終更新 **2026-06-08 00:50**

```
```

### `badge-followback.stdout.log` — 最終更新 **2026-06-08 00:50**

```
```

### `competitor-follower-follow-err.log` — 最終更新 **2026-08-23 11:30**

```
```

### `competitor-follower-follow.log` — 最終更新 **2026-09-05 11:35**

```
[2026-09-05T02:33:40.994Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
  @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
[2026-09-05T02:34:13.858Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
  @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
[2026-09-05T02:34:46.696Z]   @<伏せ>: ❌ follower count out of range (1, need 10-10000)
  @<伏せ>: ❌ follower count out of range (1, need 10-10000)
[2026-09-05T02:35:19.548Z]   @<伏せ>: ❌ random-looking handle (likely throwaway/spam): bJCLtICrZA93414
  @<伏せ>: ❌ random-looking handle (likely throwaway/spam): bJCLtICrZA93414
[2026-09-05T02:35:49.558Z] === end: 0/10 OK ===
=== end: 0/10 OK ===
```

### `daily-follow-summary-err.log` — 最終更新 **2026-08-09 23:00**

```
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=daily-follow-summary is silent, slack HTTP calls suppressed
```

### `daily-follow-summary.log` — 最終更新 **2026-08-09 23:00**

```
{"ok":true,"follower":null,"follower_delta":null,"following":null,"today_follows":3,"by_source":{"hashtag-follow":3},"new_followback":0,"revenge":0,"30d":{"total_follow":
{"ok":true,"follower":null,"follower_delta":null,"following":null,"today_follows":3,"by_source":{"hashtag-follow":3},"new_followback":0,"revenge":0,"30d":{"total_follow":
{"ok":true,"follower":null,"follower_delta":null,"following":null,"today_follows":1,"by_source":{"competitor-follower":1},"new_followback":0,"revenge":0,"30d":{"total_fol
{"ok":true,"follower":null,"follower_delta":null,"following":null,"today_follows":0,"by_source":{},"new_followback":0,"revenge":0,"30d":{"total_follow":15,"total_fb":1,"r
{"ok":true,"follower":null,"follower_delta":null,"following":null,"today_follows":0,"by_source":{},"new_followback":0,"revenge":0,"30d":{"total_follow":15,"total_fb":1,"r
{"ok":true,"follower":null,"follower_delta":null,"following":null,"today_follows":0,"by_source":{},"new_followback":0,"revenge":0,"30d":{"total_follow":15,"total_fb":1,"r
{"ok":true,"follower":192,"follower_delta":null,"following":null,"today_follows":0,"by_source":{},"new_followback":0,"revenge":0,"30d":{"total_follow":14,"total_fb":1,"ra
{"ok":true,"follower":195,"follower_delta":3,"following":null,"today_follows":12,"by_source":{"competitor-follower":7,"comment-orchestrator":3,"hashtag-follow":2},"new_fo
{"ok":true,"follower":null,"follower_delta":null,"following":null,"today_follows":0,"by_source":{},"new_followback":0,"revenge":0,"30d":{"total_follow":26,"total_fb":1,"r
{"ok":true,"follower":201,"follower_delta":3,"following":null,"today_follows":6,"by_source":{"comment-orchestrator":5,"incoming-reply-watcher":1},"new_followback":0,"reve
```

### `follow-daily-err.log` — 最終更新 **2026-05-10 14:00**

```
```

### `follow-daily.log` — 最終更新 **2026-06-07 15:13**

```
{"ok":false,"error":"browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://localhost:18800\n  - <ws co
{"ok":true,"phase":1,"followers_count":56,"followed":[],"skipped":33,"target_reached":false}
{"ok":true,"phase":1,"followers_count":59,"followed":[],"skipped":33,"target_reached":false}
{"ok":true,"phase":1,"followers_count":64,"followed":[{"handle":"7cd2y","user_id":"7cd2y","followed_at":"2026-05-28T05:00:57.783Z","keyword":"phase1","followback":false,"
{"ok":true,"phase":1,"followers_count":68,"followed":[{"handle":"16lGH1KUiz28535","user_id":"16lGH1KUiz28535","followed_at":"2026-05-29T05:01:20.721Z","keyword":"phase1",
{"ok":true,"phase":1,"followers_count":71,"followed":[],"skipped":34,"target_reached":false}
{"ok":true,"phase":1,"followers_count":70,"followed":[{"handle":"pon_oya","user_id":"pon_oya","followed_at":"2026-05-31T05:01:01.713Z","keyword":"phase1","followback":fal
{"ok":false,"error":"browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://localhost:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://localhost:18800\n  - <ws co
{"ok":true,"phase":1,"followers_count":82,"followed":[{"handle":"tikuzaiko","user_id":"tikuzaiko","followed_at":"2026-06-07T06:12:32.176Z","keyword":"phase1","followback"
```

### `follow-morning-err.log` — 最終更新 **2026-05-11 08:00**

```
```

### `follow-morning.log` — 最終更新 **2026-06-02 08:00**

```
{"ok":true,"phase":1,"followers_count":0,"followed":[{"handle":"hugkm15","user_id":"hugkm15","followed_at":"2026-05-23T23:00:54.308Z","keyword":"phase1","followback":fals
{"ok":false,"error":"browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://localhost:18800\n  - <ws co
{"ok":true,"phase":1,"followers_count":56,"followed":[{"handle":"AO_flower666","user_id":"AO_flower666","followed_at":"2026-05-25T23:01:30.588Z","keyword":"phase1","follo
{"ok":true,"phase":1,"followers_count":58,"followed":[{"handle":"pecokabu","user_id":"pecokabu","followed_at":"2026-05-26T23:01:19.442Z","keyword":"phase1","followback":f
{"ok":true,"phase":1,"followers_count":59,"followed":[{"handle":"AzDwKqDNSyZPnPf","user_id":"AzDwKqDNSyZPnPf","followed_at":"2026-05-27T23:01:28.782Z","keyword":"phase1",
{"ok":true,"phase":1,"followers_count":67,"followed":[{"handle":"After_All_Lucky","user_id":"After_All_Lucky","followed_at":"2026-05-28T23:02:09.950Z","keyword":"phase1",
{"ok":true,"phase":1,"followers_count":70,"followed":[],"skipped":36,"target_reached":false}
{"ok":true,"phase":1,"followers_count":69,"followed":[],"skipped":18,"target_reached":false}
{"ok":false,"error":"browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://localhost:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://localhost:18800\n  - <ws co
```

### `follow-up-reply.log` — 最終更新 **2026-05-17 02:23**

```
[2026-05-16T16:38:19.179Z] no candidates in 28-35min window
[2026-05-16T16:43:19.278Z] no candidates in 28-35min window
[2026-05-16T16:48:19.382Z] no candidates in 28-35min window
[2026-05-16T16:53:19.497Z] no candidates in 28-35min window
[2026-05-16T16:58:19.605Z] no candidates in 28-35min window
[2026-05-16T17:03:19.708Z] no candidates in 28-35min window
[2026-05-16T17:08:19.814Z] no candidates in 28-35min window
[2026-05-16T17:13:19.919Z] no candidates in 28-35min window
[2026-05-16T17:18:20.015Z] no candidates in 28-35min window
[2026-05-16T17:23:20.106Z] no candidates in 28-35min window
```

### `follow-watchdog-err.log` — 最終更新 **2026-08-06 21:05**

```
  - <ws connected> ws://127.0.0.1:18800/devtools/browser/01b57623-a205-4dca-9035-f3373632eedf

falling back to cached success (4141min old)
trend-detect main failed: browserType.connectOverCDP: Timeout 8000ms exceeded.
Call log:
  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800
  - <ws connecting> ws://127.0.0.1:18800/devtools/browser/01b57623-a205-4dca-9035-f3373632eedf
  - <ws connected> ws://127.0.0.1:18800/devtools/browser/01b57623-a205-4dca-9035-f3373632eedf

falling back to cached success (4861min old)
```

### `follow-watchdog.log` — 最終更新 **2026-08-10 09:00**

```
  },
  "src24": {
    "badge-followback": 2
  },
  "src72": {
    "cron-poikatsu-follow": 19,
    "badge-followback": 6
  },
  "reasons": []
}
```

### `follower-daily-report-err.log` — 最終更新 **2026-08-10 08:00**

```
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
[silence-enforce] this script kind=follower-progress-report is silent, slack HTTP calls suppressed
```

### `follower-daily-report.log` — 最終更新 **2026-08-10 08:00**

```
{"ok":true,"pace_actual":0.9629629629629629,"pace_required":null,"consec_behind":24}
{"ok":true,"pace_actual":0.9642857142857143,"pace_required":null,"consec_behind":25}
{"ok":true,"pace_actual":1.0689655172413792,"pace_required":null,"consec_behind":26}
{"ok":true,"pace_actual":1.0689655172413792,"pace_required":null,"consec_behind":27}
{"ok":true,"pace_actual":1.0689655172413792,"pace_required":null,"consec_behind":28}
{"ok":true,"pace_actual":1.0689655172413792,"pace_required":null,"consec_behind":29}
{"ok":true,"pace_actual":0.9393939393939394,"pace_required":null,"consec_behind":30}
{"ok":true,"pace_actual":1,"pace_required":null,"consec_behind":31}
{"ok":true,"pace_actual":1.0571428571428572,"pace_required":null,"consec_behind":32}
{"ok":true,"pace_actual":1.25,"pace_required":null,"consec_behind":33}
```

### `follower-monitor-err.log` — 最終更新 **2026-06-04 12:30**

```
```

### `follower-monitor.log` — 最終更新 **2026-08-09 12:30**

```
{"ok":true,"timestamp":"2026-07-31T03:30:07.229Z","follower_count":184,"follower_history":[{"date":"2026-07-11","count":0},{"date":"2026-07-12","count":166},{"date":"2026
{"ok":true,"timestamp":"2026-08-01T03:30:05.137Z","follower_count":187,"follower_history":[{"date":"2026-07-12","count":166},{"date":"2026-07-15","count":0},{"date":"2026
{"ok":true,"timestamp":"2026-08-02T03:30:02.134Z","follower_count":188,"follower_history":[{"date":"2026-07-15","count":0},{"date":"2026-07-17","count":0},{"date":"2026-0
{"ok":true,"timestamp":"2026-08-03T03:30:02.263Z","follower_count":192,"follower_history":[{"date":"2026-07-17","count":0},{"date":"2026-07-19","count":180},{"date":"2026
{"ok":true,"timestamp":"2026-08-04T03:30:05.141Z","follower_count":192,"follower_history":[{"date":"2026-07-17","count":0},{"date":"2026-07-19","count":180},{"date":"2026
{"ok":true,"timestamp":"2026-08-05T03:30:02.171Z","follower_count":192,"follower_history":[{"date":"2026-07-17","count":0},{"date":"2026-07-19","count":180},{"date":"2026
{"ok":true,"timestamp":"2026-08-06T03:30:05.130Z","follower_count":192,"follower_history":[{"date":"2026-07-17","count":0},{"date":"2026-07-19","count":180},{"date":"2026
{"ok":true,"timestamp":"2026-08-07T03:30:05.141Z","follower_count":192,"follower_history":[{"date":"2026-07-19","count":180},{"date":"2026-07-20","count":180},{"date":"20
{"ok":true,"timestamp":"2026-08-08T03:30:05.138Z","follower_count":195,"follower_history":[{"date":"2026-07-20","count":180},{"date":"2026-07-25","count":184},{"date":"20
{"ok":true,"timestamp":"2026-08-09T03:30:06.122Z","follower_count":198,"follower_history":[{"date":"2026-07-25","count":184},{"date":"2026-07-31","count":187},{"date":"20
```

### `follower-snapshot.log` — 最終更新 **2026-08-30 00:35**

```
{"ok":true,"today":"2026-08-09","count_today":206,"count_prev":198,"disappeared":2,"new":10,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-08
{"ok":true,"today":"2026-08-21","count_today":207,"count_prev":206,"disappeared":15,"new":16,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-0
{"ok":true,"today":"2026-08-22","count_today":206,"count_prev":207,"disappeared":5,"new":4,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-08-
{"ok":true,"today":"2026-08-23","count_today":208,"count_prev":206,"disappeared":3,"new":5,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-08-
{"ok":true,"today":"2026-08-24","count_today":210,"count_prev":208,"disappeared":3,"new":5,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-08-
{"ok":true,"today":"2026-08-25","count_today":212,"count_prev":210,"disappeared":3,"new":5,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-08-
{"ok":true,"today":"2026-08-26","count_today":211,"count_prev":212,"disappeared":4,"new":3,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-08-
{"ok":true,"today":"2026-08-27","count_today":214,"count_prev":211,"disappeared":4,"new":7,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-08-
{"ok":true,"today":"2026-08-28","count_today":214,"count_prev":214,"disappeared":5,"new":5,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-08-
{"ok":true,"today":"2026-08-29","count_today":215,"count_prev":214,"disappeared":4,"new":5,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-08-
```

### `follower-snapshot.stderr.log` — 最終更新 **2026-06-07 00:35**

```
```

### `follower-snapshot.stdout.log` — 最終更新 **2026-06-07 00:35**

```
```

### `follower-target-monitor-err.log` — 最終更新 **2026-06-07 21:00**

```
```

### `follower-target-monitor.log` — 最終更新 **2026-07-04 21:00**

```
{"ok":true,"today":"2026-06-30","follower":155,"ideal":300,"gap":-145,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
{"ok":true,"today":"2026-06-30","follower":155,"ideal":300,"gap":-145,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
{"ok":true,"today":"2026-07-01","follower":155,"ideal":309,"gap":-154.43478260869563,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
{"ok":true,"today":"2026-07-01","follower":155,"ideal":309,"gap":-154.43478260869563,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
{"ok":true,"today":"2026-07-02","follower":155,"ideal":319,"gap":-163.8695652173913,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
{"ok":true,"today":"2026-07-02","follower":155,"ideal":319,"gap":-163.8695652173913,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
{"ok":true,"today":"2026-07-03","follower":155,"ideal":328,"gap":-173.304347826087,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
{"ok":true,"today":"2026-07-03","follower":155,"ideal":328,"gap":-173.304347826087,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
{"ok":true,"today":"2026-07-04","follower":155,"ideal":338,"gap":-182.73913043478262,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
{"ok":true,"today":"2026-07-04","follower":155,"ideal":338,"gap":-182.73913043478262,"today_follow":0,"recent7":{"f":0,"fb":0,"rate":null},"alerts":2,"future_pace":145}
```

### `hashtag-follow-err.log` — 最終更新 **2026-08-23 10:15**

```
```

### `hashtag-follow.log` — 最終更新 **2026-09-05 10:20**

```
[2026-09-05T01:18:41.937Z]   @<伏せ>: ❌ random-looking handle (likely throwaway/spam): kankan1014
  @<伏せ>: ❌ random-looking handle (likely throwaway/spam): kankan1014
[2026-09-05T01:19:14.787Z]   @<伏せ>: ❌ inactive (last post 152d ago)
  @<伏せ>: ❌ inactive (last post 152d ago)
[2026-09-05T01:19:49.312Z]   @<伏せ>: ✅
  @<伏せ>: ✅
[2026-09-05T01:20:22.157Z]   @<伏せ>: ❌ follower>>following exclusion: ratio=0.19 (fw=222/fr=1148) — フォロバ率低のため skip
  @<伏せ>: ❌ follower>>following exclusion: ratio=0.19 (fw=222/fr=1148) — フォロバ率低のため skip
[2026-09-05T01:20:52.170Z] === end: 1/5 OK ===
=== end: 1/5 OK ===
```

### `reply-followback-check.log` — 最終更新 **2026-08-10 01:15**

```
[2026-08-08T04:15:32.922Z] @<伏せ>: no, scheduled_unfollow_at=2026-08-15T03:55:27.972Z
[2026-08-08T04:15:32.924Z] @<伏せ>: no, scheduled_unfollow_at=2026-08-18T00:02:01.463Z
[2026-08-08T04:15:32.924Z] @<伏せ>: no, scheduled_unfollow_at=2026-08-18T19:14:18.150Z
[2026-08-08T04:15:32.926Z] done
[2026-08-08T16:15:00.061Z] checking 2 handles: Poitftp,mashitora_
[2026-08-08T16:15:05.458Z] @<伏せ>: no, scheduled_unfollow_at=2026-08-17T21:50:18.581Z
[2026-08-08T16:15:05.458Z] @<伏せ>: no, scheduled_unfollow_at=2026-08-16T16:54:39.655Z
[2026-08-08T16:15:05.460Z] done
[2026-08-09T04:15:03.077Z] nothing to check (no entries 24h+ pending)
[2026-08-09T16:15:05.117Z] nothing to check (no entries 24h+ pending)
```

### `reply-followers-cleanup.log` — 最終更新 **2026-08-10 09:49**

```
  - <ws preparing> retrieving websocket url from http://127.0.0.1:1
[check-followback] connect attempt 2/3 failed: browserType.connectOverCDP: Timeout 60000ms exceeded.
Call log:
  - <ws preparing> retrieving websocket url from http://
[check-followback] connect attempt 3/3 failed: browserType.connectOverCDP: Timeout 60000ms exceeded.
Call log:
  - <ws preparing> retrieving websocket url from http://
 — abort cleanup
[2026-08-10T00:48:07.327Z] due unfollows: 165 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyo
[2026-08-10T00:49:55.907Z] recheck failed: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/check-followback.js mao_otk_tw cpaky1 sukesankoba fxm
```

### `revenge-unfollow-err.log` — 最終更新 **2026-07-12 13:00**

```
ensure-chrome: login-mode-guard active, skip launch
```

### `revenge-unfollow.log` — 最終更新 **2026-08-09 13:00**

```
{"ok":true,"checked":1,"revenge_unfollowed":0,"still_mutual":0,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":[],"ghostSkipped":[],"checkFail":[]}
{"ok":false,"error":"CDP browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <w
{"ok":false,"error":"CDP browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <w
{"ok":false,"error":"CDP browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <w
[whitelist] skip @<伏せ>
{"ok":true,"checked":2,"revenge_unfollowed":0,"still_mutual":1,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":["okazusan1"],"ghostSkipped":[],"che
[whitelist] skip @<伏せ>
{"ok":true,"checked":1,"revenge_unfollowed":0,"still_mutual":0,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":[],"ghostSkipped":[],"checkFail":[]}
[whitelist] skip @<伏せ>
{"ok":true,"checked":1,"revenge_unfollowed":0,"still_mutual":0,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":[],"ghostSkipped":[],"checkFail":[]}
```

### `unfollow-cleanup-evening-err.log` — 最終更新 **2026-08-09 20:31**

```
[unfollow-cleanup] 2026-08-09T11:30:05.622Z whitelist size: 12
[unfollow-cleanup] 2026-08-09T11:30:05.789Z Chrome tabs: 4
[unfollow-cleanup] 2026-08-09T11:30:05.857Z scraping /following...
[unfollow-cleanup] 2026-08-09T11:30:47.492Z scraped 172 handles
[unfollow-cleanup] 2026-08-09T11:30:47.542Z tier: T1=15 T2=58 T3=73 T4=26
[unfollow-cleanup] 2026-08-09T11:30:47.542Z candidates (2): mocaketu, gSkTl8nNVU89471
[unfollow-cleanup] 2026-08-09T11:30:47.542Z unfollowing @<伏せ> (bio: "フォロー中 ウクレレばかり弾いてるカリンバ沼民2022年6月からカリンバ�
[unfollow-cleanup] 2026-08-09T11:30:54.219Z   OK
[unfollow-cleanup] 2026-08-09T11:31:04.884Z unfollowing @<伏せ> (bio: "フォローされています フォロー中 フォロバ100")
[unfollow-cleanup] 2026-08-09T11:31:11.656Z   OK
```

### `unfollow-cleanup-evening.log` — 最終更新 **2026-08-06 20:30**

```
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
```

### `unfollow-cleanup-morning-err.log` — 最終更新 **2026-08-10 09:31**

```
[unfollow-cleanup] 2026-08-10T00:30:08.328Z scraping /following...
[unfollow-cleanup] 2026-08-10T00:30:49.380Z scraped 172 handles
[unfollow-cleanup] 2026-08-10T00:30:49.415Z tier: T1=13 T2=59 T3=74 T4=26
[unfollow-cleanup] 2026-08-10T00:30:49.415Z candidates (3): tatantan_abc, DfcAbc11052, as030376
[unfollow-cleanup] 2026-08-10T00:30:49.415Z unfollowing @<伏せ> (bio: "フォロー中 懸賞応募中 写真好き ディズニー大好き 当選報告は写真�
[unfollow-cleanup] 2026-08-10T00:30:55.992Z   OK
[unfollow-cleanup] 2026-08-10T00:31:10.683Z unfollowing @<伏せ> (bio: "フォロー中 ブロスタ/モンスト/バウンティ やってます。たまにネタツ
[unfollow-cleanup] 2026-08-10T00:31:17.283Z   OK
[unfollow-cleanup] 2026-08-10T00:31:28.792Z unfollowing @<伏せ> (bio: "フォロー中 元業界最大手です！仲介もしてます！フォロバ100%です！フ�
[unfollow-cleanup] 2026-08-10T00:31:35.366Z   OK
```

### `unfollow-cleanup-morning.log` — 最終更新 **2026-08-06 09:30**

```
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
```

### `unfollow-daily-err.log` — 最終更新 **2026-07-12 14:00**

```
ensure-chrome: login-mode-guard active, skip launch
ensure-chrome: login-mode-guard active, skip launch
```

### `unfollow-daily.log` — 最終更新 **2026-08-10 09:00**

```
{"ok":true,"total_candidates":1,"unfollowed":["okane_kyukyu"],"ghosts":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":3,"unfollowed":["kabu_world_map","tanoc_happy"],"ghosts":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":3,"unfollowed":[],"cancelled":["aichikyu369","abi_41_official","hitsujimaru_ai"],"ghosts":[],"failed":[]}
```

### `unfollow-evening-err.log` — 最終更新 **2026-07-12 22:00**

```
ensure-chrome: login-mode-guard active, skip launch
ensure-chrome: login-mode-guard active, skip launch
ensure-chrome: login-mode-guard active, skip launch
```

### `unfollow-evening.log` — 最終更新 **2026-08-09 22:00**

```
{"ok":true,"total_candidates":19,"unfollowed":[],"cancelled":[],"ghosts":["cony30175146","gSkTl8nNVU89471","xwGiEzSE9","DwacHXEg55","NyEkrFlE8","sinonon882211","lis171322
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
```

### `unfollow-stats-monitor.log` — 最終更新 **2026-08-10 09:30**

```
  "ok": true,
  "alerts": [],
  "stats": {
    "runs_inspected": 7,
    "sumUnfollowed": 3,
    "sumCancelled": 5,
    "sumFailed": 0,
    "failRatio": "0.00"
  }
}
```

### `unfollow-stats-monitor.stderr.log` — 最終更新 **2026-05-24 09:30**

```
```

### `unfollow-stats-monitor.stdout.log` — 最終更新 **2026-05-24 09:30**

```
```

### `x-follower-cron.log` — 最終更新 **2026-07-04 23:54**

```
- フォロワー3.8万 > 200で、following/follower = 38000/38000 ≈ 1.0 → インフルエンサーフィルター（<0.3）は非該当 ✅
- ただしフォロワー10,000人以上 → **除外条件に該当**（SKILL.md: フォロワー10,000人以上の大型アカウントは除外）❌

この方は除外です。別のアカウントを探します。
検索結果が `@<伏せ>` だらけです。別のキーワードで検索します。節約・家計管理系のキーワードで探しましょう。

効率を上げるため、サブエージェントで複数の候補アカウントを並行評価＆フォローする作業を行います。
サブエージェントが作業開始しました。アンフォロー（money_yossy）はすでに完了しているので、データ更新を先に行います。
データを更新しました。サブエージェントのフォロー完了を待ちます。
[2026-07-04 23:54:03 JST] x-follower-cron done (follow, exit: 0)
```

### `x-follower-follow-err.log` — 最終更新 **2026-05-09 01:48**

```
```

### `x-follower-follow.log` — 最終更新 **2026-05-09 01:48**

```
```

### `x-follower-unfollow-err.log` — 最終更新 **2026-05-09 22:00**

```
```

### `x-follower-unfollow.log` — 最終更新 **2026-05-09 22:00**

```
```


---

**何も変えていない。フォローも投稿もしていない（$0）。**
