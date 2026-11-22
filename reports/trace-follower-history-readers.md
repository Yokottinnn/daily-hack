# follower-history.json を誰が読んでいるか（2026-09-21 13:10 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-21 13:10:27 JST**

> このファイルは **2026-05-23 で止まり、最後の行が `0 人` の誤読**（前日 51 人）。
> **信じる仕組みがあれば「フォロワー 0 人」と判断する。**
> **黙って消すと、読んでいた側が今度は「ファイルが無い」で落ちる。**
> だから先に読み手を洗う。**このタスクは消さない。読むだけ。**

## 1. ファイル自身

```
  path : /Users/ny/.openclaw/workspace/data/follower-history.json
  size : 1577 bytes / 73 行
  mtime: 2026-05-24 00:30:11
  --- 末尾 3 行 ---
        }
      ]
    }```

## 2. 名指ししているファイル

**`follower-history` という語で当たる。** 拡張子は問わない。

```
  --- /Users/ny/.openclaw/workspace/scripts ---
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260720-tab-overload
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260802-24h
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak18800
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260720-inline-refactor
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260725-notify-batch2
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js
  --- /Users/ny/.openclaw/workspace/ops ---
    （無し）
  --- /Users/ny/.openclaw/workspace ---
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260720-tab-overload
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260802-24h
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak18800
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260720-inline-refactor
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260725-notify-batch2
    /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js
  --- /Users/ny/Library/LaunchAgents ---
    （無し）
  --- /Users/ny/projects/anta-baka-x/blog（リポジトリ）---
    ops/tasks/004-inventory-follow-stack.sh
```

## 3. 読んでいるのか、書いているのか

**名前が出るだけでは足りない。** `readFileSync` なら読み手、
`writeFileSync` / `appendFileSync` なら書き手。**前後を出して見分ける。**

```
  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260720-tab-overload =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260802-24h =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak18800 =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260720-inline-refactor =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260725-notify-batch2 =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260720-tab-overload =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260802-24h =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak18800 =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260720-inline-refactor =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js.bak.20260725-notify-batch2 =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

  ===== /Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js =====
    33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
    34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
    35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
    36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
    37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;

```

## 4. 判断の材料（**このタスクでは決めない**）

| 出方 | 意味 |
| --- | --- |
| 該当が 1 件も無い | **消してよい。** 誰も読んでいない |
| 書き手だけ在る | **書き手が壊れている。** 4 か月 書けていない。直すか止めるか |
| 読み手が在る | **`0 人` を読んでいる。** `follower-snapshots/` の `count` に向け直す |

**`follower-snapshots/YYYY-MM-DD.json` の `count` が正しい記録**
（`followers` はハンドルの配列で人数ではない。docs/follower-tracking.md）。

## 5. 費用

**`grep` と `stat` だけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
