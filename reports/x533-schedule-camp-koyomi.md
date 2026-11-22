# CAMPこよみワークショップを予約する（2026-11-22 00:32:53 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-22 12:13 ／ UTC 2026-11-22T03:13:00.000Z ／ いまから 701 分後
```

## 1. 画像 2 枚を origin/main から取る
```
  1-official.jpg     173759 bytes
  2-point.jpg        153301 bytes
  対象 2 枚 / 取れた 2 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 154 ／ 重み 265
  [2/2] 文字 117 ／ 重み 110
  冒頭（👇まで）の重み 265
  ALT: 1枚目 52字 ／ 2枚目 146字
OK 積んだ: x-blog-20261122-camp-koyomi
```

## 3. 11/19 12:08 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-camp-koyomi-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-camp-koyomi-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-camp-koyomi-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-camp-koyomi-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
