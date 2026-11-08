# ふるさと納税サイト比較の告知を予約する（2026-11-08 21:57:29 JST・$0）

## 0. 予約時刻
```
  JST 2026-11-11 12:00 ／ UTC 2026-11-11T03:00:00.000Z ／ いまから 3723 分後
```

## 1. 画像 4 枚を origin/main から取る
```
  1-ban.jpg          141030 bytes
  2-points.jpg       136907 bytes
  3-anapay.jpg       127498 bytes
  4-steps.jpg        172698 bytes
  対象 4 枚 / 取れた 4 枚
```

## 2. 文面を確かめて積む
```
  [1/2] 文字 155 ／ 重み 275
  [2/2] 文字 199 ／ 重み 253
OK 積んだ: x-blog-20261111-furusato
```

## 3. 11/11 12:00 に 1 回だけ走るジョブ
```
  bootstrap rc=0 
```

## 4. 載ったことの証拠（print で見る）
```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-furusato-portal-comparison-2026-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 取り消すとき
```bash
  launchctl bootout gui/501/com.dailyhack.publish-furusato-portal-comparison-2026-oneshot; rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-furusato-portal-comparison-2026-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-furusato-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させない。**
