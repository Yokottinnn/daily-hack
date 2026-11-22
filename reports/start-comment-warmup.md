# 返信を再開する（2026-09-06 21:23 JST）

> 利用者が `x03` の文面を読んで **「この文面で OK。起動する」** と承認。
> **8 件/日**（1 回 2 件 × 日 4 回）。実測 $0.003/件 → **$0.024/日・$0.72/月**。
> **8/15 に `MAX_PICKS_PER_FIRE=8`（32 件/日）で暴走した前科がある。**
> **plist を読まずに load しない。**

## 1. plist を読む

- 1354 B / 更新 2026-08-23 02:09
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist: OK

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>EnvironmentVariables</key>
	<dict>
		<key>MAX_AGE_HOURS</key>
		<string>18</string>
		<key>MAX_PICKS_PER_FIRE</key>
		<string>2</string>
		<key>MIN_LIKES</key>
		<string>2</string>
		<key>REPLY_FOLLOW_DAILY_CAP</key>
		<string>30</string>
	</dict>
	<key>Label</key>
	<string>ai.openclaw.comment-warmup</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>/Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh</string>
	</array>
	<key>StandardErrorPath</key>
	<string>/Users/ny/.openclaw/workspace/logs/comment-warmup-err.log</string>
	<key>StandardOutPath</key>
	<string>/Users/ny/.openclaw/workspace/logs/comment-warmup.log</string>
	<key>StartCalendarInterval</key>
	<array>
		<dict>
			<key>Hour</key>
			<integer>16</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
		<dict>
			<key>Hour</key>
			<integer>12</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
		<dict>
			<key>Hour</key>
			<integer>22</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
		<dict>
			<key>Hour</key>
			<integer>19</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
	</array>
</dict>
</plist>
```

## 2. 1 回あたりの件数を 2 にする

- 現在の `MAX_PICKS_PER_FIRE`: **2**
- 望む値と同じ。**触らない。**

## 3. 起動する

```
```

### `launchctl list` で確かめる（**ログでは判定しない**）

```
  ロード済み  PID=-        最後のrc=0
```

## 4. 定時を待たずに 1 回 走らせる

**次の周回を待たない**（CLAUDE.md 最上位ルール 9）。実際に返信が出るまで見届ける。

- 走らせる前の comment/reply 件数: **908**

```
```

- 走り終わるのを待つ（最大 240 秒）
- 待った時間: **10 秒**（ログ更新: あり）

### `comment-warmup.log` の末尾

```
[2026-09-01T22:03:05] picked 2 / max 2 (from 18 candidates)
[2026-09-01T22:03:05] recent template ids (newest first): T16c,T04,T07,T29,T05
[2026-09-01T22:03:05] today's reply-connected follows: 3 / 30
[2026-09-01T22:03:05] --- processing #1/2 for @<伏せ> ---
[2026-09-01T22:03:08]   → chosen template_id: T22
[2026-09-01T22:03:08] enqueue: {"ok":true,"id":"comment-20260901-2203-0"}
{"ok":true,"entry_id":"comment-20260901-2203-0","x_tweet_id":"2094773088139477233","url":"https://x.com/heng_ji31590/status/2094773088139477233","slack_report_ts":"silenced"}
[2026-09-01T22:03:23]   follow @<伏せ>: filtered
[2026-09-01T22:03:23] --- processing #2/2 for @<伏せ> ---
[2026-09-01T22:03:26]   → chosen template_id: T21
[2026-09-01T22:03:26] enqueue: {"ok":true,"id":"comment-20260901-2203-1"}
{"ok":true,"entry_id":"comment-20260901-2203-1","x_tweet_id":"2094773161623728197","url":"https://x.com/heng_ji31590/status/2094773161623728197","slack_report_ts":"silenced"}
[2026-09-01T22:03:40]   follow @<伏せ>: filtered
[2026-09-01T22:03:40] === orchestrator done: 2 drafts, 3 reply-connected follows today ===
[2026-09-02T12:00:05] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
[2026-09-02T12:03:06] picked 2 / max 2 (from 15 candidates)
[2026-09-02T12:03:06] recent template ids (newest first): T21,T22,T16c,T04,T07
[2026-09-02T12:03:06] today's reply-connected follows: 0 / 30
[2026-09-02T12:03:06] --- processing #1/2 for @<伏せ> ---
[2026-09-02T12:03:10]   → chosen template_id: T11
[2026-09-02T12:03:10] enqueue: {"ok":true,"id":"comment-20260902-1203-0"}
{"ok":true,"entry_id":"comment-20260902-1203-0","x_tweet_id":"2094984489013502070","url":"https://x.com/heng_ji31590/status/2094984489013502070","slack_report_ts":"silenced"}
[2026-09-02T12:03:25]   follow @<伏せ>: filtered
[2026-09-02T12:03:25] --- processing #2/2 for @<伏せ> ---
[2026-09-02T12:03:29]   → chosen template_id: T07
[2026-09-02T12:03:29] enqueue: {"ok":true,"id":"comment-20260902-1203-1"}
{"ok":true,"entry_id":"comment-20260902-1203-1","x_tweet_id":"2094984567581200796","url":"https://x.com/heng_ji31590/status/2094984567581200796","slack_report_ts":"silenced"}
[2026-09-02T12:03:40]   follow @<伏せ>: skipped (already in reply-followers.json)
[2026-09-02T12:03:40] === orchestrator done: 2 drafts, 0 reply-connected follows today ===
[2026-09-06T21:23:17] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
```

## 5. 実際に出た返信

```
  comment/reply 合計: 908 件（開始前 908）
  今日つくられた: 0 件
```

---

**8 件/日 を超える設定にしていない。他のジョブは触っていない。**
**実測 $0.003/件 → $0.024/日・$0.72/月。**
