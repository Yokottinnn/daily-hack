# フォロー返しの上限と、前倒しの 1 回の結果（2026-10-16 00:49:12 JST・$0）

## run-badge-followback.sh
```bash
#!/bin/bash
set -e
/Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh || { echo '{"ok":false,"error":"Chrome failed"}'; exit 1; }
CONFIG=/Users/ny/.openclaw/openclaw.json
eval "$(/usr/local/bin/node -e "
const c = require('${CONFIG}');
")"
cd /Users/ny/.openclaw/workspace
exec /usr/local/bin/node scripts/badge-followback.js
```

## 本体（上限・間隔・認証の判定の行）
本体: /Users/ny/.openclaw/workspace/scripts/badge-followback.js
```javascript
8:    const cfgPath = process.env.HOME + "/.openclaw/workspace/config/silent_slack.json";
62: *   1. /heng_ji31590/followers をスクロールして全フォロワー + 各人の verified バッジ有無を抽出
76:const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
84:const MAX_SCROLL_LOOPS = 80;
85:const DRY_RUN = process.env.DRY_RUN === "1";
86:const BASELINE_ONLY = process.env.BASELINE_ONLY === "1";
96:    return await nx.notify(text, { kind: "badge-followback-report" });
112:  const map = new Map(); // handle -> verified(bool)
114:  for (let i = 0; i < MAX_SCROLL_LOOPS; i++) {
115:    const batch = await page.evaluate(() => {
124:        const verified = !!c.querySelector('svg[data-testid="icon-verified"]');
125:        res.push([h, verified]);
132:    await page.evaluate(() => window.scrollBy(0, 1400));
133:    await page.waitForTimeout(700);
139:  await page.goto(`https://x.com/${handle}`, { waitUntil: "domcontentloaded", timeout: 20000 });
140:  await page.waitForTimeout(1200);
141:  return await page.evaluate(() => {
149:    const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
150:    await btn.click();
151:    await page.waitForTimeout(1500);
152:    return !!(await page.$('[data-testid$="-unfollow"]'));
160:    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
162:    const page = await ctx.newPage();
163:    await page.goto(`https://x.com/${X_USERNAME}/followers`, { waitUntil: "domcontentloaded", timeout: 30000 });
164:    await page.waitForTimeout(2500);
165:    try { await page.waitForSelector('[data-testid="UserCell"]', { timeout: 10000 }); } catch {}
167:    const map = await scrollExtractVerified(page);
168:    const verifiedFollowers = [...map.entries()].filter(([, v]) => v).map(([h]) => h);
174:    const candidates = verifiedFollowers.filter((h) => !processed.has(h));
176:    log(`scanned=${map.size} verified=${verifiedFollowers.length} new_candidates=${candidates.length} DRY_RUN=${DRY_RUN} BASELINE_ONLY=${BASELINE_ONLY}`);
179:      out({ ok: true, dry_run: true, scanned: map.size, verified: verifiedFollowers.length, new_candidates: candidates.length, sample: candidates.slice(0, 40) });
180:      await browser.close().catch(() => {}); return;
184:      for (const h of verifiedFollowers) processed.add(h);
186:      await slackPost(`<@${OWNER_USER_ID}> ✅ バッジ自動フォローバック: baseline化完了。既存の認証バッジフォロワー ${verifiedFollowers.length} 件を「処理済み」として記録(フォローはせず)。今後フォローしてくる新規バッジユーザーを自動FBします。`);
187:      out({ ok: true, baseline: true, baselined: verifiedFollowers.length });
188:      await browser.close().catch(() => {}); return;
193:        const st = await getProfileFollowState(page, h);
196:        if (await clickFollow(page)) {
200:            followedData.followed.push({ handle: h, followed_at: new Date().toISOString(), source: "badge-followback", verified: true });
206:        await page.waitForTimeout(rand(5000, 15000));
214:      const list = followedBackNow.slice(0, 30).map((h) => "@" + h).join(", ");
215:      await slackPost(`<@${OWNER_USER_ID}> 🔵 バッジ自動フォローバック ${followedBackNow.length}件: ${list}${followedBackNow.length > 30 ? "..." : ""}`);
217:    out({ ok: true, scanned: map.size, verified: verifiedFollowers.length, followed_back: followedBackNow.length, handles: followedBackNow });
220:    try { await slackPost(`<@${OWNER_USER_ID}> ⚠️ バッジ自動フォローバック エラー: ${e.message}`); } catch {}
221:  } finally { if (browser) await browser.close().catch(() => {}); }
```

## 前倒しの回（10/15 夜〜）
```
{"ok":true,"scanned":342,"verified":120,"followed_back":2,"handles":["<伏せ>"]}
[2026-10-10T15:50:37.705Z] scanned=344 verified=121 new_candidates=3 DRY_RUN=false BASELINE_ONLY=false
scanned=344 verified=121 new_candidates=3 DRY_RUN=false BASELINE_ONLY=false
{"ok":true,"scanned":344,"verified":121,"followed_back":0,"handles":["<伏せ>"]}
[2026-10-11T15:50:42.126Z] scanned=346 verified=122 new_candidates=3 DRY_RUN=false BASELINE_ONLY=false
scanned=346 verified=122 new_candidates=3 DRY_RUN=false BASELINE_ONLY=false
{"ok":true,"scanned":346,"verified":122,"followed_back":1,"handles":["<伏せ>"]}
[2026-10-12T15:50:34.315Z] scanned=378 verified=152 new_candidates=30 DRY_RUN=false BASELINE_ONLY=false
scanned=378 verified=152 new_candidates=30 DRY_RUN=false BASELINE_ONLY=false
{"ok":true,"scanned":378,"verified":152,"followed_back":8,"handles":["<伏せ>"]}
[2026-10-13T15:50:30.362Z] scanned=409 verified=174 new_candidates=28 DRY_RUN=false BASELINE_ONLY=false
scanned=409 verified=174 new_candidates=28 DRY_RUN=false BASELINE_ONLY=false
{"ok":true,"scanned":409,"verified":174,"followed_back":8,"handles":["<伏せ>"]}
[2026-10-14T15:50:37.840Z] scanned=429 verified=196 new_candidates=21 DRY_RUN=false BASELINE_ONLY=false
scanned=429 verified=196 new_candidates=21 DRY_RUN=false BASELINE_ONLY=false
{"ok":true,"scanned":429,"verified":196,"followed_back":13,"handles":["<伏せ>"]}
[2026-10-15T15:47:38.287Z] scanned=445 verified=209 new_candidates=16 DRY_RUN=false BASELINE_ONLY=false
scanned=445 verified=209 new_candidates=16 DRY_RUN=false BASELINE_ONLY=false
[2026-10-15T15:47:44.551Z] followed back @<伏せ>
[2026-10-15T15:47:57.535Z] followed back @<伏せ>
[2026-10-15T15:48:10.534Z] followed back @<伏せ>
[2026-10-15T15:48:24.635Z] followed back @<伏せ>
[2026-10-15T15:48:36.315Z] followed back @<伏せ>
[2026-10-15T15:48:53.564Z] followed back @<伏せ>
[2026-10-15T15:49:05.223Z] followed back @<伏せ>
```

**読むだけ。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
