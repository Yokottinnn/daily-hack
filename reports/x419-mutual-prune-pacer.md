# mutual-prune に外す間隔の台帳を入れる（2026-11-04 00:09 JST・$0）
```
pacer: /Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs
--- 外す処理の周り（読むだけ）
8://   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
47:  for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
77:  await page.waitForTimeout(4000);
93:    await page.waitForTimeout(1200);
105:  await page.waitForTimeout(3500 + Math.floor(Math.random() * 1500));   // x224: 続けて開きすぎない
141:    await page.waitForTimeout(3000);
247:      await page.waitForTimeout(1500);
252:          if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
261:      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
265:      // x341（2026-10-25）: サブスクを出しているアカウントは「<id>-unfollow」が「購入する」ボタンで、押しても外れない。
266:      // 外すのはアイコンのボタン（aria「〇〇さんのフォローを解除」）→ 出るメニューの「〇〇さんのフォローを解除」�
267:      if (await page.locator('[aria-label$="さんのフォローを解除"]').count()) {
268:        await page.locator('[aria-label$="さんのフォローを解除"]').first().click({ timeout: 8000 }).catch(() => {});
269:        await page.waitForTimeout(1200);
270:        await page.locator('[role="menuitem"]:has-text("さんのフォローを解除")').first().click({ timeout: 5000 }).catch(() => {});
274:          const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
279:      await page.waitForTimeout(1200);
281:        const c = document.querySelector("[data-testid=confirmationSheetConfirm]");
284:      await page.waitForTimeout(2500);
287:        if (document.querySelector('[aria-label$="さんのフォローを解除"]')) return "解除ボタンが残っている";
294:        state[h] = { unfollowed_at: new Date().toISOString(), why: d.why, followers: d.followers, idle_days: d.idle };
299:      await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));
315:        if (!d2 || !d2.unfollowed_at) continue;
319:        if (e2.unfollowed_at && e2.still_following === false) continue;
321:        e2.unfollowed_at = e2.unfollowed_at || d2.unfollowed_at;
322:        e2.unfollow_source = "mutual-prune";
323:        e2.unfollow_reason = d2.why || null;
① 差し込んだ（267 行目の前・止め方 break;）
① 入れた・構文 OK
267:      // x419: フォロー解除は全ジョブ共有の台帳で 120 秒あけ・30 分 6 回まで（最上位ルール 23）。空くまで待って記録する。空かなければこの回�
268:      { const _r = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("unfollow", 35 * 60 * 1000); if (!_r.ok) { console.log("  間隔待ちで空かない（" + _r.rea
269-      if (await page.locator('[aria-label$="さんのフォローを解除"]').count()) {
--- ③ 載せ直す（走らせない）
bootstrap rc=0
**載っている**
	state = not running 	runs = 0 	last exit code = (never exited) 
```
**LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。外す条件・猶予・上限は変えていない**
