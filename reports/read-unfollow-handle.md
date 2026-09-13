# `unfollow-handle.js` の実物

**このレポートが作られた時刻: 2026-09-13 15:04:05 JST**

> x53 の判定: **B. フォロー中なのに外せていない。**
> ボタンは在る（`2040770556531011584-unfollow` ／「フォロー中」）。
> **探し方が違う。** 推測で書き換えず、実物を見る。

## 1. 全文

```
  50 行 / 最終更新 2026-08-09 17:52
```

```javascript
#!/usr/bin/env node
// unfollow-handle.js — Unfollow a single X handle via CDP.
// Usage: node unfollow-handle.js <handle>
// Output: JSON {ok, status: unfollowed/not_following/unconfirmed/error, reason?}
const { chromium } = require("playwright-core");
const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";

async function main() {
  const handle = process.argv[2];
  if (!handle) {
    console.log(JSON.stringify({ ok: false, error: "missing handle" }));
    process.exit(1);
  }
  // 2026-08-09: 専用ウィンドウ。Jordanのウィンドウに触れない。
  const { openWorkTab } = require("./lib/work-window.js");
  const _w = await openWorkTab("unfollow");
  const browser = _w.browser;
  const page = _w.page;
  try {
    // 2026-07-20: commit + waitForTimeout (concurrent Chrome load 対策、 unfollow-cleanup Timeout 事故由来)
    await page.bringToFront().catch(()=>{});
    await page.goto(`https://x.com/${handle}`, { waitUntil: "commit", timeout: 25000 }).catch(e => { throw e; });
    await page.waitForTimeout(4000);
    const unfollowBtn = await page.$('[data-testid$="-unfollow"]');
    if (!unfollowBtn) {
      console.log(JSON.stringify({ ok: false, status: "not_following", reason: "no unfollow button" }));
      return;
    }
    await unfollowBtn.click();
    await page.waitForTimeout(800);
    const confirm = await page.waitForSelector('[data-testid="confirmationSheetConfirm"]', { state: "visible", timeout: 4000 }).catch(() => null);
    if (confirm) {
      await confirm.click();
      await page.waitForTimeout(1500);
    }
    const verifyFollow = await page.$('[data-testid$="-follow"]');
    if (verifyFollow) {
      console.log(JSON.stringify({ ok: true, status: "unfollowed" }));
    } else {
      console.log(JSON.stringify({ ok: false, status: "unconfirmed", reason: "no follow button visible after unfollow" }));
    }
  } catch (e) {
    console.log(JSON.stringify({ ok: false, status: "error", reason: e.message }));
  } finally {
    await page.close();
    await browser.close();
  }
}

main();
```

## 2. これを呼んでいる側

```
  [reply-followers-cleanup.js] 100 行 / 最終更新 2026-09-06 21:32
    --- unfollow-handle の呼び方 ---
      5://   - else → call unfollow-handle, status=unfollowed
      6:const fs = require("fs");
      7:const { execSync } = require("child_process");
      11:const UNFOLLOW_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/unfollow-handle.js";
      58:    const out = execSync(`/usr/local/bin/node ${CHECK_SCRIPT} ${due.join(" ")}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
      81:      const out = execSync(`/usr/local/bin/node ${UNFOLLOW_SCRIPT} ${r.handle}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
      92:      log(`@${r.handle}: unfollow exec error: ${e2.message}`);

  [auto_detect_and_unfollow_inactive.js] 157 行 / 最終更新 2026-05-09 01:15
    --- unfollow-handle の呼び方 ---
      12: * It requires OpenClaw browser snapshots as input.
      15:const fs = require('fs');
      16:const path = require('path');

  [revenge-unfollow.js] 212 行 / 最終更新 2026-08-09 17:52
    --- unfollow-handle の呼び方 ---
      19:const fs = require("fs");
      20:const https = require("https");
      21:const { chromium } = require("playwright-core");
      39:    const nx = require("./lib/slack-notify.js");

  [unfollow-cleanup.js] 300 行 / 最終更新 2026-08-09 17:52
    --- unfollow-handle の呼び方 ---
      12: *  6. Invoke unfollow-handle.js per pick with 8-15s random interval
      25:const fs = require("fs");
      26:const path = require("path");
      27:const https = require("https");
      28:const { chromium } = require("playwright-core");
      29:const { execSync, spawnSync } = require("child_process");
      75:    const nx = require("./lib/slack-notify.js");
      154:// 2026-07-20: inline unfollow (child spawn 廃止、 CDP rapid reconnect 事故対策 for Task #154)


  --- scripts/ の unfollow 系 ---
    audit-wrong-unfollows.js
    audit-wrong-unfollows.js.bak18800
    auto_detect_and_unfollow_inactive.js
    check-unfollowed-status.js
    check-unfollowed-status.js.bak18800
    reply-followers-cleanup.js
    reply-followers-cleanup.js.bak.20260906-213249
    revenge-unfollow.js
    revenge-unfollow.js.bak.20260725-notify-batch2
    revenge-unfollow.js.bak18800
    run-unfollow.sh
    unfollow-cleanup.js
```

## 3. x17 で実際に動いた押し方（比較用）

`x17` はこの形で**外せた。** 差分を見るための基準として置く。

```javascript
const btn = await page.evaluate(() => {
  const bs = Array.from(document.querySelectorAll("button,[role=button]"));
  // ① data-testid が *-unfollow で終わる／unfollow で始まる
  for (const b of bs) {
    const t = (b.getAttribute("data-testid") || "");
    if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText||"").trim() };
  }
  // ② 文字が「フォロー中」か "Following"
  for (const b of bs) {
    const x = (b.innerText || "").trim();
    if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid")||"", text: x };
  }
  return null;
});
// 押したあと、**確認ダイアログを必ず確定する**
await page.evaluate(() => {
  const c = document.querySelector("[data-testid=confirmationSheetConfirm]");
  if (c) c.click();
});
```

**見るところ**

| 疑うところ | なぜ |
| --- | --- |
| 探す範囲を絞っている | `[data-testid=UserName]` の中など。**おすすめ欄と混ざるのを避けようとして、本体も外している**かもしれない |
| 文字が英語だけ | `Following` のみで **「フォロー中」を見ていない** |
| `-unfollow` を見ていない | 文字だけで探すと、描画の揺れで外す |
| 確認ダイアログを確定していない | 押しても**元に戻る** |
| 待ち時間が短い | プロフィールの描画前に探している |

## 4. 期限到来は増え続けている

```
  2026-09-12 の x09 時点: 197 件（30 日以上 放置が 164 件）
  2026-09-13 の x53 時点: **322 件**（30 日以上 放置が 223 件）
  いちばん古い: 2026-05-16
```

**外せていないので積み上がっている。** 直せば一気に減る。
ただし**一度に大量に外さない。** 上限は今のまま（1 回 5 件）で始める。

## 5. 費用

**読むだけ。LLM を呼ばない。押さない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
