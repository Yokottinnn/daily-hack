# フォローのスクリプトを読む（2026-11-14 19:31:03 JST・読むだけ）

## 1. follow-handle.js（全行のうち、押す前後）
行数 279

### follow-handle.js の 1〜14 行
```js
#!/usr/bin/env node
/* x352: X のアクションの間隔待ち（x-action-pacer）。空かなければ押さずに終わる */ { const _r=require("child_process").spawnSync(process.execPath,["/Users/ny/.openclaw/workspace/lib/x-action-pa
// follow-handle.js — Follow a single X handle via CDP.
// 2026-05-20 大幅強化: profile scrape + 多段 filter (bio/influencer/活発度) を追加。
//   過去 Tier A/B/C は filter なしで follow しており、 user 留意点 (influencer 除外) も未適用だった。
//
// Usage: node follow-handle.js <handle> [--no-filter]
// Output: JSON {ok, status: followed/already_following/cannot_follow/filtered/click_failed/error, reason?, profile?}

const { chromium } = require("playwright-core");
const fs = require("fs");
const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const BLACKLIST_PATH = "/Users/ny/.openclaw/workspace/data/refollow-blacklist.json";

```
2:/* x352: X のアクションの間隔待ち（x-action-pacer）。空かなければ押さずに終わる */ { const _r=require("child_process").spawnSync(process.execPath,["/Users/ny/.openclaw/wor
15:const NO_FILTER = process.argv.includes("--no-filter");
16:const handle = process.argv.find((a, i) => i >= 2 && !a.startsWith("--"));
80:  console.log(JSON.stringify({ ok: false, error: "missing handle arg" }));
218:    const followBtn = document.querySelector('[data-testid$="-follow"]');
219:    const unfollowBtn = document.querySelector('[data-testid$="-unfollow"]');
244:      console.log(JSON.stringify({ ok: true, status: "already_following", profile }));
248:      console.log(JSON.stringify({ ok: false, status: "cannot_follow", reason: "no follow button (private/blocked/deleted)", profile }));
256:        console.log(JSON.stringify({ ok: false, status: "filtered", reason: f.reason, phase: f.phase, profile }));
262:    const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
263:    await btn.click();
265:    const verifyUnfollow = await page.$('[data-testid$="-unfollow"]');
267:      console.log(JSON.stringify({ ok: true, status: "followed", profile }));
269:      console.log(JSON.stringify({ ok: false, status: "click_failed", reason: "follow button click didn't change to unfollow", profile }));
272:    console.log(JSON.stringify({ ok: false, status: "error", reason: e.message }));

## 2. unfollow-handle.js（押す前後）
行数 110

### unfollow-handle.js の 1〜12 行
```js
#!/usr/bin/env node
/* x380: 2 分で必ず終わる（止まったまま親を巻き込まない）。押す前に空くまで待つ（30 分 6 回・2 分おき） */ setTimeout(()=>{console.log(JSON.stringify({ok:false,step:"timeout",err
/* x383: 結果の JSON を出したら終える（CDP のつながりが残って終わらず、親に 120 秒で捨てられていた） */ { const _cl=console.log; console.log=(...a)=>{ _cl(...a); if(typeof a[0]==="st
// unfollow-handle.js — Unfollow a single X handle via CDP.
// Usage: node unfollow-handle.js <handle>
// Output: JSON {ok, status: unfollowed/not_following/unconfirmed/error, reason?}
//
// 2026-09-13: **x17 で実際に外せた取り方にそろえた。**
//
// 直したのは 3 つだけ。判定も出力の JSON も変えていない。
//
//   ① work-window ではなく `contexts()[0]` を使う
```

## 3. badge-followback（起動の sh と js）
```
#!/bin/bash
# Wrapper: Chrome(CDP)を起動保証 + Slack token をロードして badge-followback.js を実行
set -e
/Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh || { echo '{"ok":false,"error":"Chrome failed"}'; exit 1; }
CONFIG=/Users/ny/.openclaw/openclaw.json
eval "$(/usr/local/bin/node -e "
const c = require('${CONFIG}');
console.log('export SLACK_BOT_TOKEN='<伏せ>''));
")"
cd /Users/ny/.openclaw/workspace
exec /usr/local/bin/node scripts/badge-followback.js
```
行数 245
8:    const cfgPath = process.env.HOME + "/.openclaw/workspace/config/silent_slack.json";
76:const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
84:const MAX_SCROLL_LOOPS = 80;
85:const DRY_RUN = process.env.DRY_RUN === "1";
86:const BASELINE_ONLY = process.env.BASELINE_ONLY === "1";
114:  for (let i = 0; i < MAX_SCROLL_LOOPS; i++) {
129:    for (const [h, v] of batch) { if (!map.has(h) || v) map.set(h, v); }
133:    await page.waitForTimeout(700);
140:  await page.waitForTimeout(1200);
150:    await btn.click();
151:    await page.waitForTimeout(1500);
164:    await page.waitForTimeout(2500);
176:      for (let k = 0; k < 40 && still < 4; k++) {
184:        for (const [h, nf] of rows) { if (!h) continue; seenVF.add(h); if (nf) notFollowing.add(h); }
186:        await page.evaluate(() => window.scrollBy(0, 2500)); await page.waitForTimeout(1500);
195:    // x299: 一覧で未フォローの人を必ず足す。1 回の上限 FOLLOWBACK_MAX_PER_RUN（既定 25）
196:    const MAX_PER_RUN = Number(process.env.FOLLOWBACK_MAX_PER_RUN || 25);
197:    const candidates = [...new Set([...notFollowing, ...verifiedFollowers.filter((h) => !processed.has(h))])].filter((h) => h.toLowerCase() !== String(X_USERNAME).toLowerCase()).slice(0, MAX_PER_R
207:      for (const h of verifiedFollowers) processed.add(h);
214:    for (const h of candidates) {
227:          log(`followed back @${h}`);
229:        await page.waitForTimeout(rand(5000, 15000));

### badge-followback.js の 197〜233 行
```js
    const candidates = [...new Set([...notFollowing, ...verifiedFollowers.filter((h) => !processed.has(h))])].filter((h) => h.toLowerCase() !== String(X_USERNAME).toLowerCase()).slice(0, MAX_PER_RUN);

    log(`scanned=${map.size} verified=${verifiedFollowers.length} new_candidates=${candidates.length} DRY_RUN=${DRY_RUN} BASELINE_ONLY=${BASELINE_ONLY}`);

    if (DRY_RUN) {
      out({ ok: true, dry_run: true, scanned: map.size, verified: verifiedFollowers.length, new_candidates: candidates.length, sample: candidates.slice(0, 40) });
      await browser.close().catch(() => {}); return;
    }

    if (BASELINE_ONLY) {
      for (const h of verifiedFollowers) processed.add(h);
      state.processed = [...processed]; state.initialized = true; saveState(state);
      await slackPost(`<@${OWNER_USER_ID}> ✅ バッジ自動フォローバック: baseline化完了。既存の認証バッジフォロワー ${verifiedFollowers.length} 件を「処理済み」として記録(フォ�
      out({ ok: true, baseline: true, baselined: verifiedFollowers.length });
      await browser.close().catch(() => {}); return;
    }

    for (const h of candidates) {
      try {
        const st = await getProfileFollowState(page, h);
        processed.add(h);
        if (st.already_following || !st.can_follow) continue;
        if (await clickFollow(page)) {
          followedBackNow.push(h);
          if (!alreadyFollowing.has(h)) {
            followedData.followed = followedData.followed || [];
            followedData.followed.push({ handle: h, followed_at: new Date().toISOString(), source: "badge-followback", verified: true });
            alreadyFollowing.add(h);
          }
          state.followed_back.push({ handle: h, at: new Date().toISOString() });
          log(`followed back @${h}`);
        }
        await page.waitForTimeout(rand(5000, 15000));
      } catch (e) { log(`error @${h}: ${e.message}`); processed.add(h); }
    }

    state.processed = [...processed]; state.initialized = true;
```

## 4. 1 回あたりの上限と起動の時刻（plist）

### badge-followback
```
時刻: Array { Dict { Hour = 0 Minute = 50 } Dict { Hour = 8 Minute = 50 } Dict { Hour = 16 Minute = 20 } } 
間隔: 
Dict {
}
```

### competitor-follower-follow
```
時刻: Array { Dict { Hour = 11 Minute = 30 } Dict { Hour = 20 Minute = 45 } } 
間隔: 
Dict {
 COMPETITOR_FOLLOW_DAILY_CAP = 30
 PATH = /usr/local/bin:/usr/bin:/bin
 FORCE_RUN = 1
}
```

### comment-warmup
```
時刻: Array { Dict { Hour = 8 Minute = 0 } Dict { Hour = 10 Minute = 0 } Dict { Hour = 12 Minute = 0 } Dict { Hour = 16 Minute = 0 } Dict { Hour = 19 Minute = 0 } Dict { Hour = 22 Minute = 0 } } 
間隔: 
Dict {
 MIN_LIKES = 2
 MAX_AGE_HOURS = 18
 MAX_PICKS_PER_FIRE = 5
 REPLY_FOLLOW_DAILY_CAP = 30
}
```

### hashtag-follow
```
時刻: Array { Dict { Hour = 10 Minute = 15 } Dict { Hour = 17 Minute = 0 } } 
間隔: 
Dict {
 HASHTAG_FOLLOW_DAILY_CAP = 90
 PATH = /usr/local/bin:/usr/bin:/bin
 FORCE_RUN = 1
}
```

### follow-balance
```
時刻: Array { Dict { Hour = 11 Minute = 45 } Dict { Hour = 20 Minute = 15 } Dict { Hour = 15 Minute = 15 } } 
間隔: 
Dict {
 MAX_PROFILE_READS = 60
 DECIDE_BUDGET_S = 300
 FOLLOW_RATIO_GLIDE = 500:0.62,700:0.60,1000:0.55,1500:0.50
 LIST_BUDGET_S = 110
 MIN_UNFOLLOW = 20
 HOME = /Users/ny
 MAX_UNFOLLOW = 20
 PATH = /usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
 GRACE_DAYS = 3
}
```

### mutual-prune
```
時刻: Array { Dict { Hour = 6 Minute = 0 } Dict { Hour = 18 Minute = 0 } Dict { Hour = 12 Minute = 30 } } 
間隔: 
Dict {
 OPS_WS = /Users/ny/.openclaw/workspace
 RATIO = 0.20
 ABS_MIN = 300
 INACTIVE_DAYS = 30
 HOME = /Users/ny
 MAX_UNFOLLOW = 15
 MUTUAL_RATIO_CUT = 0.8
 CDP_URL = http://127.0.0.1:18810
 GRACE_DAYS = 1
 PATH = /usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
}
```

### reply-followers-cleanup
```
時刻: Array { Dict { Hour = 2 Minute = 0 } Dict { Hour = 3 Minute = 0 } Dict { Hour = 4 Minute = 0 } Dict { Hour = 5 Minute = 0 } Dict { Hour = 6 Minute = 0 } Dict { Hour = 7 Minute = 0 } Dict { Hour = 8 Minute = 0 } Dict { Hour = 9 Minute = 0 } Dict { Hour = 10 Minute = 0 } Dict { Hour = 11 Minute = 0 } 
間隔: 
Dict {
}
```

### incoming-reply-watcher
```
時刻: 
間隔: 900
Dict {
}
```

## 5. スクリプトの中の 1 回あたりの上限（既定値）
```
competitor-follower-follow.js:8: * cap: COMPETITOR_FOLLOW_DAILY_CAP (default 10)
competitor-follower-follow.js:19:const REPLY_FOLLOWERS_PATH = `${WS}/data/reply-followers.json`;
competitor-follower-follow.js:39:const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);
competitor-follower-follow.js:40:const FOLLOW_GAP_MS = 30 * 1000;
competitor-follower-follow.js:68:  if (fs.existsSync(REPLY_FOLLOWERS_PATH)) {
competitor-follower-follow.js:70:      const d = JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8"));
competitor-follower-follow.js:127:  log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITORS.length-1}) cap=${DAILY
competitor-follower-follow.js:140:  const targets = scrapedHandles.filter(h => !followed.has(h.toLowerCase())).slice(0, DAILY_CAP);
competitor-follower-follow.js:157:          const rf = fs.existsSync(REPLY_FOLLOWERS_PATH) ? JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8")) : {};
competitor-follower-follow.js:167:          fs.writeFileSync(REPLY_FOLLOWERS_PATH, JSON.stringify(rf, null, 2));
competitor-follower-follow.js:174:    await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
hashtag-follow.js:13: * Daily cap: env HASHTAG_FOLLOW_DAILY_CAP (default 10)
hashtag-follow.js:24:const REPLY_FOLLOWERS_PATH = `${WS}/data/reply-followers.json`;
hashtag-follow.js:30:const DAILY_CAP = parseInt(process.env.HASHTAG_FOLLOW_DAILY_CAP || "10", 10);
hashtag-follow.js:31:const FOLLOW_GAP_MS = 30 * 1000;
hashtag-follow.js:75:  if (fs.existsSync(REPLY_FOLLOWERS_PATH)) {
hashtag-follow.js:77:      const d = JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8"));
hashtag-follow.js:92:  log(`=== hashtag-follow start (cap=${DAILY_CAP}) ===`);
hashtag-follow.js:127:  const alreadyTodayB = todayFollowCountFrom(REPLY_FOLLOWERS_PATH);
hashtag-follow.js:129:  const remaining = Math.max(0, DAILY_CAP - usedToday);  // ※ Tier A 内の cap、他 source とは別計算がベターだがまず合算
hashtag-follow.js:130:  log(`today already follows: ${usedToday} (A:${alreadyTodayA}+B:${alreadyTodayB}) / DAILY_CAP=${DAILY_CAP} / remaining=${remaining}`);
hashtag-follow.js:134:    await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow: cap到達でskip (today=${usedToday}/${DAILY_CAP})`);
hashtag-follow.js:154:          const rf = fs.existsSync(REPLY_FOLLOWERS_PATH) ? JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8")) : {};
hashtag-follow.js:166:          fs.writeFileSync(REPLY_FOLLOWERS_PATH, JSON.stringify(rf, null, 2));
hashtag-follow.js:173:    await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
hashtag-follow.js:177:  await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow 完了: ${ok}/${results.length} follow OK (今日合計 follow ≈${use
comment-orchestrator.sh:3:# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
comment-orchestrator.sh:9:MAX_PICKS=${MAX_PICKS_PER_FIRE:-2}
comment-orchestrator.sh:10:REPLY_FOLLOW_DAILY_CAP=${REPLY_FOLLOW_DAILY_CAP:-10}
comment-orchestrator.sh:22:log "=== comment orchestrator start (max_picks=$MAX_PICKS, reply_follow_cap=$REPLY_FOLLOW_DAILY_CAP) ==="
```
