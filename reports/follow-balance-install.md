# ボタン待ちを直して plist を置く（2026-09-28 00:18 JST・$0）

**このレポートが作られた時刻: 2026-09-28 00:18:37 JST**

> **走らせない。** 本番の実行は `x184` が 1 回 だけ行う。
> **LLM を呼ばない（$0／回・$0／日・$0／月）。**

## 1. 置き換える

```
  書いたもの: 22007 bytes / 419 行
  node --check rc=0（打つ名前: .follow-balance-wait-20260928-001837.js）
```
```
  置いた: follow-balance.js（419 行）
  出るまで待つ処理      1 箇所（1 が正）
  理由を出す処理        1 箇所（1 が正）
  固定 3.5 秒 待ちの残り 0 箇所（0 が正）
  ONEWAY_IGNORE_ENGAGED 2 箇所 / process.exit(0) 10 箇所
```

## 2. plist を置いて載せる（**11:45 と 18:45**）

フォロー側は 11:30 / 18:30 に撃つ。**その後に外す。**

```
  bootstrap rc=0 
  （**rc=5 Input/output error は「もう載っている」の出方**）

  --- 載ったことの証拠（`list | grep` では足りない）---
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.follow-balance.plist
    	state = not running
    	program = /usr/local/bin/node
    	runs = 0
    	last exit code = (never exited)
    → **載っている**

  --- 起動時刻と環境変数（**上限が 8 のままか**）---
    Array {
        Dict {
            Hour = 11
            Minute = 45
        }
        Dict {
            Hour = 18
            Minute = 45
        }
    }
    Dict {
        MAX_PROFILE_READS = 40
        DECIDE_BUDGET_S = 150
        MIN_UNFOLLOW = 8
        LIST_BUDGET_S = 110
        HOME = /Users/ny
        MAX_UNFOLLOW = 8
        PATH = /usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
    }
```

## 3. 載せ直しの対象になっているか

**tab-guard は `ai.openclaw.*` を一斉に外す。** 一覧に在れば 30 分ごとに戻る。

```
  ai.openclaw.follow-balance は autoload-jobs.txt に **在る**（30 分ごとに載せ直される）
```

---

## 次の一手

| §1・§2 の出方 | 次 |
| --- | --- |
| 3 つとも正（待つ 1 / 理由 1 / 固定待ち 0）＋ **載っている** | **`x184` が本番 1 回 を走らせる** |
| 固定待ちが残っている | **置き換えが効いていない。** アンカーを見直す |
| 載っていない | `bootstrap` の出力を読む。**足す前に直す** |

**$0／回・$0／日（11:45 と 18:45 の 2 回）・$0／月。** LLM を呼ばない。
