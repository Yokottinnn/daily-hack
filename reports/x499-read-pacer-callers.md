# 間隔の決まりの呼ばれ方を読む（2026-11-15 20:59:42 JST・読むだけ・$0）

## follow-handle.js（280 行）
```
2:/* x352: X のアクションの間隔待ち（x-action-pacer）。空かなければ押さずに終わる */ { const _r=require("child_process").spawnSync(process.execPath,["/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs"
3:// follow-handle.js — Follow a single X handle via CDP.
7:// Usage: node follow-handle.js <handle> [--no-filter]
15:const NO_FILTER = process.argv.includes("--no-filter");
16:const handle = process.argv.find((a, i) => i >= 2 && !a.startsWith("--"));
262:    /* x480: 押す直前に間隔の決まりを通す（記録する）。絞り込みで落ちた相手は数えない。空かなければ押さずに終わる */ { const _pr = await require("/Users/ny/.openclaw/workspace/
```
前後:
```
      }
    }

    // Execute follow
    /* x480: 押す直前に間隔の決まりを通す（記録する）。絞り込みで落ちた相手は数えない。空かなければ押さずに終わる */ { const _pr = await require("/Users/ny/.openclaw/workspace/lib/
    const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
    await btn.click();
    await page.waitForTimeout(1500);
    const verifyUnfollow = await page.$('[data-testid$="-unfollow"]');
    if (verifyUnfollow) {
      console.log(JSON.stringify({ ok: true, status: "followed", profile }));
    } else {
      console.log(JSON.stringify({ ok: false, status: "click_failed", reason: "follow button click didn't change to unfollow", profile }));
```

## unfollow-handle.js（110 行）
```
2:/* x380: 2 分で必ず終わる（止まったまま親を巻き込まない）。押す前に空くまで待つ（30 分 6 回・2 分おき） */ setTimeout(()=>{console.log(JSON.stringify({ok:false,step:"timeout",error:"2 �
4:// unfollow-handle.js — Unfollow a single X handle via CDP.
5:// Usage: node unfollow-handle.js <handle>
33:  const handle = process.argv[2];
```

## follow-balance.js（646 行）
```
17://   MAX_UNFOLLOW=60      1 回に外す絶対上限（暴走よけ）
21://   MAX_PROFILE_READS=40 プロフィールを開く上限（時間の暴走よけ）
30:const MAXN = Number(process.env.MAX_UNFOLLOW || 60);
34:const MAX_READS = Number(process.env.MAX_PROFILE_READS || 40);
41:const CACHE_MAX_H = Number(process.env.CACHE_MAX_H || 6);
233:    if (!isFinite(ageH) || ageH > CACHE_MAX_H) {
468:      if (cuts.length >= quota * 2 || reads >= MAX_READS) break;
582:      { const _r = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("unfollow", 35 * 60 * 1000); if (!_r.ok) { log("  間隔待ちで空かない（" + _r.reason + "）。この回はここまで�
```
前後:
```
      }
      // x341（2026-10-25）: サブスクを出しているアカウントは「<id>-unfollow」が「購入する」ボタンで、押しても外れない。
      // 外すのはアイコンのボタン（aria「〇〇さんのフォローを解除」）→ 出るメニューの「〇〇さんのフォローを解除」。マウス操作で押す（JS の click() では開かない）
      // x403: フォロー解除は全ジョブ共有の台帳で 120 秒あけ・30 分 6 回まで（最上位ルール 23）。空くまで待って記録する。空かなければこの回はここまで
      { const _r = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("unfollow", 35 * 60 * 1000); if (!_r.ok) { log("  間隔待ちで空かない（" + _r.reason + "）。この回はここまで（x4
      if (await page.locator('[aria-label$="さんのフォローを解除"]').count()) {
        await page.locator('[aria-label$="さんのフォローを解除"]').first().click({ timeout: 8000 }).catch(() => {});
        await page.waitForTimeout(1200);
        await page.locator('[role="menuitem"]:has-text("さんのフォローを解除")').first().click({ timeout: 5000 }).catch(() => {});
      } else {
        await page.evaluate(() => {
          const bs = Array.from(document.querySelectorAll("button,[role=button]"));
          const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
```

## mutual-prune.js（340 行）
```
12://   MAX_UNFOLLOW=8     1 回に外す上限
24:const MAXN = Number(process.env.MAX_UNFOLLOW || 8);
268:      { const _r = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("unfollow", 35 * 60 * 1000); if (!_r.ok) { console.log("  間隔待ちで空かない（" + _r.reason + "）。この回はこ�
```
前後:
```
      }
      // x341（2026-10-25）: サブスクを出しているアカウントは「<id>-unfollow」が「購入する」ボタンで、押しても外れない。
      // 外すのはアイコンのボタン（aria「〇〇さんのフォローを解除」）→ 出るメニューの「〇〇さんのフォローを解除」。マウス操作で押す（JS の click() では開かない）
      // x419: フォロー解除は全ジョブ共有の台帳で 120 秒あけ・30 分 6 回まで（最上位ルール 23）。空くまで待って記録する。空かなければこの回はここまで
      { const _r = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("unfollow", 35 * 60 * 1000); if (!_r.ok) { console.log("  間隔待ちで空かない（" + _r.reason + "）。この回はここま
      if (await page.locator('[aria-label$="さんのフォローを解除"]').count()) {
        await page.locator('[aria-label$="さんのフォローを解除"]').first().click({ timeout: 8000 }).catch(() => {});
        await page.waitForTimeout(1200);
        await page.locator('[role="menuitem"]:has-text("さんのフォローを解除")').first().click({ timeout: 5000 }).catch(() => {});
      } else {
        await page.evaluate(() => {
          const bs = Array.from(document.querySelectorAll("button,[role=button]"));
          const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
```

## badge-followback.js（246 行）
```
84:const MAX_SCROLL_LOOPS = 80;
114:  for (let i = 0; i < MAX_SCROLL_LOOPS; i++) {
195:    // x299: 一覧で未フォローの人を必ず足す。1 回の上限 FOLLOWBACK_MAX_PER_RUN（既定 25）
196:    const MAX_PER_RUN = Number(process.env.FOLLOWBACK_MAX_PER_RUN || 25);
197:    const candidates = [...new Set([...notFollowing, ...verifiedFollowers.filter((h) => !processed.has(h))])].filter((h) => h.toLowerCase() !== String(X_USERNAME).toLowerCase()).slice(0, MAX_PER_RUN);
219:        /* x480: 押す前に間隔の決まりを通す（記録する）。空かなければこの回はここで止める */ { const _pr = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("fol
```
前後:
```
      try {
        const st = await getProfileFollowState(page, h);
        processed.add(h);
        if (st.already_following || !st.can_follow) continue;
        /* x480: 押す前に間隔の決まりを通す（記録する）。空かなければこの回はここで止める */ { const _pr = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("follow"
        if (await clickFollow(page)) {
          followedBackNow.push(h);
          if (!alreadyFollowing.has(h)) {
            followedData.followed = followedData.followed || [];
            followedData.followed.push({ handle: h, followed_at: new Date().toISOString(), source: "badge-followback", verified: true });
            alreadyFollowing.add(h);
          }
          state.followed_back.push({ handle: h, at: new Date().toISOString() });
```

## competitor-follower-follow.js（180 行）
```
7: * filter: follow-handle.js 経由 (bio mutual-intent / follower-count range)
13:const { execSync } = require("child_process");
17:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
40:const FOLLOW_GAP_MS = 30 * 1000;
151:      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${h}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2*1024*1024 });
174:    await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
```

## hashtag-follow.js（179 行）
```
10: *   4. follow-handle.js 経由で follow (bio/follower-count filter 内蔵)
18:const { execSync } = require("child_process");
22:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
31:const FOLLOW_GAP_MS = 30 * 1000;
97:    detectOut = execSync(`/usr/local/bin/node ${TREND_DETECT}`, { encoding: "utf8", maxBuffer: 32 * 1024 * 1024, timeout: 420000 });
146:      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2 * 1024 * 1024, env: Object.assign({}, process.env, { FOLLOW_REQUIRE_VERIFIED: process.env.HASHTAG_
173:    await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
```

## incoming-reply-watcher.js（272 行）
```
8:const { execSync } = require("child_process");
193:      const out = execSync(`/usr/local/bin/node ${POST_COMMENT_SCRIPT} "${textB64}" "${r.reply_url}" 2>&1`, { encoding: "utf8", maxBuffer: 8*1024*1024 });
211:        // follow-handle.js 経由、既 follow なら skip される、失敗してもメイン flow 続行
213:          const followOut = execSync(`/usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js ${r.author} 2>&1`, { encoding: "utf8", timeout: 30000, maxBuffer: 2*1024*1024 });
```

## reply-followers-cleanup.js（107 行）
```
5://   - else → call unfollow-handle, status=unfollowed
7:const { execSync } = require("child_process");
11:const UNFOLLOW_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/unfollow-handle.js";
48:  const CLEANUP_MAX_PER_RUN = Number(process.env.CLEANUP_MAX_PER_RUN || 20);
49:  if (due.length > CLEANUP_MAX_PER_RUN) {
50:    log(`due ${due.length} → 上限 ${CLEANUP_MAX_PER_RUN} 件に絞る（残りは次回）`);
51:    due.length = CLEANUP_MAX_PER_RUN;
58:    const out = execSync(`/usr/local/bin/node ${CHECK_SCRIPT} ${due.join(" ")}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024, timeout: 120000 });
81:      const out = execSync(`/usr/local/bin/node ${UNFOLLOW_SCRIPT} ${r.handle}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024, timeout: 120000 });
```

## launchd の間隔（StartInterval / StartCalendarInterval の数）
```
badge-followback: StartInterval=なし ／ 時刻指定 3 回
comment-warmup: StartInterval=なし ／ 時刻指定 6 回
competitor-follower-follow: StartInterval=なし ／ 時刻指定 2 回
hashtag-follow: StartInterval=なし ／ 時刻指定 2 回
incoming-reply-watcher: StartInterval=900 ／ 時刻指定 0 回
follow-balance: StartInterval=なし ／ 時刻指定 3 回
mutual-prune: StartInterval=なし ／ 時刻指定 3 回
reply-followers-cleanup: StartInterval=なし ／ 時刻指定 24 回
```

**読むだけ。LLM 不使用（$0）。**
