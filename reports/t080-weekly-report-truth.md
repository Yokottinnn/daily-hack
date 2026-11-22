# 週次レポートは何を走らせているか（t080）

生成: **2026-09-15T01:56:08+0900**

## 1. launchd に載っているジョブ

```
-	0	com.apple.pluginkit.pkreporter
-	0	com.microsoft.SyncReporter
-	0	com.apple.DiagnosticsReporter
-	0	com.apple.loginwindow.LWWeeklyMessageTracer
-	-9	com.apple.ReportCrash
-	0	com.dailyhack.weekly-blog-report
```

## 2. plist が実際に叩いているコマンド

### `ai.openclaw.cost-report-daily.plist`

```
["\/bin\/bash","\/Users\/ny\/.openclaw\/workspace\/scripts\/run-daily-cost-report.sh"]```

- 実行間隔: `-`
- カレンダー: `{"Hour":0,"Minute":5}`

### `ai.openclaw.follower-daily-report.plist`

```
["\/bin\/bash","-c","eval \"$(\/usr\/local\/bin\/node -e \"const c=require('\/Users\/ny\/.openclaw\/openclaw.json');console.log('export SLACK_BOT_TOKEN='+JSON.stringify((c.channels&&c.channels.slack&&c.channels.slack.botToken)||''));\")\"; cd \/Users\/ny\/.openclaw\/workspace; \/usr\/local\/bin\/node scripts\/follower-daily-report.js"]```

- 実行間隔: `-`
- カレンダー: `{"Hour":8,"Minute":0}`

### `ai.openclaw.monthly-kpi-report.plist`

```
["\/usr\/local\/bin\/node","\/Users\/ny\/.openclaw\/workspace\/scripts\/monthly-kpi-report.js"]```

- 実行間隔: `-`
- カレンダー: `{"Day":1,"Hour":9,"Minute":0}`

### `ai.openclaw.weekly-design-reminder.plist`

```
["\/bin\/bash","\/Users\/ny\/.openclaw\/workspace\/scripts\/weekly-design-reminder.sh"]```

- 実行間隔: `-`
- カレンダー: `{"Weekday":1,"Hour":10,"Minute":0}`

### `com.dailyhack.weekly-blog-report.plist`

```
["\/opt\/homebrew\/bin\/python3.11","\/Users\/ny\/scripts\/weekly-blog-report.py"]```

- 実行間隔: `-`
- カレンダー: `{"Weekday":1,"Hour":8,"Minute":0}`

## 3. Mac のクローンの状態

| 項目 | 値 |
| --- | --- |
| パス | `/Users/ny/projects/anta-baka-x/blog` |
| HEAD | `ade78a1 2026-08-30 22:54:06 +0900 fix: サウナ告知が no candidate で終わった原�` |
| origin/main | `e486831 2026-09-15 01:55:08 +0900` |
| main に対して遅れ | **186 コミット** |

### weekly-blog-report.py はあるか

- **無い。** これだけで (a) が確定する

## 4. ${ALL_VISITS} を書いているファイル

**この文字列を持つスクリプトが、いま走っている本体。**

```
```

## 読み方

- **3 の「遅れ」が 0 でないなら (a)。** クローンを pull すれば直る
- **4 に `.sh` が出てきたら (b)。** plist がそちらを指している
- 両方なら両方 直す必要がある
