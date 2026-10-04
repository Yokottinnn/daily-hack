# follow-balance の猶予を 7 日 → 1 日（24 時間）に戻す（2026-10-04 18:11 JST・$0）

**このレポートが作られた時刻: 2026-10-04 18:11:06 JST**

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
  見ていた秒数 240 ← **240 秒 で見るのをやめた。走り続けている**（x237 で読む）

  [2026-10-04T09:11:07.156Z] === follow-balance start (dry=false min=20 max=20 grace=1d inactive=30d big=5000) ===
```

- **launchd が GRACE_DAYS=1 を持っている。** 以後の 11:45 / 18:45 も 24 時間で判定する
- 1 回に外すのは今までどおり 20 件まで（1 日 2 回）。比率の帯・ホワイトリストは変えていない
- 戻すときは plist の GRACE_DAYS を消して bootout → bootstrap

**フォローしていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
