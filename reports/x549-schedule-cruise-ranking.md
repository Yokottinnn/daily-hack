# クルーズ船の寄港回数を予約する（2026-11-23 23:13:28 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-25 11:56 ／ UTC 2026-11-25T02:56:00.000Z ／ いまから 2203 分後
```

## 1. 画像 6 枚を origin/main から取る
```
  1-rank.jpg         202750 bytes
  2-tokyo.jpg        185425 bytes
  3-nagasaki.jpg     195599 bytes
  4-kobe.jpg         161216 bytes
  5-ishigaki.jpg     166159 bytes
  6-sasebo.jpg       169994 bytes
  対象 6 枚 / 取れた 6 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 134 ／ 重み 229
  [2/2] 文字 136 ／ 重み 144
  冒頭（👇まで）の重み 229
  ALT: 1枚目 197字 ／ 2枚目 140字 ／ 3枚目 143字 ／ 4枚目 152字 ／ 5枚目 128字 ／ 6枚目 173字
OK 積んだ: x-blog-20261125-cruise-ranking
```

## 3. 11/19 12:08 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-cruise-ranking-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-cruise-ranking-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-cruise-ranking-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-cruise-ranking-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
