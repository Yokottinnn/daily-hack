# 花火の告知（B 案）を予約する（2026-10-23 00:18:44 JST・$0）

## 0. 予約時刻

```
  JST          2026-10-23 08:00
  scheduled_at 2026-10-22T23:00:00.000Z  (UTC)
  いまから      462 分後
```

## 1. 画像 4 枚を origin/main から取り直す

```
  1-checklist.jpg    253701 bytes
  2-alcohol.jpg      170264 bytes
  3-roads.jpg        159620 bytes
  4-no-ticket.jpg    147682 bytes
  対象 4 枚 / 取れた 4 枚
```

## 2. 文面を origin/main から取り、ロックのハッシュと照合して積む

```
  [1/1] ロック 一致 ／ 文字 559 ／ 重み 1048 / 25000
OK 積んだ: blog-promo-20261023-tokyo-bay-hanabi
  rc=0
```

## 3. 10/23 08:00 に 1 回だけ走るジョブ

```
  bootstrap rc=0  
```

## 4. 載ったことの証拠（rc ではなく print で見る）

```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-hanabi-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 5. Chrome は健全か（予約時点の参考。08:00 に run-publish.sh が ensure-chrome を呼ぶ）

```
{"ok":true,"healthy":true,"round_trip_ms":3896,"product":"Chrome/140.0.7339.207","tabs":10}
  (rc=0)
```

## 取り消すとき

```bash
  launchctl bootout gui/501/com.dailyhack.publish-hanabi-oneshot
  rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-hanabi-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-hanabi-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させないので、毎日の費用は増えない。**
