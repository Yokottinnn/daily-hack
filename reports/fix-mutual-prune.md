# mutual-prune.js を直す（2026-10-04 01:02 JST・$0）

**このレポートが作られた時刻: 2026-10-04 01:02:47 JST**

## ④ 居座っている処理を止める

```
    PID STARTED                       ELAPSED COMMAND
  68155 Sat Oct  3 05:03:08 2026     19:59:39 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/mutual-prune.js
  止めた。いま: state=not running pid=
```

## ①〜③ mutual-prune.js を直す

```
  控え: mutual-prune.js.bak-x224-20261004-010247
  当たった数: ① 1 ／ ② 1 ／ ③ 1
  node --check rc=0 
  置いた。321 行 ／ x224 の印 4 個
```

## 直したあとの該当箇所

```
100:  // x224: 空のページは開き直す（2026-10-03。空のページで「ボタンが無い」「フォロワー数が読めない」になっていた）
101-  { const ok = () => page.waitForSelector('[data-testid="UserName"], [data-testid="emptyState"]', { timeout: 12000 }).then(() => true).catch(() => false);
102-    if (!(await ok())) { log("  @" + handle + ": ページが空。開き直す"); await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {}); await ok(); } }
103-  await page.waitForTimeout(3500 + Math.floor(Math.random() * 1500));   // x224: 続けて開きすぎない
--
237:      // x224: 空のページは開き直す（2026-10-03。空のページで「ボタンが無い」「フォロワー数が読めない」になっていた）
238-      { const ok = () => page.waitForSelector('[data-testid="UserName"], [data-testid="emptyState"]', { timeout: 15000 }).then(() => true).catch(() => false);
239-        if (!(await ok())) { log("  @" + h + ": ページが空。開き直す"); await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {}); await ok(); } }
240-      await page.waitForTimeout(1500);
103:  await page.waitForTimeout(3500 + Math.floor(Math.random() * 1500));   // x224: 続けて開きすぎない
320:  setTimeout(() => process.exit(0), 1000);   // x224: page.close() だけでは node が終わらず、次の定時を飛ばしていた
  await page.close();
  setTimeout(() => process.exit(0), 1000);   // x224: page.close() だけでは node が終わらず、次の定時を飛ばしていた
})().catch((e) => { setTimeout(() => process.exit(1), 1000); log("落ちた: " + String(e && e.message).slice(0, 200)); });
```

- **ジョブは走らせていない。** 次の定時（6 時 / 18 時）から効く
- 戻すときは `mutual-prune.js.bak-x224-20261004-010247` を mutual-prune.js に戻す

**外していない。フォローしていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
