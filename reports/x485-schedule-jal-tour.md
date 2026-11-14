# JAL のツアーと別々の予約の告知を予約する（2026-11-15 00:41:49 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-17 12:00 ／ UTC 2026-11-17T03:00:00.000Z ／ いまから 3559 分後
```

## 1. 画像 2 枚を origin/main から取る
```
  1-compare.jpg      153256 bytes
  2-plane.jpg        175000 bytes
  対象 2 枚 / 取れた 2 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 154 ／ 重み 268
  [2/2] 文字 160 ／ 重み 183
  ALT: 1枚目 258字 ／ 2枚目 181字
OK 積んだ: x-blog-20261117-jal-tour
```

## 3. 11/17 12:00 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-jal-tour-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-jal-tour-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-jal-tour-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-jal-tour-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
