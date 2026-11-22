# フォロー比率の目標をフォロワー数で下げる・相互の整理の DRY（2026-10-12 22:54:25 JST・$0）

## ① follow-balance.js
```json
{"ok":true,"note":"書いた・node --check 通過"}
```
```
plist の値: 370:0.57,500:0.50,700:0.42,1000:0.33
	state = not running
		FOLLOW_RATIO_GLIDE => 370:0.57,500:0.50,700:0.42,1000:0.33
```

## ② mutual-prune の DRY（切り離して起動）

- 起動した（全件を判定する。198 件 × 5〜6 秒で 20 分ほど。ログ `logs/x284-mutual-dry.log`）

**外していない（DRY）。LLM を呼んでいない（$0／回・$0／日・$0／月）。** 戻すときは follow-balance.js.bak-x284 と plist の .bak-x284。
