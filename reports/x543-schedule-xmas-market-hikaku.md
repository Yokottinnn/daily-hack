# クリスマスマーケット 8 会場を予約する（2026-11-22 13:47:43 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-24 12:07 ／ UTC 2026-11-24T03:07:00.000Z ／ いまから 2780 分後
```

## 1. 画像 10 枚を origin/main から取る
```
  1-official.jpg     270063 bytes
  2-compare.jpg      193880 bytes
  3-mugs.jpg         153529 bytes
  4-free.jpg         263726 bytes
  5-shiba.jpg        201508 bytes
  6-roppongi.jpg     255826 bytes
  7-azabudai.jpg     308333 bytes
  8-skytree.jpg      328605 bytes
  9-ueno.jpg         212476 bytes
  10-marunouchi.jpg   355106 bytes
  対象 10 枚 / 取れた 10 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 135 ／ 重み 247
  [2/2] 文字 174 ／ 重み 183
  冒頭（👇まで）の重み 247
  ALT: 1枚目 126字 ／ 2枚目 313字 ／ 3枚目 126字 ／ 4枚目 138字 ／ 5枚目 151字 ／ 6枚目 135字 ／ 7枚目 153字 ／ 8枚目 161字 ／ 9枚目 138字 ／ 10枚目 144字
OK 積んだ: x-blog-20261124-xmas-market-hikaku
```

## 3. 11/19 12:08 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-xmas-market-hikaku-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-xmas-market-hikaku-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-xmas-market-hikaku-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-xmas-market-hikaku-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
