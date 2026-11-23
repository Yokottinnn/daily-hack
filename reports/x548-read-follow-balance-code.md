# follow-balance のコードを読む（2026-11-23 22:43 JST・読むだけ・$0）

```
-rw-r--r--  1 ny  staff  40926 Nov  3 21:29 ~/.openclaw/workspace/scripts/follow-balance.js
     646 ~/.openclaw/workspace/scripts/follow-balance.js
```

## 接続のところ（connectOverCDP・newPage・contexts）
```
7://   - connectOverCDP で既存の Chrome に繋ぐ（新しく起動しない）
203:  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
205:  const ctx = b.contexts()[0];
207:  const page = await ctx.newPage();
215:    if (/login|i\/flow/.test(page.url())) { log("**ログインが切れている。何もしない。**"); await page.close(); process.exit(0); }
221:  } catch (e) { log("/home を開けない: " + String(e.message).slice(0, 100)); await page.close(); process.exit(0); }
224:  if (!me) { let u = "", L = -1; try { u = page.url(); L = await page.evaluate(() => (document.body && document.body.innerText || "").length); } catch (e) {} log("**自分のハンドルが読め�
231:    catch (e) { log("**一覧のキャッシュが読めない。MODE=collect を先に走らせる。** " + String(e.message).slice(0, 80)); await page.close(); process.exit(0); }
235:      await page.close(); process.exit(0);
240:    if (following.size === 0) { log("**キャッシュが空。何もしない。**"); await page.close(); process.exit(0); }
246:    if (following.size === 0) { log("**0 件しか読めない。ページが壊れている。何もしない。**"); await page.close(); process.exit(0); }
264:      await page.close(); process.exit(0);
380:    try { await page.close(); } catch (e) {}
495:    await page.close();
641:  await page.close();
642:  // **`connectOverCDP` の接続が開いたままだと node は終わらない。**
644:  // `b.close()` は利用者の Chrome に触りうるので、明示的に抜ける
```

## 「フォローしていない」「取り込み間違い」の判定
```
56:// **「そもそもフォローしていない」と分かった相手を覚える。**
143:      // 「`-follow` しか無い＝フォローしていない」を見て押さない門が在る。
391:  // 相手はこちらをフォローしていないので、過去に反応があっても外してよい。
503:  let notF = 0;   // **一覧に混ざっていた「そもそもフォローしていない」人の数**
555:        // **`-follow`（＝「フォロー」）しか無いなら、そもそもフォローしていない。**
567:          log("  @" + h + ": **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）");
556:        // 一覧の取り込み間違い。**押す対象ではないので、そう書く。**
567:          log("  @" + h + ": **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）");
567:          log("  @" + h + ": **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）");
557:        const notFollowing = !!(why && !why.suspended && !why.notfound && !why.locked &&
560:        if (notFollowing) {
```

## 判定の前後 60 行
```
    process.exit(0);
    return;
  }

  let state = {};
  try { state = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
  let done = 0;
  let notF = 0;   // **一覧に混ざっていた「そもそもフォローしていない」人の数**
  for (const c of cuts) {
    if (done >= quota) { log("外れた数が上限 " + quota + " 件に届いた。残りの候補は次回（x411）"); break; }
    const h = c.h;
    try {
      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      // x219: 空のページは開き直す（2026-10-03。下調べで続けて開いたあと、本文が空のページが返り 0 件になっていた）
      const x219Ready = () => page.waitForSelector('[data-testid="UserName"], [data-testid="emptyState"]', { timeout: 15000 }).then(() => true).catch(() => false);
      if (!(await x219Ready())) {
        log("  @" + h + ": ページが空。開き直す");
        await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {});
        await x219Ready();
      }
      await page.waitForTimeout(1500);
      const findBtn = () => page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        for (const b of bs) {
          const t = b.getAttribute("data-testid") || "";
          if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
        }
        for (const b of bs) {
          const x = (b.innerText || "").trim();
          if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid") || "", text: x };
        }
        return null;
      });
      // **固定待ちで 1 回 見るだけだと、描画前に「無い」と判定する。**
      // 2026-09-27 の本番初回で、8 件 中 4 件 が **約 4 秒** で「ボタンが無い」になった
      // （外れた 2 件 は 7〜10 秒 かかっている）。**出るまで待つ。**
      let btn = null;
      for (let w = 0; w < 12; w++) {
        btn = await findBtn();
        if (btn) break;
        await page.waitForTimeout(900);
      }
      if (!btn) {
        // **「無い」と決める前に、なぜ無いのかを出す。**
        // 凍結・削除・鍵・そもそも読み込めていない、を区別できないと直せない
        const why = await page.evaluate(() => {
          const t = (document.body && document.body.innerText || "").slice(0, 400);
          const seen = Array.from(document.querySelectorAll("button,[role=button]"))
            .map((b) => (b.getAttribute("data-testid") || "?") + ":" + (b.innerText || "").trim().slice(0, 10))
            .filter((x) => /follow/i.test(x)).slice(0, 4).join(" | ");
          return {
            path: location.pathname,
            suspended: /凍結|suspended/i.test(t),
            notfound: /存在しません|doesn.t exist|Account not found/i.test(t),
            locked: /鍵アカウント|protected|posts are protected/i.test(t),
            empty: t.length < 40,
            follow_btns: seen || "(無し)",
          };
        }).catch(() => null);
        // **`-follow`（＝「フォロー」）しか無いなら、そもそもフォローしていない。**
        // 一覧の取り込み間違い。**押す対象ではないので、そう書く。**
        const notFollowing = !!(why && !why.suspended && !why.notfound && !why.locked &&
                                !why.empty && /-follow:/.test(String(why.follow_btns || "")) &&
                                !/-unfollow:/.test(String(why.follow_btns || "")));
        if (notFollowing) {
          notF++;
          notFollowSet.add(String(h).toLowerCase());
          try {
            fs.writeFileSync(NOTFOLLOW, JSON.stringify([...notFollowSet].sort(), null, 2));
            JSON.parse(fs.readFileSync(NOTFOLLOW, "utf8"));   // **書いた JSON を読み直す**
          } catch (e) { log("  （覚えられない: " + String(e.message).slice(0, 60) + "）"); }
          log("  @" + h + ": **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）");
        } else {
          if (why && why.empty) { try { let j = {}; try { j = JSON.parse(fs.readFileSync(require("path").join(process.env.HOME, ".openclaw/workspace/data/follow-balance-empty.json"), "utf8")); } catch (e) {} const k = St
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
      // 外すのはアイコンのボタン（aria「〇〇さんのフォローを解除」）→ 出るメニューの「〇〇さんのフォローを解除」。マウス操作で押す（JS の click() では開�
      // x403: フォロー解除は全ジョブ共有の台帳で 120 秒あけ・30 分 6 回まで（最上位ルール 23）。空くまで待って記録する。空かなければこの回はここまで
```

## 一覧（following）を読むところ
```
243:    following = await scrapeList(page, "https://x.com/" + me + "/following", 800);
326:        following: toN(pick('a[href$="/following"]')),
144:      const all = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
154:        const cells = Array.from(document.querySelectorAll("[data-testid=UserCell]"));
```

## 覚えた未フォローの記録ファイル
```
280:.openclaw/workspace/data/follow-balance-empty.json
304:followed.json
415:follow-balance-followers-prev.json
465:.openclaw/workspace/data/badge-followback-state.json
52:follow-balance-state.json
53:reply-followers.json
54:followed.json
55:follow-balance-lists.json
569:.openclaw/workspace/data/follow-balance-empty.json
59:follow-balance-notfollowing.json
622:reply-followers.json
633:.json
633:.x227tmp.json
636:reply-followers.json
637:reply-followers.json
72:data/mutual-prune-whitelist.json
72:data/unfollow-whitelist.json
72:data/whitelist.json
83:followed.json
```

## ログ: 11/22〜23 の『外した』行と落ちた行
```
[2026-11-22T02:58:42.440Z] === follow-balance start (dry=false min=2 max=20 grace=3d inactive=30d big=5000) ===
[2026-11-22T03:50:47.897Z] === 外した: 4 件 / 候補 26 件（今日のフォロー 3 件） / **一覧に混ざっていた未フォロー 11 件** ===
[2026-11-22T06:36:37.297Z] === follow-balance start (dry=false min=2 max=20 grace=3d inactive=30d big=5000) ===
[2026-11-22T06:44:09.541Z] === 外した: 0 件 / 候補 16 件（今日のフォロー 3 件） / **一覧に混ざっていた未フォロー 14 件** ===
[2026-11-22T11:15:36.811Z] === follow-balance start (dry=false min=2 max=20 grace=3d inactive=30d big=5000) ===
[2026-11-23T02:58:58.442Z] === follow-balance start (dry=false min=2 max=20 grace=3d inactive=30d big=5000) ===
[2026-11-23T03:06:38.869Z] === 外した: 0 件 / 候補 17 件（今日のフォロー 2 件） / **一覧に混ざっていた未フォロー 15 件** ===
[2026-11-23T06:36:50.419Z] === follow-balance start (dry=false min=2 max=20 grace=3d inactive=30d big=5000) ===
[2026-11-23T06:44:05.967Z] === 外した: 0 件 / 候補 15 件（今日のフォロー 2 件） / **一覧に混ざっていた未フォロー 13 件** ===
[2026-11-23T11:19:55.462Z] === follow-balance start (dry=false min=2 max=20 grace=3d inactive=30d big=5000) ===
[2026-11-23T11:27:33.087Z] === 外した: 1 件 / 候補 17 件（今日のフォロー 4 件） / **一覧に混ざっていた未フォロー 14 件** ===
```

## ほかに shared_worker を開きうるタブ（いま開いているページの URL のホスト）
```
1 page https://search.rakuten.co.jp
6 page https://x.com
1 page chrome://profile-picker
1 service_worker https://claude.ai
1 service_worker https://www.amazon.co.jp
1 service_worker https://www.youtube.com
1 service_worker https://x.com
6 shared_worker blob:https://x.com
```

**読むだけ。LLM 不使用（$0）。**
