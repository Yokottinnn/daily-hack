# 作戦室の数字の取り直し（t321・**$0**）

生成: **2026-10-19T11:24:27+0900**

## ① board-weekly の実行記録

```text
	path = /Users/ny/Library/LaunchAgents/com.dailyhack.board-weekly.plist
	state = not running
	program = /bin/bash
	arguments = {
	stdout path = /Users/ny/.openclaw/logs/board-weekly.out.log
	stderr path = /Users/ny/.openclaw/logs/board-weekly.err.log
	runs = 2
	last exit code = 0
		state = active
		state = active
	properties = inferred program
```

### plist

```text
{
  "Label" => "com.dailyhack.board-weekly"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/bin/board-weekly-boot.sh"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/logs/board-weekly.err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/logs/board-weekly.out.log"
  "StartCalendarInterval" => {
    "Hour" => 6
    "Minute" => 40
  }
}
```

### StandardOutPath の末尾（/Users/ny/.openclaw/logs/board-weekly.out.log・更新 Oct 12 18:40:59 2026）

```text
```

### StandardErrorPath の末尾（/Users/ny/.openclaw/logs/board-weekly.err.log・更新 Oct 12 18:40:59 2026）

```text
```

### 書き出し先 reports/board の更新日時

```text
total 128
drwxr-xr-x    8 ny  staff    256 Oct 19 07:19 .
drwxr-xr-x  946 ny  staff  30272 Oct 19 11:24 ..
drwxr-xr-x    6 ny  staff    192 Oct 19 06:49 asp-probe
-rw-r--r--    1 ny  staff  42955 Oct 19 06:49 gsc-weekly.json
-rw-r--r--    1 ny  staff    100 Oct 19 06:49 mac-weekly-status.json
drwxr-xr-x    7 ny  staff    224 Oct 19 07:10 trend
-rw-r--r--    1 ny  staff   3612 Oct 19 07:19 trend-words.json
-rw-r--r--    1 ny  staff  11853 Oct 19 06:49 x-weekly.json
```

## ② X の数字（いま読んだもの）

```json
{
 "generated": "2026-10-19T02:24:28.594Z",
 "handle": "heng_ji31590",
 "header": {
  "following": 305,
  "followers": 515,
  "raw": {
   "following": "305 フォロー中",
   "followers": "515 フォロワー"
  }
 },
 "d7": {
  "impressions": 173600,
  "profileVisits": 1400,
  "engagements": 2600,
  "verifiedFollowers": 267,
  "followersOnPage": 515
 },
 "d90": {
  "impressions": 173600,
  "profileVisits": 1400
 },
 "ocr": {
  "verifiedFollowers": 267,
  "verifiedImpressions90": 167,
  "eligible": false
 }
}
```

## ③ board-weekly を kickstart した（rc=0）。結果は次の heartbeat で reports/board/mac-weekly-status.json に出る
