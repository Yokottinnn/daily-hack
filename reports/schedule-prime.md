# 感謝祭 vs お買い物マラソンを予約する（2026-10-18 00:12:16 JST・$0）

## 0. 予約時刻

```
  JST          2026-10-18 12:00
  scheduled_at 2026-10-18T03:00:00.000Z  (UTC)
  いまから      708 分後
```

## 1. 画像 4 枚を origin/main から取り直す

```
  1-deadline.jpg     219333 bytes
  2-rules.jpg        185702 bytes
  3-which.jpg        168168 bytes
  4-next.jpg         140816 bytes
  対象 4 枚 / 取れた 4 枚
```

## 2. 文面を origin/main から取り、ロックのハッシュと照合して積む

```
  [1/2] ロック 一致 ／ 文字 1325 ／ 重み 2376 / 25000
  [2/2] ロック 一致 ／ 文字 133 ／ 重み 131 / 25000
OK 積んだ: blog-promo-20261018-prime-vs-rakuten
  rc=0
```

## 3. 12:00 に 1 回だけ走るジョブ

```
  bootstrap rc=0  
```

## 4. 載ったことの証拠（rc ではなく print で見る）

```
  	path = /Users/ny/Library/LaunchAgents/ai.openclaw.publish-prime-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 5. Chrome は健全か（予約時点の参考。12:00 に run-publish.sh が ensure-chrome を呼ぶ）

```
{"ok":true,"healthy":true,"round_trip_ms":2291,"product":"Chrome/140.0.7339.207","tabs":7}
  (rc=0)
```

## 取り消すとき

```bash
  launchctl bootout gui/501/ai.openclaw.publish-prime-oneshot
  rm -f "/Users/ny/Library/LaunchAgents/ai.openclaw.publish-prime-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-prime-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させないので、毎日の費用は増えない。**
