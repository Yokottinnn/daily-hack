# フォロー 3 本の中身（2026-11-01 00:22 JST・読むだけ・$0）

## follow-balance
```
行数 629  更新 10-25 17:29
--- plist の環境変数
{"MAX_PROFILE_READS":"40","DECIDE_BUDGET_S":"150","FOLLOW_RATIO_GLIDE":"370:0.57,500:0.50,700:0.42,1000:0.33","LIST_BUDGET_S":"110","MIN_UNFOLLOW":"20","HOME":"\/Users\/ny","MAX_UNFOLLOW":"20","PATH":"\/usr\/local\/bin:\/usr\/bin:\/bin:\/usr\/sbin:\/sbin","GRACE_DAYS":"1"}
--- 自分のハンドル・フォロワー一覧・検索・条件まわりの行（前後 3 行）
42:// **1 本の scrapeList に持ち時間を持たせる。** 無いと片方で使い切る
127:async function scrapeList(page, url, want) {
144:      const all = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
154:        const cells = Array.from(document.querySelectorAll("[data-testid=UserCell]"));
184:    const a = document.querySelector('a[href$="/verified_followers"]') ||
185:              document.querySelector('a[href$="/followers"]');
200:      " grace=" + GRACE_DAYS + "d inactive=" + INACTIVE_DAYS + "d big=" + BIG + ") ===");
212:    // x238: プロフィールへのリンクが出るまで待つ。出なければ 1 回 開き直す（3 秒 固定では空のページを読んでいた）
213:    { const ok = () => page.waitForSelector('[data-testid=AppTabBar_Profile_Link]', { timeout: 15000 }).then(() => true).catch(() => false);
217:      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
222:  if (!me) { let u = "", L = -1; try { u = page.url(); L = await page.evaluate(() => (document.body && document.body.innerText || "").length); } catch (e) {} log("**自分のハンドルが読め�
241:    following = await scrapeList(page, "https://x.com/" + me + "/following", 800);
245:    followers = await scrapeList(page, "https://x.com/" + me + "/followers", 1000);
303:  let TARGET_RATIO = Number(process.env.FOLLOW_RATIO_TARGET || 0.58);
323:        followers: toN(pick('a[href$="/verified_followers"]') || pick('a[href$="/followers"]')),
339:        TARGET_RATIO = t; CEIL_RATIO = t + 0.05; FLOOR_RATIO = Math.max(0.1, t - 0.15);
348:        "（目標 " + Math.floor(hdr.followers * TARGET_RATIO) + " 件 / 警戒 " + ceilN +
350:    const targetN = Math.floor(hdr.followers * TARGET_RATIO);
```
### 今日のログ（最初の 40 行）
```
```

## competitor-follower-follow
```
行数 180  更新 10-12 21:33
--- plist の環境変数
{"COMPETITOR_FOLLOW_DAILY_CAP":"30","PATH":"\/usr\/local\/bin:\/usr\/bin:\/bin","FORCE_RUN":"1"}
--- 自分のハンドル・フォロワー一覧・検索・条件まわりの行（前後 3 行）
3: * competitor-follower-follow.js — Tier B: 競合 follower scrape → follow
6: * Daily rotation: day-of-week mod len(competitors) で 1 competitor 選定、 follower list 先頭から scrape
8: * cap: COMPETITOR_FOLLOW_DAILY_CAP (default 10)
39:const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);
41:const SCRAPE_TARGET_COUNT = 60;
77:async function scrapeFollowers(competitor) {
86:    const listPath = process.env.COMPETITOR_VERIFIED_ONLY === "0" ? "followers" : "verified_followers";
91:    while (handles.size < SCRAPE_TARGET_COUNT && stableCount < 5) {
93:        const links = Array.from(document.querySelectorAll('[data-testid="UserCell"] a[href^="/"]'));
109:    log(`scrape err: ${e.message}`);
127:  log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITORS.length-1}) cap=${DAILY_CAP} ===`);
130:  let scrapedHandles = [];
132:    scrapedHandles = await scrapeFollowers(competitor);
134:    log(`scrape failure: ${e.message}`);
135:    await slackPost(`<@${OWNER_USER_ID}> 🌐 Tier B competitor-follower: scrape失敗 @${competitor} (${e.message})`);
138:  log(`scraped ${scrapedHandles.length} followers from @${competitor}`);
140:  const targets = scrapedHandles.filter(h => !followed.has(h.toLowerCase())).slice(0, DAILY_CAP);
141:  log(`new targets (after dedup): ${targets.length}`);
143:  if (targets.length === 0) {
149:  for (const h of targets) {
178:  await slackPost(`<@${OWNER_USER_ID}> 🌐 Tier B competitor-follower 完了: @${competitor} の follower から ${ok}/${results.length} follow OK (scraped=${scrapedHandles.length})`);
```
### 今日のログ（最初の 40 行）
```
```

## hashtag-follow
```
行数 179  更新 10-12 21:33
--- plist の環境変数
{"HASHTAG_FOLLOW_DAILY_CAP":"90","PATH":"\/usr\/local\/bin:\/usr\/bin:\/bin","FORCE_RUN":"1"}
--- 自分のハンドル・フォロワー一覧・検索・条件まわりの行（前後 3 行）
3: * hashtag-follow.js — Tier A: ハッシュタグ active 投稿者を follow 候補化
11: *   5. reply-followers.json に source="hashtag-active" で記録 (live-check safety net 自動適用)
13: * Daily cap: env HASHTAG_FOLLOW_DAILY_CAP (default 10)
25:const LOG_PATH = `${WS}/logs/hashtag-follow.log`;
30:const DAILY_CAP = parseInt(process.env.HASHTAG_FOLLOW_DAILY_CAP || "10", 10);
40:    return nx.notify(text, { kind: "hashtag-follow-progress" });
88:    log(`=== hashtag-follow SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
92:  log(`=== hashtag-follow start (cap=${DAILY_CAP}) ===`);
114:  const targets = [];
121:    targets.push({ author: a, ...c });
123:  log(`unique new authors: ${targets.length}`);
125:  // 3. cap check (今日既に follow した数を 2 source から合算)
129:  const remaining = Math.max(0, DAILY_CAP - usedToday);  // ※ Tier A 内の cap、他 source とは別計算がベターだがまず合算 conservative
130:  log(`today already follows: ${usedToday} (A:${alreadyTodayA}+B:${alreadyTodayB}) / DAILY_CAP=${DAILY_CAP} / remaining=${remaining}`);
133:    log("cap reached, exit");
134:    await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow: cap到達でskip (today=${usedToday}/${DAILY_CAP})`);
138:  const picks = targets.slice(0, remaining);
145:      // 2026-10-12 x278: 認証済みの投稿者だけをフォローする（HASHTAG_REQUIRE_VERIFIED=0 で従来どおり）
146:      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2 * 1024 * 1024, env: Object.assign({}, process.env, { FOLLOW_REQUIRE_
161:            source: "hashtag-follow",
177:  await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow 完了: ${ok}/${results.length} follow OK (今日合計 follow ≈${usedToday + ok}/${DAILY_CAP})`);
```
### 今日のログ（最初の 40 行）
```
```

## 自分のハンドルを読む部分（follow-balance の x238 前後 25 行）
```
    const ts = Array.from(document.querySelectorAll("article time[datetime]"))
      .map((t) => t.getAttribute("datetime")).filter(Boolean);
    if (ts.length) {
      const ms = ts.map((x) => new Date(x).getTime()).filter((n) => isFinite(n) && n > 0);
      if (ms.length) res.lastPost = new Date(Math.max.apply(null, ms)).toISOString();
    }
    res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
    return res;
  });
}

(async () => {
  log("=== follow-balance start (dry=" + DRY + " min=" + MINN + " max=" + MAXN +
      " grace=" + GRACE_DAYS + "d inactive=" + INACTIVE_DAYS + "d big=" + BIG + ") ===");

  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
  catch (e) { log("CDP に繋がらない: " + String(e.message).slice(0, 120)); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { log("context が無い。何もしない。"); return; }
  const page = await ctx.newPage();

  let me = null;
  try {
    await page.goto("https://x.com/<伏せ>", { waitUntil: "domcontentloaded", timeout: 30000 });
    // x238: プロフィールへのリンクが出るまで待つ。出なければ 1 回 開き直す（3 秒 固定では空のページを読んでいた）
    { const ok = () => page.waitForSelector('[data-testid=AppTabBar_Profile_Link]', { timeout: 15000 }).then(() => true).catch(() => false);
      if (!(await ok())) { log("/home が空。開き直す"); await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {}); await ok(); } }
    if (/login|i\/flow/.test(page.url())) { log("**ログインが切れている。何もしない。**"); await page.close(); process.exit(0); }
    me = await page.evaluate(() => {
      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
      const m = a && (a.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
      return m ? m[1] : null;
    });
  } catch (e) { log("/home を開けない: " + String(e.message).slice(0, 100)); await page.close(); process.exit(0); }
  if (!me) { let u = "", L = -1; try { u = page.url(); L = await page.evaluate(() => (document.body && document.body.innerText || "").length); } catch (e) {} log("**自分のハンドルが読めな�
```

## 競合のフォロワーを読む部分（scraped の前 40 行）
```
    let lastSize = 0;
    while (handles.size < SCRAPE_TARGET_COUNT && stableCount < 5) {
      const newOnes = await page.evaluate(() => {
        const links = Array.from(document.querySelectorAll('[data-testid="UserCell"] a[href^="/"]'));
        const seen = new Set();
        for (const a of links) {
          const m = a.getAttribute("href").match(/^\/([^/?#]+)$/);
          if (m && !/^(home|explore|notifications|messages|i|search)$/.test(m[1])) seen.add(m[1]);
        }
        return [...seen];
      });
      for (const h of newOnes) handles.add(h);
      if (handles.size === lastSize) stableCount++;
      else stableCount = 0;
      lastSize = handles.size;
      await page.evaluate(() => window.scrollBy(0, 800));
      await page.waitForTimeout(2000);
    }
  } catch (e) {
    log(`scrape err: ${e.message}`);
  } finally {
    await page.close(); await browser.close();
  }
  return [...handles];
}

(async () => {
  // 🆕 2026-06-07: 日曜(0)・月曜(1) はFB率0%のためスキップ
  const todayDate = new Date();
  const todayDow = todayDate.getDay();
  if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
    log(`=== competitor-follower SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
    process.exit(0);
  }

  const dayIndex = Math.floor(todayDate.getTime() / 86400000) % COMPETITORS.length;
  const competitor = COMPETITORS[dayIndex];
  log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITORS.length-1}) cap=${DAILY_CAP} ===`);

  const followed = getFollowedHandles();
  let scrapedHandles = [];
  try {
    scrapedHandles = await scrapeFollowers(competitor);
  } catch (e) {
```

## ハッシュタグの候補の集め方（out of range の前 40 行）
```
```
