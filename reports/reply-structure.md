# 実機の構造（2026-08-22T09:06:42Z）

## scripts ディレクトリ
_cmr.js
_cmr.js.bak18800
a8net_login.js
a8net_login.js.bak.20260607-cdp
a8net_login.js.bak18800
anthropic-client.js
asuka-fill.js
asuka-fill.js.bak.20260515-v2
asuka-fill.js.bak.20260720-layer1
asuka-gen.js
asuka-gen.js.bak.20260527-dm
asuka-gen.js.bak.20260613-hook-sentence
asuka-gen.js.bak.20260704-ufffd
asuka-gen.js.bak.20260712-comment-variety-off
audit-wrong-unfollows.js
audit-wrong-unfollows.js.bak18800
auto-blog-promo-publisher.js
auto-blog-promo-publisher.js.bak.20260725-notify-batch2
auto-gen-card.js
auto-reply.js
auto-reply.js.bak.20260720-layer3
auto-reply.js.bak.20260725-notify-batch2
auto-reply.js.bak.20260726-silence-enforce
auto-thread-chainifier.js
auto-x-publisher.js
auto-x-publisher.js.bak.20260609-notif
auto-x-publisher.js.bak.20260725-notify-batch2
auto_detect_and_unfollow_inactive.js
badge-followback.js
badge-followback.js.bak.20260725-notify-batch2
badge-followback.js.bak.20260726-silence-enforce
badge-followback.js.bak18800
batch_activity_update.js
batch_scan_accounts.js
blog-rss-watcher.js
blog-rss-watcher.js.bak.20260528-cover
blog-thread-builder.js
blog-thread-builder.js.bak.20260515-pre-newtemplates
blog-thread-builder.js.bak.20260521-2chain
bookmark-analyzer.js

## incoming-reply-watcher.js
行数: 270

### 関数と入口
23:function log(s) { try { fs.appendFileSync(LOG_PATH, `[${new Date().toISOString()}] ${s}\n`); } catch {}; console.log(s); }
25:function slackPost(text) {
35:function loadState() {
42:function saveState(s) {
78:async function generateAutoReply(originalPostText, incomingReply) {
105:async function main() {

### 環境変数の参照（キー名のみ）
process.env.CHROME_CDP_URL

### 読み書きしているファイル
data/incoming-reply-state.json
data/post_queue.json
data/reply-followers.json
logs/incoming-reply-watcher.log

## asuka-fill.js
行数: 169

### 関数と入口
18:function weightOf(s) {
24:function loadTemplates() {
85:async function fill(trend) {
157:async function main() {

### 環境変数の参照（キー名のみ）
process.env.RECENT_TEMPLATE_IDS

### 読み書きしているファイル
data/comment-templates.json

## comment-warmup.js
（存在しない）

## quick-reply-watcher.js
行数: 160

### 関数と入口
40:function log(msg) {
46:function loadJson(p, fallback) {
50:function saveLog(entries) {
56:const todayStr = () => new Date().toISOString().slice(0, 10);
58:async function main() {

### 環境変数の参照（キー名のみ）
process.env.CHROME_CDP_URL
process.env.DRY_RUN
process.env.QUICK_REPLY_DAILY_CAP
process.env.QUICK_REPLY_WINDOW_MIN

### 読み書きしているファイル
data/quick-reply-log.json
data/quick-reply-targets.json
logs/quick-reply-watcher.log

## 状態ファイルのキー（値は出さない）
- auto-reply-fail-streak.json: count, last_fail_at, last_reason
- automation-window.json: windowId, task, createdAt
- badge-followback-state.json: processed, followed_back, initialized
- blog-rss-state.json: seen_urls, articles
- bookmark-learnings.json: analyses
- bookmark-state.json: bookmarks, last_scraped_at
- canary-state.json: last_alert
- chrome-pid.json: pid, ts
- comment-state.json: rollout_started_at, targets, daily_counts, hourly_counts, recent_negative_signals, paused, pause_reason
- comment-templates.json: list len=37
- dm-state.json: conversations
- engagement_log.json: engagements, stats
- follow-watchdog-state.json: ts, severity, counts, src24, src72, reasons, self_heal_steps, notified
- followed.json: followed, stats
- follower-daily-report-state.json: last_run, consec_behind, last_pace_actual
- follower-history.json: snapshots
- follower-target-config.json: version, target, deadline, baseline_count, baseline_date
- grok-trending-state.json: created_at, last_run_at, query_index, query_pool, picked_urls, posted_ids, cost_history
- guardian-state.json: lastAlertSig, lastAlertAt, loginDay, loginCount, lastLoginAt
- image-library.json: version, description, image_dir, fallback_image, skip_threshold, images
- inactive_accounts_batch.json: timestamp, threshold_days, total_inactive, accounts
- incoming-replies-handled.json: handled, chain_counts
- incoming-reply-state.json: seen_reply_ids, auto_replies, replied_authors_24h
- influencers.json: _doc, _last_updated, _notes, handles, _kabu_st0ck_disabled_at, _kabu_st0ck_disabled_reason
- kpi-history.json: months
- past-article-qt-state.json: qt_history
- pipeline-heartbeat-state.json: last_alert, heal_history, last_run_at
- post-metrics.json: snapshots
- post_queue.json: meta, queue
- protected-windows.json: protected, recordedAt, note
- quick-reply-targets.json: _note, _selected_at, targets
- recent-hooks-state.json: trend_post, comment, trend_qt
- refollow-blacklist.json: handles, count, last_updated
- reply-followers.json: mao_otk_tw, cpaky1, sukesankoba, fxmeitantei, feldoman0504, STARPayment07, Kimama_FIRE, hirouma888, gurisusan, furunavi_PR, kageyoshi_maki, harunorikujyou
- scheduled-entry-watchdog-state.json: alerted
- selfback_programs.json: scraped_at, total_programs, programs
- slack-notify-dedup.json: 8f746198ea25, 6bb5d6884ed8, f60ebcc2e1a1, 5c8e6f9f2ea9, b1e65fa3ca87, 92f0977336c0, c7c528255060, 144fb736e723
- tab-guard-state.json: count, at
- trend-cache.json: seen_urls, latest_success
- unfollow-cleanup-state.json: version, phase, started_at, target_ratio_phase_a, current_ratio, unfollow_log, tier_snapshot, halt_flags, note
- unfollow-whitelist.json: version, description, last_updated, whitelist, notes
- unfollow_batch.json: timestamp, total_inactive, accounts
- v3-watchdog-state.json: alerted_ids
- x-login-escalate.json: last_escalated_at, escalate_count, last_symptom_hash, last_recovered_at
- x-login-state.json: last_verified_at, status, last_recovery_at

## ログの書式（直近3行・先頭80字）

> **20 文字以上の連続した英数字は伏せている。** ログに値が入っていると
> そのまま公開リポジトリに載るため（検証中に実際に漏れた）。
### comment-warmup.log
{"ok":true,"entry_id":"<MASKED>","x_tweet_id":"2091058722823110892","url":"https
[2026-08-22T16:03:50]   follow @koya0tly: filtered
[2026-08-22T16:03:50] === orchestrator done: 2 drafts, 0 reply-connected follows
### incoming-reply-watcher.log
[2026-08-22T09:05:43.372Z] scanning 8 recent posts
[2026-08-22T09:05:43.375Z] today's auto-replies: 2 / 20
[2026-08-22T09:06:12.947Z] no new replies
