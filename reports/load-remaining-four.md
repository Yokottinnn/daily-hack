# 載らなかった 4 本を載せる

**このレポートが作られた時刻: 2026-09-13 00:23:13 JST**

> `x33` で **CDP は 15 秒で健全化**し、**悪循環は断てた。**
> ジョブは **4 / 8 本**で、90 秒 経っても減っていない（＝もう外されていない）。
> **残り 4 本が載らない理由を、今度は全部 出す。**

## 0. いまの状態

```
  **未**   comment-warmup                    
  ロード   competitor-follower-follow        
  ロード   hashtag-follow                    
  ロード   badge-followback                  
  ロード   reply-followback-check            
  **未**   reply-followers-cleanup           
  **未**   incoming-reply-watcher            
  **未**   pipeline-heartbeat                
  → 4 / 8 本

  CDP: 健全
  tab-guard: 1 本
```

## 1. 無効化されていないか

```
  		"ai.openclaw.pipeline-heartbeat" => enabled
  		"ai.openclaw.comment-warmup" => enabled
  		"ai.openclaw.incoming-reply-watcher" => enabled
  		"ai.openclaw.reply-followers-cleanup" => enabled
  ---（"=> true" なら **無効化されている**）---
```

## 2. 4 本それぞれを、理由つきで載せる

### `comment-warmup`

```
  plist: /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist
  更新 : 2026-09-06 23:25 / 1354 B

  --- plutil -lint ---
    /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist: OK

  --- 中身（要点） ---
      "EnvironmentVariables" => {
        "MAX_AGE_HOURS" => "18"
        "MAX_PICKS_PER_FIRE" => "4"
        "MIN_LIKES" => "2"
        "REPLY_FOLLOW_DAILY_CAP" => "30"
      "Label" => "ai.openclaw.comment-warmup"
      "ProgramArguments" => [
        0 => "/bin/bash"
        1 => "/Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh"
      "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/comment-warmup-err.log"
      "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/comment-warmup.log"
      "StartCalendarInterval" => [
        0 => {
          "Hour" => 16

  --- launchctl の言い分（print） ---
    gui/501/ai.openclaw.comment-warmup = {
    	active count = 0
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist
    	type = LaunchAgent
    	state = not running
    
    	program = /bin/bash
    	arguments = {

  --- (a) launchctl load -w（エラー全文） ---
    Load failed: 5: Input/output error
    Try running `launchctl bootstrap` as root for richer errors.
    → 載ったか: 1 本

  --- (b) launchctl bootstrap（エラー全文） ---
    Bootstrap failed: 5: Input/output error
    Try re-running the command as root for richer errors.
    → 載ったか: 1 本

  --- (c) enable してから bootstrap ---
    Bootstrap failed: 5: Input/output error
    Try re-running the command as root for richer errors.
    → 載ったか: 1 本
```

### `reply-followers-cleanup`

```
  plist: /Users/ny/Library/LaunchAgents/ai.openclaw.reply-followers-cleanup.plist
  更新 : 2026-05-13 16:01 / 717 B

  --- plutil -lint ---
    /Users/ny/Library/LaunchAgents/ai.openclaw.reply-followers-cleanup.plist: OK

  --- 中身（要点） ---
      "Label" => "ai.openclaw.reply-followers-cleanup"
      "ProgramArguments" => [
        0 => "/usr/local/bin/node"
        1 => "/Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js"
      "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.err"
      "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.out"
      "StartInterval" => 3600

  --- launchctl の言い分（print） ---
    gui/501/ai.openclaw.reply-followers-cleanup = {
    	active count = 1
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.reply-followers-cleanup.plist
    	type = LaunchAgent
    	state = running
    
    	program = /usr/local/bin/node
    	arguments = {

  --- (a) launchctl load -w（エラー全文） ---
    Load failed: 5: Input/output error
    Try running `launchctl bootstrap` as root for richer errors.
    → 載ったか: 1 本

  --- (b) launchctl bootstrap（エラー全文） ---
    Bootstrap failed: 5: Input/output error
    Try re-running the command as root for richer errors.
    → 載ったか: 1 本

  --- (c) enable してから bootstrap ---
    Bootstrap failed: 5: Input/output error
    Try re-running the command as root for richer errors.
    → 載ったか: 1 本
```

### `incoming-reply-watcher`

```
  既にロード済み。触らない。
```

### `pipeline-heartbeat`

```
  plist: /Users/ny/Library/LaunchAgents/ai.openclaw.pipeline-heartbeat.plist
  更新 : 2026-07-25 16:03 / 1033 B

  --- plutil -lint ---
    /Users/ny/Library/LaunchAgents/ai.openclaw.pipeline-heartbeat.plist: OK

  --- 中身（要点） ---
      "Label" => "ai.openclaw.pipeline-heartbeat"
      "ProgramArguments" => [
        0 => "/bin/bash"
        1 => "-c"
        2 => "cd /Users/ny/.openclaw/workspace && /usr/local/bin/node scripts/pipeline-heartbeat.js"
      "RunAtLoad" => false
      "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/pipeline-heartbeat-err.log"
      "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/pipeline-heartbeat.log"
      "StartCalendarInterval" => [
        0 => {
          "Hour" => 8
          "Minute" => 0
        1 => {
          "Hour" => 20

  --- launchctl の言い分（print） ---
    gui/501/ai.openclaw.pipeline-heartbeat = {
    	active count = 0
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.pipeline-heartbeat.plist
    	type = LaunchAgent
    	state = not running
    
    	program = /bin/bash
    	arguments = {

  --- (a) launchctl load -w（エラー全文） ---
    Load failed: 5: Input/output error
    Try running `launchctl bootstrap` as root for richer errors.
    → 載ったか: 1 本

  --- (b) launchctl bootstrap（エラー全文） ---
    Bootstrap failed: 5: Input/output error
    Try re-running the command as root for richer errors.
    → 載ったか: 1 本

  --- (c) enable してから bootstrap ---
    Bootstrap failed: 5: Input/output error
    Try re-running the command as root for richer errors.
    → 載ったか: 1 本
```

## 3. 60 秒 待って、生き残るか

```
  20 秒後: 4 / 8 本
  40 秒後: 5 / 8 本
  60 秒後: 0 / 8 本

  **未**   comment-warmup                    
  **未**   competitor-follower-follow        
  **未**   hashtag-follow                    
  **未**   badge-followback                  
  **未**   reply-followback-check            
  **未**   reply-followers-cleanup           
  **未**   incoming-reply-watcher            
  **未**   pipeline-heartbeat                

  **最終: 0 / 8 本**
  CDP: 健全

  --- tab-guard のログ（この間に鳴ったか） ---
    [2026-09-12T13:29:49.861Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:59.929Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T15:24:13.329Z] 🚨 Jordan のタブが 1 → 0 枚（実質全消滅） → 自動化を全停止
    [2026-09-12T15:24:13.631Z] 停止完了
    [2026-09-12T15:24:13.633Z] 監視終了（要因を確認してください）
    [2026-09-12T15:24:13.662Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
```

---

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク**（LLM 不使用） | **$0** | **$0** | **$0** |
| フォロー・アンフォロー（DOM 操作） | **$0** | **$0** | **$0** |
| 返信（**実測** 9/8=5 件・9/9=3 件） | $0.003 | $0.009〜0.015 | 約 $0.27〜0.45 |

**Chrome を kill していない。投稿もしていない。**
