# comment-warmup を常駐に戻す（2026-09-27 17:15 JST）

**このレポートが作られた時刻: 2026-09-27 17:15:16 JST**

> **量は変えない。** `MAX_PICKS_PER_FIRE` は plist の値のまま。
> **費用: $0.00417／件・実測 $0.081／日・約 $2.43／月**（増額。2026-09-27 に指示）

## 1. 戻す前の状態

```
  載っていない（止まったまま。想定どおり）
  ai.openclaw.comment-warmup.plist               無い
  ai.openclaw.comment-warmup.plist.disabled      あり（1354 bytes）
```

## 2. 守りを**正しいファイル**で数える

**`x166` は `engage-via-playwright.js` を見て 0 と出した。** 入っているのは
`post-comment.js` のほう。12:00 の publisher ログの `[x154] like 付いた` がその証拠。

```
  ===== post-comment.js（361 行）=====
    x150 ① 返信先ページに居るか   2 箇所
    x150 ② フォーカスが載ったか   2 箇所
    x150 ③ 打った文の照合         1 箇所
    x154    いいねを付ける        8 箇所
  ===== engage-via-playwright.js（176 行）=====
    x150 ① 返信先ページに居るか   0 箇所
    x150 ② フォーカスが載ったか   0 箇所
    x150 ③ 打った文の照合         0 箇所
    x154    いいねを付ける        0 箇所
```

**`post-comment.js` 側が 4 つとも 1 以上なら、守りは生きている。**

## 3. 名前を戻して載せる

```
  リネーム: ai.openclaw.comment-warmup.plist.disabled -> ai.openclaw.comment-warmup.plist

  bootstrap rc=0 
  （**rc=5 Input/output error は「もう載っている」の出方**。消えた証拠ではない）
```

## 4. 載ったことの証拠（**`list | grep` では足りない**）

```
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist
    	state = not running
    	program = /bin/bash
    	runs = 0
    	last exit code = (never exited)
    → **載っている。再開した。**
```

## 5. どの設定で動くか（**費用の根拠**）

```
  Array {
      Dict {
          Hour = 16
          Minute = 0
      }
      Dict {
          Hour = 12
          Minute = 0
      }
      Dict {
          Hour = 22
          Minute = 0
      }
      Dict {
          Hour = 19
          Minute = 0
      }
  }
  Dict {
      MIN_LIKES = 2
      MAX_AGE_HOURS = 18
      MAX_PICKS_PER_FIRE = 6
      REPLY_FOLLOW_DAILY_CAP = 30
  }
```

**`MAX_PICKS_PER_FIRE` が 6 で発火が 4 回なら 24 picks/日** ＝ 2026-09-21 の
自己計測（**実測 $0.081／日**）と同じ条件。**数字が違っていたら、費用も変わる。**

## 6. 載せ直しの対象になっているか

**tab-guard は `ai.openclaw.*` を一斉に外す。** 30 分ごとに戻す側に載っているか。

```
  ai.openclaw.comment-warmup は autoload-jobs.txt に **在る**（30 分ごとに載せ直される）
```

## 7. 直近のログ（**戻した直後なので、まだ動いていないのが普通**）

```
  更新 09-25 22:05 / 673722 bytes

  [2026-09-25T22:05:16]   follow @<伏せ>: filtered
  [2026-09-25T22:05:16] --- processing #6/6 for @<伏せ> ---
  [2026-09-25T22:05:19]   → chosen template_id: unknown
  [2026-09-25T22:05:19] enqueue: {"ok":true,"id":"comment-20260925-2205-5"}
  {"ok":true,"entry_id":"comment-20260925-2205-5","x_tweet_id":"2103470956677398659","url":"https://x.com/heng_ji31590/status/2103470956677398659","slack_report_ts":"silenced"}
  [2026-09-25T22:05:39]   follow @<伏せ>: followed
  [2026-09-25T22:05:39]   recorded in reply-followers.json (count now 16/30)
  [2026-09-25T22:05:39] === orchestrator done: 6 drafts, 16 reply-connected follows today ===
```

---

## 読み方

| §4 の出方 | 意味 |
| --- | --- |
| **載っている** ＋ `path` が `.plist`（`.disabled` でない） | **再開した。** 次の発火時刻から動く |
| 載っていない | **再開していない。** bootstrap の出力を読む |

| §2 の出方 | 意味 |
| --- | --- |
| `post-comment.js` が 4 つとも 1 以上 | **守りは生きている** |
| `post-comment.js` にも 0 が在る | **守りが消えている。** 入れ直しが要る（**戻したことは伝える**） |

**費用: $0.00417／件・実測 $0.081／日・約 $2.43／月。**
運用全体では約 $4.5／月（記事リフレッシュの実測 約 $1.33／月 を含む）。
