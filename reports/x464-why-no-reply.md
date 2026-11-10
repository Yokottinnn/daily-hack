# 相手の返信に返さなかった理由（2026-11-11 00:42:05 JST・読むだけ・$0）

## ① ログ・データに 2 つの ID が出てくるか
```
--- 2117613776182853984
--- 2116727000358646078
~/.openclaw/workspace/logs/publish-points-oneshot.log
~/.openclaw/workspace/data/x-impressions.jsonl
~/.openclaw/workspace/data/post_queue.json
```

## ② 11/3 22:40〜11/4 12:00 JST（13:40〜03:00 UTC）の incoming-reply-watcher の動き
```
[2026-11-03T13:05:37.759Z] scanning 22 recent posts
[2026-11-03T13:05:37.763Z] today's auto-replies: 6 / 20
[2026-11-03T13:07:10.589Z] no new replies
[2026-11-03T13:22:10.924Z] scanning 22 recent posts
[2026-11-03T13:22:10.928Z] today's auto-replies: 6 / 20
[2026-11-03T13:23:40.509Z] no new replies
[2026-11-03T13:38:40.908Z] scanning 22 recent posts
[2026-11-03T13:38:40.916Z] today's auto-replies: 6 / 20
[2026-11-03T13:40:04.968Z] no new replies
[2026-11-03T13:55:05.444Z] scanning 22 recent posts
[2026-11-03T13:55:05.447Z] today's auto-replies: 6 / 20
[2026-11-03T13:56:34.989Z] no new replies
[2026-11-03T14:11:35.327Z] scanning 22 recent posts
[2026-11-03T14:11:35.330Z] today's auto-replies: 6 / 20
[2026-11-03T14:13:02.881Z] no new replies
[2026-11-03T14:28:03.277Z] scanning 22 recent posts
[2026-11-03T14:28:03.286Z] today's auto-replies: 6 / 20
[2026-11-03T14:29:41.723Z] no new replies
[2026-11-03T14:44:42.407Z] scanning 22 recent posts
[2026-11-03T14:44:42.411Z] today's auto-replies: 6 / 20
[2026-11-03T14:46:12.235Z] no new replies
[2026-11-03T15:01:12.758Z] scanning 22 recent posts
[2026-11-03T15:01:12.766Z] today's auto-replies: 6 / 20
[2026-11-03T15:02:38.446Z] no new replies
[2026-11-03T15:17:39.080Z] scanning 22 recent posts
[2026-11-03T15:17:39.083Z] today's auto-replies: 6 / 20
[2026-11-03T15:19:03.040Z] no new replies
[2026-11-03T15:34:03.999Z] scanning 22 recent posts
[2026-11-03T15:34:04.005Z] today's auto-replies: 6 / 20
[2026-11-03T15:36:27.177Z] no new replies
[2026-11-03T15:51:27.918Z] scanning 22 recent posts
[2026-11-03T15:51:27.927Z] today's auto-replies: 6 / 20
[2026-11-03T15:53:13.491Z] no new replies
[2026-11-03T16:08:14.580Z] scanning 22 recent posts
[2026-11-03T16:08:14.583Z] today's auto-replies: 6 / 20
[2026-11-03T16:09:47.160Z] no new replies
[2026-11-03T16:24:47.563Z] scanning 22 recent posts
[2026-11-03T16:24:47.567Z] today's auto-replies: 6 / 20
[2026-11-03T16:26:17.319Z] no new replies
[2026-11-03T16:41:17.699Z] scanning 22 recent posts
[2026-11-03T16:41:17.707Z] today's auto-replies: 6 / 20
[2026-11-03T16:42:50.358Z] no new replies
[2026-11-03T16:57:50.716Z] scanning 22 recent posts
[2026-11-03T16:57:50.719Z] today's auto-replies: 6 / 20
[2026-11-03T16:59:23.562Z] no new replies
[2026-11-03T17:14:23.900Z] scanning 22 recent posts
[2026-11-03T17:14:23.904Z] today's auto-replies: 6 / 20
[2026-11-03T17:16:00.693Z] no new replies
[2026-11-03T17:31:01.043Z] scanning 22 recent posts
[2026-11-03T17:31:01.047Z] today's auto-replies: 6 / 20
[2026-11-03T17:36:30.839Z] no new replies
[2026-11-03T17:51:31.175Z] scanning 22 recent posts
[2026-11-03T17:51:31.179Z] today's auto-replies: 6 / 20
[2026-11-03T17:53:09.231Z] no new replies
[2026-11-03T18:08:09.684Z] scanning 22 recent posts
[2026-11-03T18:08:09.687Z] today's auto-replies: 6 / 20
[2026-11-03T18:09:39.733Z] no new replies
[2026-11-03T18:24:40.072Z] scanning 22 recent posts
[2026-11-03T18:24:40.077Z] today's auto-replies: 6 / 20
[2026-11-03T18:26:06.358Z] no new replies
```

## ③ 見る範囲と上限の設定（スクリプトの定数）
```
21:const DAILY_AUTO_REPLY_CAP = 20;
109:  const recent = queue.queue.filter(e =>
113:  if (recent.length === 0) { log("no recent posts"); return; }
114:  log(`scanning ${recent.length} recent posts`);
119:  const today = new Date().toISOString().slice(0, 10);
121:  log(`today's auto-replies: ${todayAutoReplies} / ${DAILY_AUTO_REPLY_CAP}`);
128:  for (const post of recent) {
143:          const text = textEl ? textEl.innerText.slice(0, 300) : "";
168:    if (todayAutoReplies + postedCount >= DAILY_AUTO_REPLY_CAP) {
169:      log(`  daily cap reached, skipping rest`);
173:    if (r.text.length < 5) { log(`  skip @${r.author}: text too short`); continue; }
177:      log(`  skip @${r.author}: already auto-replied within 24h`);
181:    log(`  generating reply to @${r.author}: "${r.text.slice(0,60).replace(/\n/g," ")}..."`);
209:        // follow-handle.js 経由、既 follow なら skip される、失敗してもメイン flow 続行
230:            log(`    👤 follow skip/fail: ${followRes.reason || followRes.error || "unknown"}`);
233:          log(`    👤 follow exec err: ${e.message.slice(0,150)}`);
257:    for (const a of autoReplyResults.slice(0, 10)) {
264:    msg += `\n📊 今日の auto-reply: ${todayAutoReplies + postedCount}/${DAILY_AUTO_REPLY_CAP} (cap)`;
```

## ④ 返さなかった理由の集計（11/1 以降・skip 系の行）
```
 161 scanning 22 recent posts
 111 scanning 24 recent posts
 100 scanning 19 recent posts
  75 scanning 20 recent posts
  58 scanning 23 recent posts
  54 scanning 21 recent posts
  53 ✅ posted: https://x.com/heng_ji31590/status/<ID>
  49 1 NEW replies, auto-reply attempting
  46 scanning 26 recent posts
  43 scanning 29 recent posts
  31 scanning 16 recent posts
  29 👤 follow OK (incoming-reply Tier C): @<伏せ>
  29 scanning 3 recent posts
  21 scanning 28 recent posts
  19 scanning 27 recent posts
  17 scanning 11 recent posts
  15 scanning 13 recent posts
  12 scanning 4 recent posts
  12 scanning 18 recent posts
   9 👤 follow skip/fail: Phase 2: no relevant topic in bio
```

## ⑤ ジョブ
```
	state = not running
	runs = 93
	last exit code = 0
		state = active
		state = active
```
