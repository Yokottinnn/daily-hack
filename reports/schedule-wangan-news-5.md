# 湾岸ニュース5選を予約する（2026-11-03 22:22:37 JST・$0）

## 0. 予約時刻

```
  JST          2026-11-04 08:00
  scheduled_at 2026-11-03T23:00:00.000Z  (UTC)
  いまから      578 分後
```

## 1. 画像 2 枚を origin/main から取り直す

```
  1-cover.jpg        327318 bytes
  2-list.jpg         234766 bytes
  対象 2 枚 / 取れた 2 枚
```

## 2. 文面を origin/main から取り、利用者のレビューが入った版かを確かめて積む

```
  ALT: 1枚目 269字 ／ 2枚目 502字
  [1/2] レビュー済みの版 一致 ／ 文字 970 ／ 重み 1389 / 25000 ／ sha 681f961d277e
  [2/2] レビュー済みの版 一致 ／ 文字 154 ／ 重み 233 / 25000 ／ sha cf4476a46bf0
OK 積んだ: x-news-20261104-wangan-5
  rc=0
```

## 3. 8:00 に 1 回だけ走るジョブ

```
  bootstrap rc=0  
```

## 4. 載ったことの証拠（rc ではなく print で見る）

```
  	path = /Users/ny/Library/LaunchAgents/ai.openclaw.publish-wangan5-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 5. Chrome は健全か（予約時点の参考。8:00 に run-publish.sh が ensure-chrome を呼ぶ）

```
{"ok":true,"healthy":true,"round_trip_ms":2273,"product":"Chrome/140.0.7339.207","tabs":20}
  (rc=0)
```

## 取り消すとき

```bash
  launchctl bootout gui/501/ai.openclaw.publish-wangan5-oneshot
  rm -f "/Users/ny/Library/LaunchAgents/ai.openclaw.publish-wangan5-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-wangan5-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させないので、毎日の費用は増えない。**
