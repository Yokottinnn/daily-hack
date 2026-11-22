# 返信の緊急停止と、除外の仕組みの確定（2026-08-23T08:45:22Z）

## 1. 停止（最優先。調べる前に止める）

- ai.openclaw.comment-warmup: **停止した**
- ai.openclaw.incoming-reply-watcher: **停止した**
- ai.openclaw.auto-thread-chainifier: **停止した**

### 停止の確認（launchctl の実体）
  ai.openclaw.comment-warmup                 停止
  ai.openclaw.incoming-reply-watcher         停止
  ai.openclaw.auto-thread-chainifier         停止

### フォロー系は止めていない（返信を打たないため）
  ai.openclaw.badge-followback                     稼働
  ai.openclaw.competitor-follower-follow           稼働
  ai.openclaw.hashtag-follow                       稼働
  ai.openclaw.auto-detect-and-unfollow-inactive    稼働

### 勝手に戻すジョブがいないか

> 2026-08-15 に、bootout したはずの comment-warmup が載り続けた実績がある。
  - com.dailyhack.rc-keeper
  - ai.openclaw.slack-watchdog
  - ai.openclaw.tab-guard
  - ai.openclaw.seo-health

## 2. 除外リストらしき data / state ファイル

- data/bookmark-learnings.json: dict keys=analyses  更新=08-03 09:30
- data/engagement_log.json: dict keys=engagements, stats  更新=08-08 18:01
- data/grok-trending-state.json: dict keys=created_at, last_run_at, query_index, query_pool, picked_urls, posted_ids, cost_history  更新=08-08 08:02
- data/incoming-replies-handled.json: dict keys=handled, chain_counts  更新=08-10 00:06
- data/incoming-reply-state.json: dict keys=seen_reply_ids, auto_replies, replied_authors_24h  更新=08-23 17:36
- data/refollow-blacklist.json: dict keys=handles, count, last_updated  更新=08-02 20:45
- data/unfollow-whitelist.json: dict keys=version, description, last_updated, whitelist, notes  更新=07-19 23:06
（該当なしなら空）

## 3. 返信対象を選ぶスクリプトの除外判定

### comment-warmup.js: 存在しない

### comment-orchestrator.sh（169 行）
除外に関わる行:
3:# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
81:const ids = j.queue.filter(x => x.id && x.id.startsWith('comment-') && x.template_id).slice(-5).map(x => x.template_id).reverse();
138:      log "  follow @$AUTHOR: skipped (already in reply-followers.json)"
164:    log "  follow skipped: daily cap ($REPLY_FOLLOW_DAILY_CAP) reached"
読み込むリスト:
data/post_queue.json
data/reply-followers.json

### asuka-fill.js（169 行）
除外に関わる行:
28:const SYSTEM = `あなたは「あんたバカぁ？まだ損してるの？速報💸」(@heng_ji31590) の返信生成エンジン。
87:  const recentIds = (process.env.RECENT_TEMPLATE_IDS || "").split(",").filter(Boolean);
95:  const t16Count = recentFamilies.filter(f => f === "T16").length;
109:  const usable = templates.filter(t => !recentFamilySet.has(family(t.id)));
読み込むリスト:
data/comment-templates.json

### incoming-reply-watcher.js（270 行）
除外に関わる行:
16:const X_USERNAME = "heng_ji31590";
109:  const recent = queue.queue.filter(e =>
120:  const todayAutoReplies = state.auto_replies.filter(a => a.posted_at && a.posted_at.startsWith(today)).length;
169:      log(`  daily cap reached, skipping rest`);
172:    // Skip too short replies (likely 顔文字 or spam)
173:    if (r.text.length < 5) { log(`  skip @${r.author}: text too short`); continue; }
177:      log(`  skip @${r.author}: already auto-replied within 24h`);
197:          incoming_reply_id: r.reply_id,
198:          incoming_reply_author: r.author,
209:        // follow-handle.js 経由、既 follow なら skip される、失敗してもメイン flow 続行
224:                  incoming_reply_id: r.reply_id,
230:            log(`    👤 follow skip/fail: ${followRes.reason || followRes.error || "unknown"}`);
読み込むリスト:
data/incoming-reply-state.json
data/post_queue.json
data/reply-followers.json

### _cmr.js（17 行）
除外に関わる行:
7:  await page.goto("https://x.com/heng_ji31590/with_replies", {waitUntil: "commit", timeout: 30000}).catch(e => console.log("nav err", e.me
読み込むリスト:

### auto-thread-chainifier.js（83 行）
除外に関わる行:
44:  const targets = queue.queue.filter(e =>
48:    !["posted", "posted_pre_queue", "skipped_text_too_long", "skipped_v3_redraft", "cancelled_redundant", "skipped_consecutive_errors"].i
読み込むリスト:
data/post_queue.json


## 4. NG 語彙の仕組みが既にあるか

> 語そのものは出さず、**あるかどうかと件数だけ**。
- test-vertex-imagen.js: 1 箇所

## 5. 返信相手をどこから拾っているか

### comment-orchestrator.sh
35:# 進捗行やエラー行 (例: "hashtag 還元 failed: timeout 12000ms") を出すと SyntaxError で
42:  try{const o=JSON.parse(line);console.log(JSON.stringify(o.candidates||[]));}
47:  log "no candidates"
71:log "picked $N_PICKED / max $MAX_PICKS (from $N candidates)"
73:  log "all candidates in cooldown"

### _cmr.js
10:    const t = a.querySelector('[data-testid="tweetText"]');
11:    const timeEl = a.querySelector("time");
12:    const links = Array.from(a.querySelectorAll('a[href*="/status/"]')).slice(0, 2).map(l => l.getAttribute("href"));

