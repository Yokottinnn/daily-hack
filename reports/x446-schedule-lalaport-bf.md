# ららぽーと豊洲ブラックフライデーの告知を予約する（2026-11-10 00:21:21 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-12 12:00 ／ UTC 2026-11-12T03:00:00.000Z ／ いまから 3579 分後
```

## 1. 画像 4 枚を origin/main から取る
```
  1-official.jpg     315718 bytes
  4-prizes.jpg       130034 bytes
  2-point.jpg        222998 bytes
  3-flyer-top.jpg    385358 bytes
  対象 4 枚 / 取れた 4 枚
```

## 2. 文面を確かめて積む
```
  文字 246 ／ 冒頭の重み 272 ／ 全体 345
  ALT: 1枚目 69字 ／ 2枚目 324字 ／ 3枚目 243字 ／ 4枚目 100字
OK 積んだ: x-news-20261112-lalaport-bf
```

## 3. 11/12 12:00 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-lalaport-toyosu-black-friday-2026-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-lalaport-toyosu-black-friday-2026-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-lalaport-toyosu-black-friday-2026-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-lalaport-bf-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
