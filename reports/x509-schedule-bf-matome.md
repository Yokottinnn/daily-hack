# ブラックフライデーまとめを予約する（2026-11-15 23:42:49 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-19 12:08 ／ UTC 2026-11-19T03:08:00.000Z ／ いまから 5066 分後
```

## 1. 画像 4 枚を origin/main から取る
```
  0-cover.jpg        287735 bytes
  1-now.jpg          199135 bytes
  2-week.jpg         176967 bytes
  3-later.jpg        110725 bytes
  対象 4 枚 / 取れた 4 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 399 ／ 重み 688
  [2/2] 文字 158 ／ 重み 198
  冒頭（👇まで）の重み 136
  ALT: 1枚目 172字 ／ 2枚目 289字 ／ 3枚目 217字 ／ 4枚目 103字
OK 積んだ: x-blog-20261119-bf-matome
```

## 3. 11/19 12:08 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-bf-matome-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-bf-matome-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-bf-matome-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-bf-matome-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
