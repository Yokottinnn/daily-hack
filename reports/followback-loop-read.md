# badge-followback.js の判定と記録（2026-10-16 00:52:24 JST・$0）
```javascript
const BASELINE_ONLY = process.env.BASELINE_ONLY === "1";

function log(s) { try { fs.appendFileSync(LOG_PATH, `[${new Date().toISOString()}] ${s}\n`); } catch {} ; console.log(s); }
function out(o) { console.log(JSON.stringify(o)); }
function rand(a, b) { return Math.floor(a + Math.random() * (b - a)); }

async function slackPost(text) {
  // 2026-07-25 migrated: silent_slack.json kind-based routing via slack-notify.js
  try {
    const nx = require("./lib/slack-notify.js");
    return await nx.notify(text, { kind: "badge-followback-report" });
  } catch (e) {
    return { ok: false, error: "slack-notify-lib-missing" };
  }
}

function loadState() {
  if (!fs.existsSync(STATE_PATH)) return { processed: [], followed_back: [], initialized: false };
  try { const s = JSON.parse(fs.readFileSync(STATE_PATH, "utf8")); s.processed = s.processed || []; s.followed_back = s.followed_back || []; return s; }
  catch { return { processed: [], followed_back: [], initialized: false }; }
}
function saveState(s) { const tmp = STATE_PATH + ".tmp"; fs.writeFileSync(tmp, JSON.stringify(s, null, 2)); fs.renameSync(tmp, STATE_PATH); }
function loadFollowed() { if (!fs.existsSync(FOLLOWED_PATH)) return { followed: [] }; try { return JSON.parse(fs.readFileSync(FOLLOWED_PATH, "utf8")); } catch { return { followed: [] }; } }
function saveFollowed(d) { const tmp = FOLLOWED_PATH + ".tmp"; fs.writeFileSync(tmp, JSON.stringify(d, null, 2)); fs.renameSync(tmp, FOLLOWED_PATH); }

async function scrollExtractVerified(page) {
  const map = new Map(); // handle -> verified(bool)
}

async function getProfileFollowState(page, handle) {
  await page.goto(`https://x.com/${handle}`, { waitUntil: "domcontentloaded", timeout: 20000 });
  await page.waitForTimeout(1200);
  return await page.evaluate(() => {
    const followBtn = document.querySelector('[data-testid$="-follow"]');
    const unfollowBtn = document.querySelector('[data-testid$="-unfollow"]');
    return { can_follow: !!followBtn, already_following: !!unfollowBtn };
  });
}
async function clickFollow(page) {
  try {
    const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
    await btn.click();
    await page.waitForTimeout(1500);
    return !!(await page.$('[data-testid$="-unfollow"]'));
  } catch { return false; }
}

(async () => {
  let browser;
  const followedBackNow = [];
  try {
    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
    const ctx = browser.contexts()[0];
    const page = await ctx.newPage();
    await page.goto(`https://x.com/${X_USERNAME}/followers`, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(2500);
    try { await page.waitForSelector('[data-testid="UserCell"]', { timeout: 10000 }); } catch {}

    const map = await scrollExtractVerified(page);
    const verifiedFollowers = [...map.entries()].filter(([, v]) => v).map(([h]) => h);

    const state = loadState();
    const processed = new Set(state.processed);
    const followedData = loadFollowed();
    const alreadyFollowing = new Set((followedData.followed || []).map((a) => a.handle));
    const candidates = verifiedFollowers.filter((h) => !processed.has(h));

    log(`scanned=${map.size} verified=${verifiedFollowers.length} new_candidates=${candidates.length} DRY_RUN=${DRY_RUN} BASELINE_ONLY=${BASELINE_ONLY}`);

    if (DRY_RUN) {
      out({ ok: true, dry_run: true, scanned: map.size, verified: verifiedFollowers.length, new_candidates: candidates.length, sample: candidates.slice(0, 40) });
      await browser.close().catch(() => {}); return;
    }

    if (BASELINE_ONLY) {
      for (const h of verifiedFollowers) processed.add(h);
      state.processed = [...processed]; state.initialized = true; saveState(state);
      await slackPost(`<@${OWNER_USER_ID}> ✅ バッジ自動フォローバック: baseline化完了。既存の認証バッジフォロワー ${verifiedFollowers.length} 件を「処理済み」として記録(フォローはせず)。今後フォローしてくる新規バッジユーザーを自動FBします。`);
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
    saveFollowed(followedData); saveState(state);

    if (followedBackNow.length) {
      const list = followedBackNow.slice(0, 30).map((h) => "@" + h).join(", ");
      await slackPost(`<@${OWNER_USER_ID}> 🔵 バッジ自動フォローバック ${followedBackNow.length}件: ${list}${followedBackNow.length > 30 ? "..." : ""}`);
```

## 処理済みの記録
```
/data/badge-followback-state.json
badge-followback-state.json: キー processed,followed_back,initialized
  processed: 352 件
  followed_back: 149 件
```

## 前倒しの回の結果
```
[2026-10-15T15:50:41.374Z] followed back @<伏せ>
followed back @<伏せ>
{"ok":true,"scanned":445,"verified":209,"followed_back":13,"handles":["<伏せ>"]}
```
**読むだけ。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
