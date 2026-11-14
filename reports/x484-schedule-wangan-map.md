# 湾岸エリアイベントマップの告知を予約する（2026-11-14 21:36:00 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-15 12:00 ／ UTC 2026-11-15T03:00:00.000Z ／ いまから 864 分後
```

## 1. 画像 4 枚を origin/main から取る
```
  1-map.jpg          202870 bytes
  2-xmas.jpg         236830 bytes
  3-car.jpg          170689 bytes
  4-tb.jpg           171637 bytes
  対象 4 枚 / 取れた 4 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 186 ／ 重み 273
  [2/2] 文字 106 ／ 重み 190
  ALT: 1枚目 143字 ／ 2枚目 130字 ／ 3枚目 126字 ／ 4枚目 142字
OK 積んだ: x-blog-20261115-wangan-map
```

## 3. 11/15 12:00 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-wangan-map-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-wangan-map-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-wangan-map-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-wangan-map-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
