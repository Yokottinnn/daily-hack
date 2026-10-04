# follow-balance の猶予を 7 日 → 1 日（24 時間）に戻す（2026-10-04 14:53 JST・$0）

**このレポートが作られた時刻: 2026-10-04 14:53:32 JST**

## 1. 変える前

```
  GRACE_DAYS（plist）: 1
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
    		MIN_UNFOLLOW => 20
    		GRACE_DAYS => 1
    		DECIDE_BUDGET_S => 150
    		LIST_BUDGET_S => 110
    		MAX_UNFOLLOW => 20
```

## 4. その場で 1 回 走らせる（18:45 を待たない）

```
  kickstart rc=0 
