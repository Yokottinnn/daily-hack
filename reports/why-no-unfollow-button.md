# なぜアンフォローのボタンが見つからないのか（2026-09-06 22:31 JST・費用 $0）

> **5 件すべてが同じ失敗。** 個別の事情ではなく共通原因がある。
> **押さない。見るだけ。**

## 1. `unfollow-handle.js` の全文

- 50 行 / 更新 2026-08-09 17:52

```javascript
     1	#!/usr/bin/env node
     2	// unfollow-handle.js — Unfollow a single X handle via CDP.
     3	// Usage: node unfollow-handle.js <handle>
     4	// Output: JSON {ok, status: unfollowed/not_following/unconfirmed/error, reason?}
     5	const { chromium } = require("playwright-core");
     6	const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
     7	
     8	async function main() {
     9	  const handle = process.argv[2];
    10	  if (!handle) {
    11	    console.log(JSON.stringify({ ok: false, error: "missing handle" }));
    12	    process.exit(1);
    13	  }
    14	  // 2026-08-09: 専用ウィンドウ。Jordanのウィンドウに触れない。
    15	  const { openWorkTab } = require("./lib/work-window.js");
    16	  const _w = await openWorkTab("unfollow");
    17	  const browser = _w.browser;
    18	  const page = _w.page;
    19	  try {
    20	    // 2026-07-20: commit + waitForTimeout (concurrent Chrome load 対策、 unfollow-cleanup Timeout 事故由来)
    21	    await page.bringToFront().catch(()=>{});
    22	    await page.goto(`https://x.com/${handle}`, { waitUntil: "commit", timeout: 25000 }).catch(e => { throw e; });
    23	    await page.waitForTimeout(4000);
    24	    const unfollowBtn = await page.$('[data-testid$="-unfollow"]');
    25	    if (!unfollowBtn) {
    26	      console.log(JSON.stringify({ ok: false, status: "not_following", reason: "no unfollow button" }));
    27	      return;
    28	    }
    29	    await unfollowBtn.click();
    30	    await page.waitForTimeout(800);
    31	    const confirm = await page.waitForSelector('[data-testid="confirmationSheetConfirm"]', { state: "visible", timeout: 4000 }).catch(() => null);
    32	    if (confirm) {
    33	      await confirm.click();
    34	      await page.waitForTimeout(1500);
    35	    }
    36	    const verifyFollow = await page.$('[data-testid$="-follow"]');
    37	    if (verifyFollow) {
    38	      console.log(JSON.stringify({ ok: true, status: "unfollowed" }));
    39	    } else {
    40	      console.log(JSON.stringify({ ok: false, status: "unconfirmed", reason: "no follow button visible after unfollow" }));
    41	    }
    42	  } catch (e) {
    43	    console.log(JSON.stringify({ ok: false, status: "error", reason: e.message }));
    44	  } finally {
    45	    await page.close();
    46	    await browser.close();
    47	  }
    48	}
    49	
    50	main();
```

## 2. 対象のプロフィールを開いて、ボタンの実物を見る

**押さない。** 文字列と `data-testid` を読むだけ。

- 対象: 2 件（ハンドルは伏せる）

```
node:internal/modules/cjs/loader:1478
  throw err;
  ^

Error: Cannot find module 'playwright'
Require stack:
- /[eval]
    at Module._resolveFilename (node:internal/modules/cjs/loader:1475:15)
    at wrapResolveFilename (node:internal/modules/cjs/loader:1048:27)
    at defaultResolveImplForCJSLoading (node:internal/modules/cjs/loader:1072:10)
    at resolveForCJSWithHooks (node:internal/modules/cjs/loader:1093:12)
    at Module._load (node:internal/modules/cjs/loader:1261:25)
    at wrapModuleLoad (node:internal/modules/cjs/loader:255:19)
    at Module.require (node:internal/modules/cjs/loader:1575:12)
    at require (node:internal/modules/helpers:191:16)
    at [eval]:2:22
    at runScriptInThisContext (node:internal/vm:219:10) {
  code: 'MODULE_NOT_FOUND',
  requireStack: [ '/[eval]' ]
}

Node.js v26.0.0
```

**`Follow` / `フォロー` しか無ければ「既に外れている」。**
**`Following` / `フォロー中` があるのに掴めていないなら「セレクタが古い」。**

## 3. 期限到来 197 件の古さ

```
  期限到来: 197 件
    0〜6日      5 件 放置
    7〜13日     3 件 放置
    14〜29日    25 件 放置
    30日以上     164 件 放置
  いちばん古い期限: 2026-05-20
```

**30 日以上 放置が多ければ、その間に手で外している可能性がある。**

---

**ボタンを押していない。アンフォローもフォローもしていない（$0）。**
