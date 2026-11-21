# 決済キャンペーン5つを予約する（2026-11-21 12:37:02 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-21 13:47 ／ UTC 2026-11-21T04:47:00.000Z ／ いまから 70 分後
```

## 1. 画像 1 枚を origin/main から取る
```
  4-pay5.jpg         166218 bytes
  対象 1 枚 / 取れた 1 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 456 ／ 重み 759
  [2/2] 文字 124 ／ 重み 136
  冒頭（👇まで）の重み 157
  ALT: 1枚目 333字
OK 積んだ: x-blog-20261121-bf-pay
```

## 3. 11/19 12:08 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-bf-pay-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-bf-pay-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-bf-pay-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-bf-pay-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
