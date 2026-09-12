# 載らない 4 本の理由（**rc は見ない**）

**このレポートが作られた時刻: 2026-09-13 01:19:08 JST**

> 最上位ルール 13: **`rc=0` は「やった」証拠にならない。**
> 判定は **`launchctl list` に出るか** の 1 点だけで行う。

## 0. いまの状態

```
  3 ループの 8 本   : 5 / 8 本
  ai.openclaw.* 全体: 9 本
  tab-guard         : 1 本
  CDP               : 健全
  login ロック      : **有る**（ensure-chrome が no-op になる）
```

## 1. 8 本を 1 本ずつ見る

### `comment-warmup`

```
  **ロード済み。触らない。**
    	"LastExitStatus" = 0;
```

### `competitor-follower-follow`

```
  **ロード済み。触らない。**
    	"LastExitStatus" = 0;
```

### `hashtag-follow`

```
  **ロード済み。触らない。**
    	"LastExitStatus" = 0;
```

### `badge-followback`

```
  **ロード済み。触らない。**
    	"LastExitStatus" = 0;
```

### `reply-followback-check`

```
  **ロード済み。触らない。**
    	"LastExitStatus" = 0;
```

### `reply-followers-cleanup`

```
  plist   : 在る（717 bytes / 更新 2026-05-13 16:01）
  lint    : ai.openclaw.reply-followers-cleanup.plist: OK
  実行対象: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js 
    /usr/local/bin/node … 在る
    /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js … 在る

  --- launchctl print gui/501/ai.openclaw.reply-followers-cleanup ---
    gui/501/ai.openclaw.reply-followers-cleanup = {
    	active count = 0
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.reply-followers-cleanup.plist
    	type = LaunchAgent
    	state = not running
    
    	program = /usr/local/bin/node
    	arguments = {

  --- enable ---
  --- bootstrap ---
    Bootstrap failed: 5: Input/output error
    Try re-running the command as root for richer errors.

  **→ 載っていない。上の出力が理由。**
```

### `incoming-reply-watcher`

```
  **ロード済み。触らない。**
    	"LastExitStatus" = 0;
```

### `pipeline-heartbeat`

```
  plist   : 在る（1033 bytes / 更新 2026-07-25 16:03）
  lint    : ai.openclaw.pipeline-heartbeat.plist: OK
  実行対象: /bin/bash /Users/ny/.openclaw/workspace 
    /bin/bash … 在る
    /Users/ny/.openclaw/workspace … 在る

  --- launchctl print gui/501/ai.openclaw.pipeline-heartbeat ---
    gui/501/ai.openclaw.pipeline-heartbeat = {
    	active count = 0
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.pipeline-heartbeat.plist
    	type = LaunchAgent
    	state = not running
    
    	program = /bin/bash
    	arguments = {

  --- enable ---
  --- bootstrap ---
    Bootstrap failed: 5: Input/output error
    Try re-running the command as root for richer errors.

  **→ 載っていない。上の出力が理由。**
```

## 2. 30 秒後・90 秒後（**外されていないか**）

x34 では載った直後に tab-guard が外した。**時間を置いて数え直す。**

```
   30 秒 経過: 5 / 8 本
   60 秒 経過: 4 / 8 本

  **最終: 4 / 8 本**
  載っていない: comment-warmup reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat
```

### tab-guard が何か言ったか（直近 10 行）

```
  [2026-09-12T13:29:49.601Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
  [2026-09-12T13:29:49.639Z] 🚨 Jordan のタブが 14 → 1 枚（一括破壊） → 自動化を全停止
  [2026-09-12T13:29:49.860Z] 停止完了
  [2026-09-12T13:29:49.861Z] 監視終了（要因を確認してください）
  [2026-09-12T13:29:59.929Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
  [2026-09-12T15:24:13.329Z] 🚨 Jordan のタブが 1 → 0 枚（実質全消滅） → 自動化を全停止
  [2026-09-12T15:24:13.631Z] 停止完了
  [2026-09-12T15:24:13.633Z] 監視終了（要因を確認してください）
  [2026-09-12T15:24:13.662Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
  [2026-09-12T15:43:41.695Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
```

## 2-B. login ロックは**作られ直している**

`heartbeat.json`（2026-09-12 15:29Z）の実測。

```
  "login_lock": {"present": true, "age_hours": 0}
```

**9/12 の時点では 51 時間 だった。0 時間 に戻っている ＝ 誰かが作り直している。**
x26 は「age 0 時間」を見て**触らずに終えた**ので、ロックは残ったままになった。

ロックが在るあいだ `ensure-chrome.sh` は **rc=0 のまま何もしない**（最上位ルール 13）。

```
  パス      : /tmp/x-login-in-progress
  作成/更新 : 2026-09-13 00:24:13 （**56 分前**）
  中身      : tab-guard
  所有者    : ny

  --- ログイン処理が本当に走っているか ---
    x-login のプロセスは**無い**

  **30 分 以上 放置されていて、ログインも走っていない ＝ 死んだロック。外す。**
    → **外した**
    5 秒後: 無い（正常）
```

## 3. `comment-warmup` が載ったなら、待たずに走らせる

> 最上位ルール 9: **「次の定時実行を待つ」は、ほぼ全部 やらなくていい待ち。**

```
  comment-warmup が載っていない。**LLM を 1 回も呼ばずに終わる（$0）。**
```
