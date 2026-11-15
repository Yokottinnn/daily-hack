# 高輪ゲートウェイの告知を予約する（2026-11-08 17:38:16 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-09 12:00 ／ UTC 2026-11-09T03:00:00.000Z ／ いまから 1102 分後
```

## 1. 画像 4 枚を origin/main から取る
```
  1-morning.jpg      278542 bytes
  2-luftbaum.jpg     236231 bytes
  3-mon.jpg          293636 bytes
  4-access.jpg       242001 bytes
  対象 4 枚 / 取れた 4 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 167 ／ 重み 260
  [2/2] 文字 174 ／ 重み 219
OK 積んだ: x-news-20261109-takanawa
```

## 3. 12:00 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-takanawa-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-takanawa-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-takanawa-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-takanawa-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
