# アンフォローのボタンが無い原因（2026-10-03 21:21 JST・$0）

**このレポートが作られた時刻: 2026-10-03 21:21:17 JST**

> **押さない。外さない。フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**

## ① follow-balance.js のボタン探しとページの待ち

```
8://   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
72:  for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
129:  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
130:  await page.waitForTimeout(4000);
144:      const all = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
153:        const pc = document.querySelector('[data-testid="primaryColumn"]');
154:        const cells = Array.from(document.querySelectorAll("[data-testid=UserCell]"));
173:    await page.waitForTimeout(1200);
180:  await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 12000 });
181:  await page.waitForTimeout(2200);
193:    res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
211:    await page.goto("https://x.com/<伏せ>", { waitUntil: "domcontentloaded", timeout: 30000 });
212:    await page.waitForTimeout(3000);
215:      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
304:    await page.goto("https://x.com/" + me, { waitUntil: "domcontentloaded", timeout: 30000 });
305:    await page.waitForTimeout(4500);
451:      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
452:      await page.waitForTimeout(1500);
456:          const t = b.getAttribute("data-testid") || "";
457:          if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
461:          if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid") || "", text: x };
472:        await page.waitForTimeout(900);
480:            .map((b) => (b.getAttribute("data-testid") || "?") + ":" + (b.innerText || "").trim().slice(0, 10))
487:            empty: t.length < 40,
488:            follow_btns: seen || "(無し)",
494:                                !why.empty && /-follow:/.test(String(why.follow_btns || "")) &&
495:                                !/-unfollow:/.test(String(why.follow_btns || "")));
505:          log("  @" + h + ": フォロー中のボタンが無い" +
510:      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
516:        const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
520:      await page.waitForTimeout(1200);
522:        const c2 = document.querySelector("[data-testid=confirmationSheetConfirm]");
525:      await page.waitForTimeout(2500);
528:        const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
529:        return t ? ((t.innerText || "").trim() || t.getAttribute("data-testid")) : "-";
533:        state[h] = { unfollowed_at: new Date().toISOString(), why: c.why, rank: c.rank };
538:      await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));

  --- 445〜505 行目
  try { state = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
  let done = 0;
  let notF = 0;   // **一覧に混ざっていた「そもそもフォローしていない」人の数**
  for (const c of cuts) {
    const h = c.h;
    try {
      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
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
          log("  @" + h + ": フォロー中のボタンが無い" +
```

## ② 今日 失敗した相手のページ（1・4・8 秒待って読む）

```
  対象 3 件
  rc=0
```

### 1 件目（画面 `x218-1.png`）

```
1 秒: main=true primaryColumn=true UserName=false emptyState=false loginWall=false 本文長=149
     ボタン: []
4 秒: main=true primaryColumn=true UserName=true emptyState=false loginWall=false 本文長=1859
     ボタン: [{"testid":"395674396-unfollow","aria":"フォロー中 @x","text":"フォロー中"},{"testid":"3424882992-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"4811085860-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1298651495181611008-follow","aria":"フォロー @x","text":"フォロー"}]
8 秒: main=true primaryColumn=true UserName=true emptyState=false loginWall=false 本文長=1859
     ボタン: [{"testid":"395674396-unfollow","aria":"フォロー中 @x","text":"フォロー中"},{"testid":"3424882992-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"4811085860-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1298651495181611008-follow","aria":"フォロー @x","text":"フォロー"}]
```

### 2 件目

```
1 秒: main=true primaryColumn=true UserName=true emptyState=false loginWall=false 本文長=407
     ボタン: [{"testid":"1885926748380143616-unfollow","aria":"フォロー中 @x","text":"フォロー中"}]
4 秒: main=true primaryColumn=true UserName=true emptyState=false loginWall=false 本文長=1480
     ボタン: [{"testid":"1885926748380143616-unfollow","aria":"フォロー中 @x","text":"フォロー中"},{"testid":"122833354-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1870942819-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1472469956063535105-follow","aria":"フォロー @x","text":"フォロー"}]
8 秒: main=true primaryColumn=true UserName=true emptyState=false loginWall=false 本文長=1480
     ボタン: [{"testid":"1885926748380143616-unfollow","aria":"フォロー中 @x","text":"フォロー中"},{"testid":"122833354-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1870942819-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1472469956063535105-follow","aria":"フォロー @x","text":"フォロー"}]
```

### 3 件目

```
1 秒: main=true primaryColumn=true UserName=true emptyState=false loginWall=false 本文長=474
     ボタン: [{"testid":"937907969320091648-follow","aria":"フォロー @x","text":"フォロー"}]
4 秒: main=true primaryColumn=true UserName=true emptyState=false loginWall=false 本文長=1700
     ボタン: [{"testid":"937907969320091648-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1572147265728552965-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1530566337223098369-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1540685234793881602-follow","aria":"フォロー @x","text":"フォロー"}]
8 秒: main=true primaryColumn=true UserName=true emptyState=false loginWall=false 本文長=1700
     ボタン: [{"testid":"937907969320091648-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1572147265728552965-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1530566337223098369-follow","aria":"フォロー @x","text":"フォロー"},{"testid":"1540685234793881602-follow","aria":"フォロー @x","text":"フォロー"}]
```

**押していない。外していない。フォローしていない（$0／回・$0／日・$0／月）。**
