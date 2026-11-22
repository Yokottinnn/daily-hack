# なぜ外さないのか（2026-09-27 15:07 JST・$0）

**このレポートが作られた時刻: 2026-09-27 15:07:34 JST**

> **読むだけ。** フォローもアンフォローもしていない。

## 1. 今日の収支（**これが問題そのもの**）

```
  followed.json の件数: 0（今日 = 2026-09-27 JST）

  日付         フォローした数

  --- 今日アンフォローした数（ログの unfollowed 配列を数える）---
  mutual-prune               0 回の結果行 / 外した合計 0 件（ログ全体）
  reply-followers-cleanup    0 回の結果行 / 外した合計 0 件（ログ全体）
```

> **「ログ全体」であって今日ぶんではない。** それでも、フォロー側の 1 日ぶんと比べれば桁が分かる。

## 2. フォロー側は 1 日 何回 撃つか

```
  === ai.openclaw.competitor-follower-follow ===
    Array {
        Dict {
            Hour = 11
            Minute = 30
        }
        Dict {
            Hour = 18
            Minute = 30
        }
    }
    Dict {
        COMPETITOR_FOLLOW_DAILY_CAP = 30
        PATH = /usr/local/bin:/usr/bin:/bin
        FORCE_RUN = 1
    }

  === ai.openclaw.hashtag-follow ===
    Array {
        Dict {
            Hour = 10
            Minute = 15
        }
        Dict {
            Hour = 17
            Minute = 0
        }
    }
    Dict {
        HASHTAG_FOLLOW_DAILY_CAP = 90
        PATH = /usr/local/bin:/usr/bin:/bin
        FORCE_RUN = 1
    }

```

## 3. `mutual-prune.js` の判定と実行（**ここに答えが在る**）

```javascript
       1	  log("=== mutual-prune start (dry=" + DRY + " max=" + MAXN + " inactive=" + INACTIVE_DAYS +
       2	      "d ratio=" + RATIO + " absMin=" + ABS_MIN + " grace=" + GRACE_DAYS + "d) ===");
       3	
       4	  let b;
       5	  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
       6	  catch (e) { log("CDP に繋がらない: " + String(e.message).slice(0, 120)); return; }
       7	  const ctx = b.contexts()[0];
       8	  if (!ctx) { log("context が無い。何もしない。"); return; }
       9	  const page = await ctx.newPage();
      10	
      11	  let me = null, myFollowers = null;
      12	  try {
      13	    await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 30000 });
      14	    await page.waitForTimeout(3000);
      15	    if (/login|i\/flow/.test(page.url())) { log("**ログインが切れている。何もしない。**"); await page.close(); return; }
      16	    me = await page.evaluate(() => {
      17	      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
      18	      const m = a && (a.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
      19	      return m ? m[1] : null;
      20	    });
      21	  } catch (e) { log("/home を開けない: " + String(e.message).slice(0, 100)); await page.close(); return; }
      22	  if (!me) { log("**自分のハンドルが読めない。何もしない。**"); await page.close(); return; }
      23	
      24	  // 自分のフォロワー数。**読めなければ「格下」判定を丸ごと使わない。**
      25	  try {
      26	    const mine = await readProfile(page, me);
      27	    myFollowers = parseCount(mine.followersText);
      28	  } catch (e) {}
      29	  log("自分: @" + me + " / フォロワー " + (myFollowers === null ? "読めない" : myFollowers));
      30	
      31	  const following = await scrapeList(page, "https://x.com/" + me + "/following", 400);
      32	  log("フォロー中: " + following.size + " 件");
      33	  if (following.size === 0) { log("**0 件しか読めない。ページが壊れている。何もしない。**"); await page.close(); return; }
      34	
      35	  const followers = await scrapeList(page, "https://x.com/" + me + "/followers", 600);
      36	  log("フォロワー: " + followers.size + " 件");
      37	
      38	  const wl = loadWhitelist();
      39	  log("ホワイトリスト: " + wl.size + " 件");
      40	
      41	  // フォローした日時。猶予の判定に使う
      42	  const followedAt = {};
      43	  for (const p of [FOLLOW_STATE, STATE]) {
      44	    try {
      45	      const d = JSON.parse(fs.readFileSync(p, "utf8"));
      46	      for (const [h, e] of Object.entries(d)) {
      47	        if (e && (e.followed_at || e.at)) followedAt[h.toLowerCase()] = e.followed_at || e.at;
      48	      }
      49	    } catch (e) {}
      50	  }
      51	
      52	  const lowerFollowers = new Set([...followers].map((h) => h.toLowerCase()));
      53	  const now = Date.now();
      54	
      55	  // **相互だけを対象にする。** 片思いは既存の別ジョブの担当。
      56	  const mutual = [...following].filter((h) => lowerFollowers.has(h.toLowerCase()));
      57	  log("相互フォロー: " + mutual.length + " 件");
      58	
      59	  let state = {};
      60	  try { state = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
      61	
      62	  const decided = [];
      63	  let looked = 0;
      64	  for (const h of mutual) {
      65	    if (decided.filter((d) => d.cut).length >= MAXN) break;
      66	    const k = h.toLowerCase();
      67	    if (wl.has(k)) { decided.push({ h, cut: false, why: "ホワイトリスト" }); continue; }
      68	    const fa = followedAt[k];
      69	    if (fa) {
      70	      const days = (now - new Date(fa).getTime()) / 86400000;
      71	      if (isFinite(days) && days < GRACE_DAYS) {
      72	        decided.push({ h, cut: false, why: "フォローしてまだ " + Math.floor(days) + " 日（猶予 " + GRACE_DAYS + " 日）" });
      73	        continue;
      74	      }
      75	    }
      76	
      77	    let p;
      78	    try { p = await readProfile(page, h); looked++; }
      79	    catch (e) { decided.push({ h, cut: false, why: "プロフィールが開けない: " + String(e.message).slice(0, 50) }); continue; }
      80	
      81	    if (p.verified) { decided.push({ h, cut: false, why: "認証済み" }); continue; }
      82	
      83	    const fc = parseCount(p.followersText);
      84	    if (fc === null) { decided.push({ h, cut: false, why: "フォロワー数が読めない（読めない＝悪いではない）" }); continue; }
      85	    if (!p.lastPost) { decided.push({ h, cut: false, why: "最終投稿が読めない（読めない＝悪いではない）" }); continue; }
      86	
      87	    const idle = Math.floor((now - new Date(p.lastPost).getTime()) / 86400000);
      88	    const reasons = [];
      89	    if (idle >= INACTIVE_DAYS) reasons.push("休眠 " + idle + " 日");
      90	    if (myFollowers !== null && fc < myFollowers * RATIO && fc < ABS_MIN) {
      91	      reasons.push("格下 " + fc + " < min(" + Math.round(myFollowers * RATIO) + ", " + ABS_MIN + ")");
      92	    }
      93	
      94	    if (!reasons.length) { decided.push({ h, cut: false, why: "残す（" + fc + " フォロワー / " + idle + " 日前に投稿）" }); continue; }
      95	    decided.push({ h, cut: true, why: reasons.join(" ＋ "), followers: fc, idle: idle });
      96	  }
      97	
      98	  const cuts = decided.filter((d) => d.cut);
      99	  log("見たプロフィール: " + looked + " 件 / **外す候補: " + cuts.length + " 件**");
     100	  for (const d of decided) {
     101	    log("  " + (d.cut ? "✂ " : "・ ") + "@" + d.h + " — " + d.why);
     102	  }
     103	
     104	  if (DRY) {
     105	    log("**DRY_RUN。1 件も外していない。**");
     106	    await page.close();
     107	    return;
     108	  }
     109	
     110	  let done = 0;
     111	  for (const d of cuts.slice(0, MAXN)) {
     112	    const h = d.h;
     113	    try {
     114	      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
     115	      await page.waitForTimeout(3500);
     116	      const btn = await page.evaluate(() => {
     117	        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
     118	        for (const b of bs) {
     119	          const t = b.getAttribute("data-testid") || "";
     120	          if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
     121	        }
     122	        for (const b of bs) {
     123	          const x = (b.innerText || "").trim();
     124	          if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid") || "", text: x };
     125	        }
     126	        return null;
     127	      });
     128	      if (!btn) { log("  @" + h + ": フォロー中のボタンが無い（既に外れている可能性）"); continue; }
     129	      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
     130	        log("  @" + h + ": 「フォロー中」ではないので押さない: " + (btn.text || btn.testid));
     131	        continue;
     132	      }
     133	      await page.evaluate(() => {
     134	        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
     135	        const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
     136	                  bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
     137	        if (t) t.click();
     138	      });
     139	      await page.waitForTimeout(1200);
     140	      await page.evaluate(() => {
     141	        const c = document.querySelector("[data-testid=confirmationSheetConfirm]");
     142	        if (c) c.click();
     143	      });
     144	      await page.waitForTimeout(2500);
     145	      const after = await page.evaluate(() => {
     146	        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
     147	        const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
     148	        return t ? ((t.innerText || "").trim() || t.getAttribute("data-testid")) : "-";
     149	      });
     150	      if (FOLLOW_RE.test(after)) {
     151	        done++;
     152	        state[h] = { unfollowed_at: new Date().toISOString(), why: d.why, followers: d.followers, idle_days: d.idle };
     153	        log("  ✂ @" + h + " — 外れた（" + d.why + "）");
     154	      } else {
     155	        log("  @" + h + ": 押したが外れていない（" + after + "）");
     156	      }
     157	      await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));
     158	    } catch (e) { log("  @" + h + ": 例外 " + String(e.message).slice(0, 90)); }
     159	  }
     160	
     161	  try { fs.writeFileSync(STATE, JSON.stringify(state, null, 2)); } catch (e) {}
     162	
     163	  // 2026-09-15 x81: 外した相手を reply-followers.json にも反映する。
     164	  // フォロー系ジョブはそちらを見て「既にフォロー済み」を判定するため、
     165	  // 印を付けないと外したのに「フォロー中」と誤認される。
     166	  try {
     167	    if (fs.existsSync(FOLLOW_STATE)) {
     168	      const rf = JSON.parse(fs.readFileSync(FOLLOW_STATE, "utf8"));
     169	      const lower = {};
     170	      for (const k of Object.keys(rf)) lower[k.toLowerCase()] = k;
     171	      let touched = 0;
     172	      for (const [h2, d2] of Object.entries(state)) {
     173	        if (!d2 || !d2.unfollowed_at) continue;
     174	        const key = lower[String(h2).toLowerCase()];
     175	        if (!key) continue;
     176	        const e2 = rf[key] || {};
     177	        if (e2.unfollowed_at && e2.still_following === false) continue;
     178	        e2.still_following = false;
     179	        e2.unfollowed_at = e2.unfollowed_at || d2.unfollowed_at;
     180	        e2.unfollow_source = "mutual-prune";
     181	        e2.unfollow_reason = d2.why || null;
     182	        rf[key] = e2;
     183	        touched++;
     184	      }
     185	      if (touched) {
     186	        const tmp2 = FOLLOW_STATE + ".tmp";
     187	        fs.writeFileSync(tmp2, JSON.stringify(rf, null, 2));
     188	        fs.renameSync(tmp2, FOLLOW_STATE);
     189	      }
     190	      log("reply-followers.json に反映: " + touched + " 件");
     191	    }
     192	  } catch (e) { log("reply-followers 反映に失敗: " + String(e.message).slice(0, 80)); }
     193	  log("=== mutual-prune done: " + done + " 件 外した ===");
     194	  await page.close();
     195	})().catch((e) => { log("落ちた: " + String(e && e.message).slice(0, 200)); });
```

## 4. ゴーストは誰が外すのか

**19 件を検知して 0 件しか外していない。** どこで止まっているかを見る。

```
  --- ghost / ghosts を扱っているスクリプト ---
  unfollow-via-playwright.js
```

### `reply-followers-cleanup.js` の ghost まわり

```javascript
```


## 5. 守る側の材料

**「反応をくれた人」と「フォローから 7 日未満」だけを守る**と決まった（2026-09-27）。
その 2 つが judgable かを見る。

```
  reply-followers.json の件数: 530
  followed_at            2026-05-13T08:02:51.436Z
  followback_status      no
  scheduled_unfollow_at  2026-05-20T17:10:54.082Z
  source                 comment-orchestrator
  comment_id             comment-20260513-1702-0
  followback_judgment_at 2026-05-15T16:15:18.334Z
  still_following        false
  follows_back           false
  checked_at             2026-09-13T10:45:03.985Z
  unfollowed_at          2026-09-13T10:42:41.440Z
  unfollow_source        reconciled
```

---

## 読み方

| 出方 | 次の一手 |
| --- | --- |
| §3 に `MAXN` や比率の門が在り、そこで落ちている | **上限を上げる**か、**門を緩める** |
| ゴーストを外す口がどこにも無い | **外す側を足す**（検知だけで終わっている） |
| §1 でフォローが 1 日 数十件 | **同じ数だけ外す仕掛け**が要る |
| §5 に反応の記録が在る | **守る側の判定に使える** |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
