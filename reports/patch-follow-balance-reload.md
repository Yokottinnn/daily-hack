# follow-balance.js を直す（2026-10-03 21:26 JST・$0）

**このレポートが作られた時刻: 2026-10-03 21:26:06 JST**

```
  控え: follow-balance.js.bak-x219-20261003-212606
  当たった数: ① 1 ／ ② 1
  node --check rc=0 
  置いた。558 行
  x219 の印: 2
```

## 直したあとの該当箇所

```
450-    try {
451-      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
452:      // x219: 空のページは開き直す（2026-10-03。下調べで続けて開いたあと、本文が空のページが返り 0 件になっていた）
453-      const x219Ready = () => page.waitForSelector('[data-testid="UserName"], [data-testid="emptyState"]', { timeout: 15000 }).then(() => true).catch(() => false);
454-      if (!(await x219Ready())) {
455-        log("  @" + h + ": ページが空。開き直す");
456-        await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {});
457-        await x219Ready();
458-      }
459-      await page.waitForTimeout(1500);
460-      const findBtn = () => page.evaluate(() => {
461-        const bs = Array.from(document.querySelectorAll("button,[role=button]"));

181:  await page.waitForTimeout(4700 + Math.floor(Math.random() * 1500));   // x219: 続けて開きすぎると X が空のページを返す（2.2 秒 → 4.7〜6.2 秒）
```

- **ジョブは走らせていない。** 次の定時（11:45 / 18:45）から効く
- 戻すときは `follow-balance.js.bak-x219-20261003-212606` を follow-balance.js に戻す

**外していない。フォローしていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
