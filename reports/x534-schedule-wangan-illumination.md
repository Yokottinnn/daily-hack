# 湾岸のイルミとクリスマスを予約する（2026-11-22 00:53:37 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-23 11:52 ／ UTC 2026-11-23T02:52:00.000Z ／ いまから 2099 分後
```

## 1. 画像 1 枚を origin/main から取る
```
  1-cover.jpg        323478 bytes
  対象 1 枚 / 取れた 1 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 173 ／ 重み 260
  [2/2] 文字 119 ／ 重み 151
  冒頭（👇まで）の重み 260
  ALT: 1枚目 283字
OK 積んだ: x-blog-20261123-wangan-illumination
```

## 3. 11/19 12:08 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-wangan-illumination-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-wangan-illumination-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-wangan-illumination-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-wangan-illumination-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
