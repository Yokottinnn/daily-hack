# mutual-prune の猶予を 14 日 → 1 日（24 時間）にする（2026-10-04 14:53 JST・$0）

**このレポートが作られた時刻: 2026-10-04 14:53:29 JST**

## 1. 変える前

```
  GRACE_DAYS（plist）: 14
  いまの状態: not running
```

## 2. 書き換える

```
  GRACE_DAYS rc=0  → ファイル上の値 1
  plutil -lint → OK
```

## 3. 載せ直す（bootout → bootstrap）

```
  bootstrap rc=0 
  → 載っている
  --- launchd が持っている値（← これが証拠）---
    		RATIO => 0.20
    		GRACE_DAYS => 1
    		ABS_MIN => 300
    		INACTIVE_DAYS => 30
    		MAX_UNFOLLOW => 8
```

- **launchd が GRACE_DAYS=1 を持っている。** 次の 18:00 から 24 時間で判定する（走らせていない）
- 1 回 8 件・休眠 30 日・小さいアカウントの基準は変えていない
- 戻すときは plist の GRACE_DAYS を 14 にして bootout → bootstrap

**外していない。フォローしていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
