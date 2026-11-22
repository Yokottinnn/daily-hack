# スリープで消えない起動方式にする ＋ Mac を寝かせない

**このレポートが作られた時刻: 2026-09-13 03:09:08 JST**

> `StartInterval` は「**前回の発火から N 秒**」で数える。
> **Mac が寝ていた／電源が落ちていた分は、そのまま消える。**
>
> `StartCalendarInterval` は「その時刻に発火」で、
> **発火時刻を過ぎて起動した場合は、起きた直後に 1 回 まとめて発火する。**

## 1. いまの起動方式

```
  comment-warmup               カレンダー 4 回/日
  competitor-follower-follow   カレンダー 2 回/日
  hashtag-follow               カレンダー 2 回/日
  badge-followback             カレンダー 1 回/日
  reply-followback-check       カレンダー 2 回/日
  reply-followers-cleanup      StartInterval 3600 秒（= 1 日 24 回）
  incoming-reply-watcher       StartInterval 900 秒（= 1 日 96 回）
  pipeline-heartbeat           カレンダー 2 回/日
  mutual-prune                 plist 無し
```

## 2. `StartCalendarInterval` に移す（**発火回数は変えない**）

間隔から「1 日 何回か」を出し、**その回数ぶんの時刻を等間隔に置く。**
6 時間ごと → 1 日 4 回、12 時間ごと → 1 日 2 回。**回数が増えないので API 課金も増えない。**

触らないもの: 既にカレンダーのもの ／ **1 日 より長い間隔** ／ **1 時間 より短い間隔**
（分刻みのものをカレンダーにすると回数が激減してしまう）

```
  comment-warmup               ALREADY_CALENDAR
  competitor-follower-follow   ALREADY_CALENDAR
  hashtag-follow               ALREADY_CALENDAR
  badge-followback             ALREADY_CALENDAR
  reply-followback-check       ALREADY_CALENDAR
  reply-followers-cleanup      CONVERTED 3600s -> 24 times/day at 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,0,1 時
  incoming-reply-watcher       SKIP_TOO_SHORT 900
  pipeline-heartbeat           ALREADY_CALENDAR
  mutual-prune                 plist 無し
```

```
  --- 変換後 ---
  comment-warmup               16,12,22,19 時          ロード済み
  competitor-follower-follow   11,18 時                ロード済み
  hashtag-follow               10,17 時                ロード済み
  badge-followback             0 時                    ロード済み
  reply-followback-check       1,13 時                 ロード済み
  reply-followers-cleanup      2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,0,1 時 ロード済み
  incoming-reply-watcher       （カレンダー無し） 時 ロード済み
  pipeline-heartbeat           8,20 時                 ロード済み
```

## 3. `caffeinate` を常駐させる（**sudo なし**）

`sudo pmset -a sleep 0` は**管理者パスワードが要る**ので、無人実行では使えない。
`/usr/bin/caffeinate -dimsu` は **sudo が要らない。**

| 旗 | 意味 |
| --- | --- |
| `-d` | ディスプレイを寝かせない |
| `-i` | アイドルスリープを抑える |
| `-m` | ディスクのアイドルを抑える |
| `-s` | **電源に繋がっているとき**のシステムスリープを抑える |
| `-u` | ユーザーが操作中だと宣言する |

**正直に書くと、これで防げるのは「アイドルで勝手に寝る」だけ。**
**蓋を閉じた ／ 手でスリープ ／ 電源を抜いてバッテリー切れ は防げない。**
だから §2 のカレンダー化が要る。**片方では足りない。**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>ai.openclaw.caffeinate</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/caffeinate</string>
    <string>-dimsu</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>/Users/ny/.openclaw/workspace/logs/caffeinate.out</string>
  <key>StandardErrorPath</key><string>/Users/ny/.openclaw/workspace/logs/caffeinate.err</string>
</dict>
</plist>
```

```
  plutil -lint: OK
  **載った（`launchctl list` に出た）** ← rc は見ない
  --- 実際に caffeinate が動いているか ---
    28910 /usr/bin/caffeinate -dimsu

  --- いまの電源設定（参考・変更はしていない） ---
     standby              1
     hibernatefile        /var/vm/sleepimage
     networkoversleep     0
     disksleep            0
     sleep                0 (sleep prevented by caffeinate, caffeinate, WindowServer, powerd)
     hibernatemode        3
     displaysleep         10 (display sleep prevented by caffeinate)
```

## 4. 費用

**LLM を一切 呼ばない。** 起動方式を変えるだけ。

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**返信ループの発火回数は変えていない**ので、定時の推定
（1 日 約 $0.19 ／ 1 か月 約 $5.8・前提 Haiku 4.5・通過率 25%・生成 64 回/日）も**変わらない。**
寝ていて飛んでいた分が飛ばなくなるぶん、**実額は推定値に近づく方向**に動く。

## 5. 戻すには

```
  # 起動方式を戻す（plist は .bak-20260913-030908 に退避してある）
  cp ~/Library/LaunchAgents/ai.openclaw.<名前>.plist.bak-20260913-030908 \
     ~/Library/LaunchAgents/ai.openclaw.<名前>.plist
  launchctl bootout gui/$(id -u)/ai.openclaw.<名前>
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.<名前>.plist

  # 寝かせない設定を止める
  launchctl bootout gui/$(id -u)/ai.openclaw.caffeinate
```
