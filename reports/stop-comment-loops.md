# 返信ループを止める（2026-09-25 22:28 JST・$0）

**このレポートが作られた時刻: 2026-09-25 22:28:25 JST**

> **投稿は消していない。** 消すかどうかは利用者が決める。
> フォロー系・監視系のループは触っていない。

## 1. 止める前の状態

```
  ai.openclaw.comment-warmup             **載っている**  	state = not running 	runs = 11 	last exit code = 0 		state = active 		state = active 
  ai.openclaw.comment-orchestrator       載っていない
```

plist の在りか:

```
  ai.openclaw.comment-warmup.plist               あり (1354 bytes)
  ai.openclaw.comment-orchestrator.plist         **無い**
```

## 2. 止める（`bootout` → plist を `.disabled` にリネーム）

```
  ===== ai.openclaw.comment-warmup =====
    bootout rc=0  
    リネーム: ai.openclaw.comment-warmup.plist -> ai.openclaw.comment-warmup.plist.disabled
  ===== ai.openclaw.comment-orchestrator =====
    plist が無いので何もしない
```

## 3. 止まったことの証拠（**rc ではなく `print` で見る**）

**`print` が通らなくなっていれば止まっている。** 通るなら止まっていない。

```
  ai.openclaw.comment-warmup             止まった（print が通らない）
  ai.openclaw.comment-orchestrator       止まった（print が通らない）
  ---
  止まっていないもの: 0 件
```

載せ直しの対象から外れたか（**`.plist` で終わらなければ対象外**）:

```
  ai.openclaw.comment-warmup.plist               無い（対象外になった）
  ai.openclaw.comment-warmup.plist.disabled      あり
  ai.openclaw.comment-orchestrator.plist         無い（対象外になった）
  ai.openclaw.comment-orchestrator.plist.disabled -
```

## 4. 触っていないもの

**返信を出すループは、もう 1 本 ある。** 今回は指示の範囲外なので触っていない。

```
  ai.openclaw.incoming-reply-watcher         載ったまま
  ai.openclaw.badge-followback               載ったまま
  ai.openclaw.reply-followback-check         載ったまま
```

> `incoming-reply-watcher` は**自分宛の返信に返す**ループ。同じ不具合を踏みうる。
> **止めるかどうかは利用者の判断。**

## 5. 戻すとき

```bash
  mv "/Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist.disabled" "/Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist"
  launchctl bootstrap gui/501 "/Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist"
  launchctl print gui/501/ai.openclaw.comment-warmup     # ← **これが通れば戻っている**
  mv "/Users/ny/Library/LaunchAgents/ai.openclaw.comment-orchestrator.plist.disabled" "/Users/ny/Library/LaunchAgents/ai.openclaw.comment-orchestrator.plist"
  launchctl bootstrap gui/501 "/Users/ny/Library/LaunchAgents/ai.openclaw.comment-orchestrator.plist"
  launchctl print gui/501/ai.openclaw.comment-orchestrator     # ← **これが通れば戻っている**
```

**`bootstrap` の 2 回目は rc=5 になる。** それは「もう載っている」印で、失敗ではない。

## 6. 費用

**このタスク自体は launchd を触るだけで LLM を呼ばない（$0）。**
止めたことで**減る**額は次のとおり（`docs/recurring-job-costs.md` の実測から）。

| | 止める前（実測） | 止めた後 |
| --- | --- | --- |
| 1 回あたり | 約 $0.0048 | **$0** |
| 1 日あたり | **$0.081** | **$0** |
| 1 か月あたり | **約 $2.43** | **$0** |

> 出典は 2026-09-21 の `pipeline-heartbeat` 自己計測（`cost_24h_usd $0.081`）。
> **これは comment 系ループぶん。** 記事リフレッシュ（約 $1.33/月・実測）は別で、止めていない。
