# 間隔の決まりを通っているか（2026-11-14 19:25:49 JST・読むだけ）

## badge-followback
```
Array { /bin/bash -lc /Users/ny/.openclaw/workspace/scripts/run-badge-followback.sh >> /Users/ny/.openclaw/workspace/logs/badge-followback.log 2>&1 } 
--- /Users/ny/.openclaw/workspace/scripts/run-badge-followback.sh（11 行）
    呼んでいる badge-followback.js: pacer の行 0
```

## competitor-follower-follow
```
Array { /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js } 
--- /Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js（180 行）
7: * filter: follow-handle.js 経由 (bio mutual-intent / follower-count range)
17:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
174:    await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
    呼んでいる competitor-follower-follow.js: pacer の行 0
    呼んでいる follow-handle.js: pacer の行 1
```

## comment-warmup
```
Array { /bin/bash /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh } 
--- /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh（202 行）
171:      FOLLOW_OUT=$(/usr/local/bin/node $SCRIPTS/follow-handle.js "$AUTHOR" 2>&1 | tail -1)
    呼んでいる asuka-reply.cjs: pacer の行 0
    呼んでいる auto-reply.js: pacer の行 0
    呼んでいる comment-state.js: pacer の行 0
    呼んでいる follow-handle.js: pacer の行 1
    呼んでいる ng-filter-candidates.cjs: pacer の行 0
```

## comment-orchestrator
```
plist なし
```

## incoming-reply-watcher
```
Array { /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/incoming-reply-watcher.js } 
--- /Users/ny/.openclaw/workspace/scripts/incoming-reply-watcher.js（272 行）
4:// Flow: new reply 検知 → Haiku generate アタシ口調返信 → post-comment.js で投稿 → Slack通知
14:const POST_COMMENT_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/post-comment.js";
190:    // Post via post-comment.js (target = the incoming reply's URL)
211:        // follow-handle.js 経由、既 follow なら skip される、失敗してもメイン flow 続行
213:          const followOut = execSync(`/usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js ${r.author} 2>&1`, { encoding: "utf8", timeout: 30000
245:    await new Promise(r => setTimeout(r, 3000)); // pause between auto-replies
    呼んでいる anthropic-client.js: pacer の行 0
    呼んでいる follow-handle.js: pacer の行 1
    呼んでいる incoming-reply-watcher.js: pacer の行 0
    呼んでいる post-comment.js: pacer の行 1
```

## hashtag-follow
```
Array { /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/hashtag-follow.js } 
--- /Users/ny/.openclaw/workspace/scripts/hashtag-follow.js（179 行）
10: *   4. follow-handle.js 経由で follow (bio/follower-count filter 内蔵)
22:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
173:    await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
    呼んでいる follow-handle.js: pacer の行 1
    呼んでいる hashtag-follow.js: pacer の行 0
    呼んでいる trend-detect.js: pacer の行 0
```

## follow-balance
```
Array { /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-balance.js } 
--- /Users/ny/.openclaw/workspace/scripts/follow-balance.js（646 行）
582:      { const _r = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("unfollow", 35 * 60 * 1000); if (!_r.ok) { log("  間隔待ちで空
584:        await page.locator('[aria-label$="さんのフォローを解除"]').first().click({ timeout: 8000 }).catch(() => {});
586:        await page.locator('[role="menuitem"]:has-text("さんのフォローを解除")').first().click({ timeout: 5000 }).catch(() => {});
592:          if (t) t.click();
598:        if (c2) c2.click();
```

## mutual-prune
```
Array { /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/mutual-prune.js } 
--- /Users/ny/.openclaw/workspace/scripts/mutual-prune.js（340 行）
268:      { const _r = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("unfollow", 35 * 60 * 1000); if (!_r.ok) { console.log("  間隔待�
270:        await page.locator('[aria-label$="さんのフォローを解除"]').first().click({ timeout: 8000 }).catch(() => {});
272:        await page.locator('[role="menuitem"]:has-text("さんのフォローを解除")').first().click({ timeout: 5000 }).catch(() => {});
278:          if (t) t.click();
284:        if (c) c.click();
339:  setTimeout(() => process.exit(0), 1000);   // x224: page.close() だけでは node が終わらず、次の定時を飛ばしていた
340:})().catch((e) => { setTimeout(() => process.exit(1), 1000); log("落ちた: " + String(e && e.message).slice(0, 200)); });
```

## reply-followers-cleanup
```
Array { /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js } 
--- /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js（107 行）
5://   - else → call unfollow-handle, status=unfollowed
11:const UNFOLLOW_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/unfollow-handle.js";
30:async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
101:    await sleep(2500);
    呼んでいる check-followback.js: pacer の行 0
    呼んでいる reply-followers-cleanup.js: pacer の行 0
    呼んでいる unfollow-handle.js: pacer の行 1
```
