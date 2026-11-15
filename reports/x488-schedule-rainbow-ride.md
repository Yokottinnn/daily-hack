# レインボーライドの交通規制の告知を予約する（2026-11-15 01:06:23 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-18 12:00 ／ UTC 2026-11-18T03:00:00.000Z ／ いまから 4974 分後
```

## 1. 画像 2 枚を origin/main から取る
```
  1-official.jpg     280928 bytes
  2-point.jpg        158227 bytes
  対象 2 枚 / 取れた 2 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 590 ／ 重み 1104
  [2/2] 文字 112 ／ 重み 86
  冒頭（👇まで）の重み 268
  ALT: 1枚目 88字 ／ 2枚目 127字
OK 積んだ: x-blog-20261118-rainbow-ride
```

## 3. 11/18 12:00 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-rainbow-ride-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-rainbow-ride-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-rainbow-ride-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-rainbow-ride-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
