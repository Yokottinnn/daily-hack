# follow-balance.js: 自分のハンドルを読むところで開き直す（2026-10-04 18:18 JST・$0）

```
  控え: follow-balance.js.bak-x238-20261004-181822
  当たった数（1 なら当たり）: ① 1 ／ ② 1
  node --check rc=0 
  置いた。605 行 ／ x238 の印 2 個
```

## 直したあとの該当箇所

```
212:    // x238: プロフィールへのリンクが出るまで待つ。出なければ 1 回 開き直す（3 秒 固定では空のページを読んでいた）
213-    { const ok = () => page.waitForSelector('[data-testid=AppTabBar_Profile_Link]', { timeout: 15000 }).then(() => true).catch(() => false);
214-      if (!(await ok())) { log("/home が空。開き直す"); await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {}); await ok(); } }
215-    if (/login|i\/flow/.test(page.url())) { log("**ログインが切れている。何もしない。**"); await page.close(); process.exit(0); }
222:  if (!me) { let u = "", L = -1; try { u = page.url(); L = await page.evaluate(() => (document.body && document.body.innerText || "").length); } catch (e) {} log("**自分のハンドルが読め�
```

- 戻すときは `follow-balance.js.bak-x238-20261004-181822` を follow-balance.js に戻す

**走らせていない。外していない。フォローしていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
