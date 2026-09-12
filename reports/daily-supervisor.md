# 毎日 必ず実行されるようにする番人

**このレポートが作られた時刻: 2026-09-13 03:02:55 JST**

> 毎日ちゃんと実行されていないジョブがあるのは非常に困るので、必ず実行される
> ような体制を作って欲しい。基準をゆるめるなど、考えを狭くせず、いろんな手段を
> 考えたうえで取り組んでね

## 0. いちばんの穴: **誰も「成功の印」を書いていない**

判定はログの更新時刻からの推測だけで、**「走って失敗した」と「走っていない」を
区別できない。** 実際 `x38` では次のように出ていた。

```
  comment-warmup  **ロード済み。触らない。**  "LastExitStatus" = 0;
```

**それでも返信は 75 時間 出ていなかった。**
`launchctl list` に出ることは、仕事をした証拠にならない（最上位ルール 13）。

## 1. 番人を置く

**8 本 ＋ mutual-prune の 9 本**について、次をやる。

1. **今日 走ったか**を観測できる事実で判定する（ログに今日 JST の行が在るか）
2. 走っていなければ
   a. **前提を直す**（死んだ login ロックを外す → `ensure-chrome` で CDP → 未ロードなら bootstrap）
   b. `kickstart -k` で走らせる
   c. 待って**もう一度 判定する**（最大 3 回）
3. 結果を `data/job-stamps/status.json` に書く
4. それでも走らないものが在れば **Slack に 1 回だけ**鳴らす

**「kickstart した」で終わらせない。走った証拠を取り直すところまでやる。**

```
  bash -n: OK（157 行）
  置いた: /Users/ny/.openclaw/workspace/scripts/daily-supervisor.sh
```

## 2. 起動方式を `StartCalendarInterval` にする

`StartInterval` は「前回から N 秒」で数えるので、**Mac が寝ていた分は消える。**
`StartCalendarInterval` なら**起動後に 1 回 まとめて発火する。**

番人は **05:00 と 17:00 JST ＋ `RunAtLoad`** で載せる。
**1 日 2 回 ある**ので、片方が寝ていても もう片方で拾える。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>ai.openclaw.daily-supervisor</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/ny/.openclaw/workspace/scripts/daily-supervisor.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>5</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>17</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/Users/ny/.openclaw/workspace/logs/daily-supervisor.out</string>
  <key>StandardErrorPath</key><string>/Users/ny/.openclaw/workspace/logs/daily-supervisor.err</string>
  <key>WorkingDirectory</key><string>/Users/ny/.openclaw/workspace</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>/Users/ny</string>
    <key>OPS_WS</key><string>/Users/ny/.openclaw/workspace</string>
    <key>MAX_FIX</key><string>3</string>
  </dict>
</dict>
</plist>
```

```
  plutil -lint: OK
  **載った（`launchctl list` に出た）** ← rc は見ない
```

## 3. その場で 1 回 走らせる（**待たない**・最上位ルール 9）

**追い上げで `comment-warmup` が走ると返信の生成が起きる（最大 4 件・$0.012）。**
他のジョブは LLM を呼ばないので $0。

```
  /var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x47-daily-supervisor.sh: line 368: timeout: command not found
```

### 出来上がった `status.json`

```json
  （まだ無い）
```

## 4. 費用

**番人そのものは LLM を呼ばない（$0）。**
追い上げで `comment-warmup` を走らせたときだけ返信の生成が走る。

| | 金額 |
| --- | --- |
| 追い上げ 1 回 | 最大 4 件 × $0.003 = **$0.012** |
| 1 日あたり（05:00・17:00 の 2 回） | 最大 **$0.024** |
| 1 か月あたり | 最大 **$0.72** |

**これは「定時が走らなかった日」だけ発生する上限で、実績ではない。**
定時が正常に走っていれば追い上げは 0 回 ＝ **$0**。

定時の返信ループ自体は **推定** 1 日 約 $0.19 ／ 1 か月 約 $5.8
（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。

## 5. 番人自身が死んだら

`RunAtLoad` ＋ **1 日 2 回のカレンダー**なので、Mac が再起動すれば必ず走る。
そのうえで外からも見ている。

- `ops-heartbeat`（30 分ごと）→ `last_reply` が 8 時間 出ていなければ **Slack**
- `ops-watchdog`（GitHub Actions・2 時間ごと）→ **Mac が丸ごと落ちても検知**

**番人・heartbeat・Actions の 3 段で、どれか 1 つが死んでも気づける。**
