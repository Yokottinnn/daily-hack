# 壊した plist の再生（2026-08-22T14:08:07Z）

## 部品
- node の実パス（launchctl print から）: /usr/local/bin/node

## ai.openclaw.auto-thread-chainifier
- ログ: auto-thread-chainifier.log 85 行
- ログから読めた発火時刻（多い順 2 つ）: 17:00 15:11 
- ログは UTC 表記なので JST に直して plist に書く（launchd はローカル時刻で解釈）
- 回収した環境変数: {"Hour":2,"Minute":0}
組み立てた: 発火 02:00 JST / 00:11 JST
- 設置した（元は ai.openclaw.auto-thread-chainifier.plist.broken.20260822-140807 へ退避）
```
{
  "EnvironmentVariables" => {
    "Hour" => "2"
    "Minute" => "0"
  }
  "Label" => "ai.openclaw.auto-thread-chainifier"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/auto-thread-chainifier.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/auto-thread-chainifier-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/auto-thread-chainifier.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 2
      "Minute" => 0
    }
    1 => {
      "Hour" => 0
      "Minute" => 11
```
- **ロード成功**

## ai.openclaw.competitor-follower-follow
- ログ: competitor-follower-follow.log 1408 行
- ログから読めた発火時刻（多い順 2 つ）: 02:30 09:30 
- ログは UTC 表記なので JST に直して plist に書く（launchd はローカル時刻で解釈）
- 回収した環境変数: ["\/usr\/local\/bin\/node","\/Users\/ny\/.openclaw\/workspace\/scripts\/competitor-follower-follow.js"]
組み立てた: 発火 11:30 JST / 18:30 JST
- 設置した（元は ai.openclaw.competitor-follower-follow.plist.broken.20260822-140807 へ退避）
```
{
  "EnvironmentVariables" => {
  }
  "Label" => "ai.openclaw.competitor-follower-follow"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/competitor-follower-follow-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/competitor-follower-follow.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 11
      "Minute" => 30
    }
    1 => {
      "Hour" => 18
      "Minute" => 30
    }
  ]
```
- **ロード成功**

## ai.openclaw.hashtag-follow
- ログ: hashtag-follow.log 1053 行
- ログから読めた発火時刻（多い順 2 つ）: 01:15 08:00 
- ログは UTC 表記なので JST に直して plist に書く（launchd はローカル時刻で解釈）
- 回収した環境変数: ["\/usr\/local\/bin\/node","\/Users\/ny\/.openclaw\/workspace\/scripts\/hashtag-follow.js"]
組み立てた: 発火 10:15 JST / 17:00 JST
- 設置した（元は ai.openclaw.hashtag-follow.plist.broken.20260822-140807 へ退避）
```
{
  "EnvironmentVariables" => {
  }
  "Label" => "ai.openclaw.hashtag-follow"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/hashtag-follow.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/hashtag-follow-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/hashtag-follow.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 10
      "Minute" => 15
    }
    1 => {
      "Hour" => 17
      "Minute" => 0
    }
  ]
```
- **ロード成功**

## Chrome CDP

016 の実測で **18810 が応答**している。Chrome 自体は生きているので、
chrome-cdp ジョブの再生は急がない（ここでは触らない）。
```
{
   "Browser": "Chrome/140.0.7339.207",
   "Protocol-Version": "1.3",
   "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/5```

## 最終確認（launchctl の実体）
ai.openclaw.auto-thread-chainifier            稼働
ai.openclaw.badge-followback                  稼働
ai.openclaw.competitor-follower-follow        稼働
ai.openclaw.hashtag-follow                    稼働
