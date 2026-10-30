# 止まった外す処理の理由（2026-10-30 21:17:53 JST・$0）

## 1. 止まっている処理と親子
```
98112     1       15:17:48 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js
98249 98112       15:16:55 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/unfollow-handle.js <伏せ>
```

## 2. reply-followers-cleanup のログの最後 25 行（.log と .err）
```
    at Dialog._onHandle (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crPage.js:696:28)
    at Dialog.accept (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/dialog.js:53:16)
    at Dialog.close (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/dialog.js:63:18)
    at DialogManager.dialogDidOpen (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/dialog.js:85:14)
    at FrameSession._onDialog (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crPage.js:689:45)
    at CRSession.<anonymous> (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crPage.js:352:119)
    at CRSession.emit (node:events:508:28) {
  type: 'error',
  method: 'Page.handleJavaScriptDialog',
  logs: undefined
}

Node.js v24.14.0

[2026-10-29T15:55:33.189Z] @<伏せ>: unfollow exec error: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/unfollow-handle.js <伏せ>
[x-action-guard] tweet: **止めた**（tweet: 前の回から 0 秒（60 秒 あける）・あと 60 秒）
[x-action-guard] tweet: **止めた**（tweet: 前の回から 30 秒（60 秒 あける）・あと 30 秒）
[x-action-guard] tweet: **止めた**（tweet: 前の回から 29 秒（60 秒 あける）・あと 31 秒）
[x-action-guard] tweet: **止めた**（tweet: 前の回から 31 秒（60 秒 あける）・あと 29 秒）

[2026-10-29T16:00:05.108Z] due 664 → 上限 20 件に絞る（残りは次回）
[2026-10-29T16:00:05.111Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mono_koto,moyana75,pref
[2026-10-29T20:03:20.000Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-10-29T21:00:05.086Z] due 665 → 上限 20 件に絞る（残りは次回）
[2026-10-29T21:00:05.088Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mono_koto,moyana75,pref
--- err
    at Dialog.close (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/dialog.js:63:18)
    at DialogManager.dialogDidOpen (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/dialog.js:85:14)
    at FrameSession._onDialog (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crPage.js:689:45)
    at CRSession.<anonymous> (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crPage.js:352:119)
    at CRSession.emit (node:events:508:28) {
  type: 'error',
  method: 'Page.handleJavaScriptDialog',
  logs: undefined
}

Node.js v24.14.0
[x-action-guard] tweet: **止めた**（tweet: 前の回から 0 秒（60 秒 あける）・あと 60 秒）
[x-action-guard] tweet: **止めた**（tweet: 前の回から 30 秒（60 秒 あける）・あと 30 秒）
[x-action-guard] tweet: **止めた**（tweet: 前の回から 29 秒（60 秒 あける）・あと 31 秒）
[x-action-guard] tweet: **止めた**（tweet: 前の回から 31 秒（60 秒 あける）・あと 29 秒）
```

## 3. reply-followers-cleanup が unfollow-handle を呼ぶところ（時間切れの有無）
```
5://   - else → call unfollow-handle, status=unfollowed
7:const { execSync } = require("child_process");
11:const UNFOLLOW_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/unfollow-handle.js";
58:    const out = execSync(`/usr/local/bin/node ${CHECK_SCRIPT} ${due.join(" ")}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
81:      const out = execSync(`/usr/local/bin/node ${UNFOLLOW_SCRIPT} ${r.handle}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
```

## 4. unfollow-handle.js の待ちと時間切れ
```
34:    process.exit(1);
39:    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
52:    await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 30000 });
53:    await page.waitForTimeout(3500);
76:    await page.waitForTimeout(900);
78:      .waitForSelector('[data-testid="confirmationSheetConfirm"]', { state: "visible", timeout: 4000 })
82:      await page.waitForTimeout(1500);
```

## 5. 終わらせる（30 分以上動いているものだけ・子から）
```
終わらせた: unfollow-handle pid=98249 経過 15:16:55
終わらせた: reply-followers-cleanup pid=98112 経過 15:17:51
--- 残り
```
**押していない（$0）。**
