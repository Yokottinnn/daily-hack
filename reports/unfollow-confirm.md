# 押したあとの処理を読む（2026-10-25 17:10:56 JST・$0）
```
   556	              (why ? " — " + JSON.stringify(why) : "（理由も取れない）"));
   557	        }
   558	        continue;
   559	      }
   560	      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
   561	        log("  @" + h + ": 「フォロー中」ではないので押さない: " + (btn.text || btn.testid));
   562	        continue;
   563	      }
   564	      await page.evaluate(() => {
   565	        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
   566	        const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
   567	                  bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
   568	        if (t) t.click();
   569	      });
   570	      await page.waitForTimeout(1200);
   571	      await page.evaluate(() => {
   572	        const c2 = document.querySelector("[data-testid=confirmationSheetConfirm]");
   573	        if (c2) c2.click();
   574	      });
   575	      await page.waitForTimeout(2500);
   576	      const after = await page.evaluate(() => {
   577	        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
   578	        const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
   579	        return t ? ((t.innerText || "").trim() || t.getAttribute("data-testid")) : "-";
   580	      });
   581	      if (FOLLOW_RE.test(after)) {
   582	        done++;
   583	        state[h] = { unfollowed_at: new Date().toISOString(), why: c.why, rank: c.rank };
   584	        x227Unf.push({ h, why: c.why });   // x227
   585	        log("  ✂ @" + h + " — 外れた（" + c.why + "）");
   586	      } else {
   587	        log("  @" + h + ": 押したが外れていない（" + after + "）");
   588	      }
   589	      await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));
   590	    } catch (e) {
   591	      log("  @" + h + ": 例外 " + String(e.message).slice(0, 80));
   592	    }
   593	  }
   594	  try { fs.writeFileSync(STATE, JSON.stringify(state, null, 2)); JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
   595	  // x227: 外した人を reply-followers.json にも書く（フォロバ判定の側が「外す予定」を持ち続けないように）
   596	  if (x227Unf.length) {
   597	    try {
   598	      const rf = JSON.parse(fs.readFileSync(ENGAGED, "utf8"));
   599	      const low = {}; for (const k of Object.keys(rf)) low[String(k).replace(/^@/, "").toLowerCase()] = k;
   600	      let wrote = 0;
```

## mutual-prune.js の同じ処理（比べる）
```
8://   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
47:  for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
252:          if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
261:      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
267:        const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
273:        const c = document.querySelector("[data-testid=confirmationSheetConfirm]");
284:        state[h] = { unfollowed_at: new Date().toISOString(), why: d.why, followers: d.followers, idle_days: d.idle };
285:        log("  ✂ @" + h + " — 外れた（" + d.why + "）");
287:        log("  @" + h + ": 押したが外れていない（" + after + "）");
305:        if (!d2 || !d2.unfollowed_at) continue;
309:        if (e2.unfollowed_at && e2.still_following === false) continue;
311:        e2.unfollowed_at = e2.unfollowed_at || d2.unfollowed_at;
312:        e2.unfollow_source = "mutual-prune";
313:        e2.unfollow_reason = d2.why || null;
```
**読んだだけ。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
