# ループの仕上げ（2026-08-22T15:39:05Z）

- node: /usr/local/bin/node

## A. 019 で失われた設定を戻す

> 値の出どころは **014 が壊れる前に実機から読み出した記録**。推測ではない。

### ai.openclaw.competitor-follower-follow
- **設定を戻してロード成功**（cap=5 / 発火 11:30・18:30 JST）

### ai.openclaw.hashtag-follow
- ログの発火時刻（UTC）: 01:15
08:00 → JST: 10:15 17:00
- **設定を戻してロード成功**（cap=90）

### ai.openclaw.auto-thread-chainifier
- 019 が env に `Hour=2 / Minute=0` というゴミを入れ、発火の片方 00:11 JST も誤りだった
- ログの 17:00 UTC ＝ **02:00 JST** が本来の発火。これ 1 本にする
- **env を掃除してロード成功**（発火 02:00 JST）

## B. ③ アンフォローを立ち上げる

### 候補スクリプト
- auto_detect_and_unfollow_inactive.js: あり（157 行）
- revenge-unfollow.js: あり（212 行）

### ログから発火時刻を探す
- unfollow-cleanup.log: 無い
- unfollow-daily.log: 234 行 / 時刻=読めない
- unfollow-evening.log: 232 行 / 時刻=読めない
- revenge-unfollow.log: 101 行 / 時刻=読めない
- auto_detect_and_unfollow_inactive.log: 無い

使うスクリプト: auto_detect_and_unfollow_inactive.js
発火時刻: **ログから読めなかったので 22:30 JST を置いた。**
これは実機から読み取った値ではなく、こちらで選んだ既定値。
1 日 1 回・深夜帯。Jordan の指定は「24 時間でフォローバックが無ければアンフォロー」なので
日次で足りる。**変えたい時刻があれば言ってください。**
ラベル: ai.openclaw.auto-detect-and-unfollow-inactive
- **ロード成功**

## 最終確認（launchctl の実体）

ai.openclaw.auto-thread-chainifier               稼働
ai.openclaw.badge-followback                     稼働
ai.openclaw.competitor-follower-follow           稼働
ai.openclaw.hashtag-follow                       稼働
ai.openclaw.auto-detect-and-unfollow-inactive    稼働

## 設定の確認（plutil -p は読み取り専用）
### ai.openclaw.competitor-follower-follow
{
  "EnvironmentVariables" => {
    "COMPETITOR_FOLLOW_DAILY_CAP" => "5"
    "PATH" => "/usr/local/bin:/usr/bin:/bin"
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
### ai.openclaw.hashtag-follow
{
  "EnvironmentVariables" => {
    "HASHTAG_FOLLOW_DAILY_CAP" => "90"
    "PATH" => "/usr/local/bin:/usr/bin:/bin"
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
### ai.openclaw.auto-thread-chainifier
{
  "EnvironmentVariables" => {
    "PATH" => "/usr/local/bin:/usr/bin:/bin"
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
  ]
}
