# 比率の調整：載せ直しと、外す間隔の作りを読む（2026-11-02 22:13 JST・$0）

## ① 載せ直す（走らせない）
```
ls: /Users/ny/Library/LaunchAgents/ai.openclaw.follow-balance.plist.disabled: No such file or directory
-rw-r--r--  1 ny  staff  1667 Oct 30 00:44 /Users/ny/Library/LaunchAgents/ai.openclaw.follow-balance.plist
bootstrap rc=0
	state = not running 	runs = 0 	last exit code = (never exited) 
**載っている**
65:ai.openclaw.follow-balance
[{"Hour":11,"Minute":45},{"Hour":18,"Minute":45},{"Hour":15,"Minute":15}]
{"MAX_PROFILE_READS":"40","DECIDE_BUDGET_S":"150","FOLLOW_RATIO_GLIDE":"370:0.57,500:0.50,700:0.42,1000:0.33","LIST_BUDGET_S":"110","MIN_UNFOLLOW":"20","HOME":"\/Users\/ny","MAX_UNFOLLOW":"20","PATH":"\/usr\/local\/bin:\/usr\/bin:\/bin:\/usr\/sbin:\/sbin","GRACE_DAYS":"1"}
```

## ② 打ち切りの秒数（DECIDE_BUDGET）
```
47:const DECIDE_BUDGET_S = Number(process.env.DECIDE_BUDGET_S || 200);
459:  let timeUp = false;
461:    const dl2 = Date.now() + DECIDE_BUDGET_S * 1000;
464:      if (Date.now() > dl2) { timeUp = true; break; }
478:      (timeUp ? "（**" + DECIDE_BUDGET_S + " 秒 で打ち切った。相互を見切れていない**）" : ""));
```

## ③ 外す処理の待ち（pacer・waitForTimeout・sleep）
```
8://   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
72:  for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
130:  await page.waitForTimeout(4000);
173:    await page.waitForTimeout(1200);
181:  await page.waitForTimeout(4700 + Math.floor(Math.random() * 1500));   // x219: 続けて開きすぎると X が空のページを返す（2.2 秒 → 4.7〜6.2 秒）
309:    await page.waitForTimeout(4500);
424:      if (!v || typeof v !== "object" || v.followback_status !== "no" || v.unfollowed_at || !v.scheduled_unfollow_at) continue;
425:      if (new Date(v.scheduled_unfollow_at).getTime() < now) x227Due.add(String(k).replace(/^@/, "").toLowerCase());
504:      await page.waitForTimeout(1500);
509:          if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
524:        await page.waitForTimeout(900);
547:                                !/-unfollow:/.test(String(why.follow_btns || "")));
562:      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
566:      // x341（2026-10-25）: サブスクを出しているアカウントは「<id>-unfollow」が「購入する」ボタンで、押しても外れない。
570:        await page.waitForTimeout(1200);
575:          const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
580:      await page.waitForTimeout(1200);
582:        const c2 = document.querySelector("[data-testid=confirmationSheetConfirm]");
585:      await page.waitForTimeout(2500);
595:        state[h] = { unfollowed_at: new Date().toISOString(), why: c.why, rank: c.rank };
601:      await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));
616:        rf[k].unfollowed_at = new Date().toISOString(); rf[k].unfollow_source = "follow-balance"; rf[k].unfollow_reason = u.why; wrote++;
```

## ③ 外す処理の前後 40 行
```
            fs.writeFileSync(NOTFOLLOW, JSON.stringify([...notFollowSet].sort(), null, 2));
            JSON.parse(fs.readFileSync(NOTFOLLOW, "utf8"));   // **書いた JSON を読み直す**
          } catch (e) { log("  （覚えられない: " + String(e.message).slice(0, 60) + "）"); }
          log("  @" + h + ": **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）");
        } else {
          log("  @" + h + ": フォロー中のボタンが無い" +
              (why ? " — " + JSON.stringify(why) : "（理由も取れない）"));
        }
        continue;
      }
      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
        log("  @" + h + ": 「フォロー中」ではないので押さない: " + (btn.text || btn.testid));
        continue;
      }
      // x341（2026-10-25）: サブスクを出しているアカウントは「<id>-unfollow」が「購入する」ボタンで、押しても外れない。
      // 外すのはアイコンのボタン（aria「〇〇さんのフォローを解除」）→ 出るメニューの「〇〇さんのフォローを解除」。マウス操作で押す（JS の
      if (await page.locator('[aria-label$="さんのフォローを解除"]').count()) {
        await page.locator('[aria-label$="さんのフォローを解除"]').first().click({ timeout: 8000 }).catch(() => {});
        await page.waitForTimeout(1200);
        await page.locator('[role="menuitem"]:has-text("さんのフォローを解除")').first().click({ timeout: 5000 }).catch(() => {});
      } else {
        await page.evaluate(() => {
          const bs = Array.from(document.querySelectorAll("button,[role=button]"));
          const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
                    bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
          if (t) t.click();
        });
      }
      await page.waitForTimeout(1200);
      await page.evaluate(() => {
        const c2 = document.querySelector("[data-testid=confirmationSheetConfirm]");
        if (c2) c2.click();
      });
      await page.waitForTimeout(2500);
      const after = await page.evaluate(() => {
        // x341: 解除のアイコンが残っていれば外れていない。「購入する」は外す状態の判定に使わない
        if (document.querySelector('[aria-label$="さんのフォローを解除"]')) return "解除ボタンが残っている";
        const bs = Array.from(document.querySelectorAll("button,[role=button]")).filter((b) => !/購入する/.test(b.innerText || ""));
        const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
        return t ? ((t.innerText || "").trim() || t.getAttribute("data-testid")) : "-";
      });
      if (FOLLOW_RE.test(after)) {
        done++;
        state[h] = { unfollowed_at: new Date().toISOString(), why: c.why, rank: c.rank };
        x227Unf.push({ h, why: c.why });   // x227
        log("  ✂ @" + h + " — 外れた（" + c.why + "）");
```

## pacer の部品が在るか
```
ls: /Users/ny/.openclaw/workspace/scripts/x-action-pacer.cjs: No such file or directory
-rw-r--r--  1 ny  staff  6186 Oct 26 00:19 /Users/ny/projects/anta-baka-x/blog/ops/lib/x-action-pacer.cjs
/Users/ny/.openclaw/workspace/scripts/follow-handle.js
/Users/ny/.openclaw/workspace/scripts/post-comment.js
/Users/ny/.openclaw/workspace/scripts/unfollow-handle.js
```
