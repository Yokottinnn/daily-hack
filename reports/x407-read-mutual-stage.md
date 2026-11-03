# follow-balance の相互の段を読む（2026-11-03 17:55 JST・読むだけ・$0）

## 反応の記録の読み込み（engaged）
```
  let notFollowSet = new Set();
  try {
    const raw = JSON.parse(fs.readFileSync(NOTFOLLOW, "utf8"));
    for (const h of (Array.isArray(raw) ? raw : Object.keys(raw || {}))) {
      notFollowSet.add(String(h).replace(/^@/, "").toLowerCase());
    }
  } catch (e) { notFollowSet = new Set(); }
  if (notFollowSet.size) log("覚えている未フォロー: " + notFollowSet.size + " 件（今回は見ない）");
  const engaged = harvest(ENGAGED);
  const followedMap = harvest(FOLLOWED);
  log("ホワイトリスト " + wl.size + " 件 / 反応の記録 " + engaged.size + " 件 / フォロー日時の記録 " + followedMap.size + " 件");

  // **その日にフォローした数。** 読めなければ下限を使う
  const now = Date.now();
  const jstDay = (ms) => new Date(ms + 9 * 3600 * 1000).toISOString().slice(0, 10);
  const today = jstDay(now);
  let followedToday = 0;
  for (const [, v] of followedMap) {
    if (!v.at) continue;
    const t = new Date(v.at).getTime();
    if (isFinite(t) && jstDay(t) === today) followedToday++;
  }
  // **フォロワーより フォローが少ない状態を保つ**（2026-09-28 に利用者が指示）。
  //   「フォロー数よりフォロワー数が多い方が圧倒的に魅力なアカウントに見える」
  //
  // **走査の数は使わない。** おすすめユーザーが混ざって 17〜21 件 多く出る
  // （9/28 実測: 走査 190 / ヘッダーの実数 173）。多いと思い込んで外しすぎる。
  // **X が表示しているヘッダーの数だけを使い、読めなければ比率を見ない**（fail-open）。
  let CEIL_RATIO = Number(process.env.FOLLOW_RATIO_CEIL || 0.65);
  let FLOOR_RATIO = Number(process.env.FOLLOW_RATIO_FLOOR || 0.45);
  // **目標。ここへ寄せる**（2026-09-28 に指示を受けた時点の比率）。
```

## プロフィールを読む部分（readProfile 相当・前後）
```
}

async function readProfile(page, handle) {
  // **タイムアウトは短く。** 1 件で 30 秒 待つと 40 件で 20 分 になる
  await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 12000 });
  await page.waitForTimeout(4700 + Math.floor(Math.random() * 1500));   // x219: 続けて開きすぎると X が空のページを返す（2.2 秒 → 4.7〜6.2 秒）
  return await page.evaluate(() => {
    const res = { followersText: null, lastPost: null, verified: false };
    const a = document.querySelector('a[href$="/verified_followers"]') ||
              document.querySelector('a[href$="/followers"]');
    if (a) res.followersText = (a.innerText || "").trim();
    const ts = Array.from(document.querySelectorAll("article time[datetime]"))
      .map((t) => t.getAttribute("datetime")).filter(Boolean);
    if (ts.length) {
      const ms = ts.map((x) => new Date(x).getTime()).filter((n) => isFinite(n) && n > 0);
      if (ms.length) res.lastPost = new Date(Math.max.apply(null, ms)).toISOString();
    }
    res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
    return res;
  });
}

(async () => {
  log("=== follow-balance start (dry=" + DRY + " min=" + MINN + " max=" + MAXN +
      " grace=" + GRACE_DAYS + "d inactive=" + INACTIVE_DAYS + "d big=" + BIG + ") ===");
```

## 相互の段（② ③）
```
  log("① 片思いから " + cuts.length + " 件");

  // ②③ 足りなければ相互を見る。**ここだけプロフィールを開く**
  let reads = 0;
  let timeUp = false;
  if (cuts.length < quota) {
    const dl2 = Date.now() + DECIDE_BUDGET_S * 1000;
    for (const h of mutual) {
      if (cuts.length >= quota || reads >= MAX_READS) break;
      if (Date.now() > dl2) { timeUp = true; break; }
      const why = protectedWhy(h, false);  // ← 相互の段。反応は守る
      if (why) { noteKeep(why); continue; }
      let p;
      try { p = await readProfile(page, h); reads++; }
      catch (e) { continue; }
      if (p.verified) continue;
      const fc = parseCount(p.followersText);
      const idle = p.lastPost ? Math.floor((now - new Date(p.lastPost).getTime()) / 86400000) : null;
      if (idle !== null && idle >= INACTIVE_DAYS) { cuts.push({ h, why: "休眠 " + idle + " 日", rank: 2 }); continue; }
      if (fc !== null && fc >= BIG) { cuts.push({ h, why: "大きいアカウント " + fc + " フォロワー", rank: 3 }); continue; }
    }
  }
  log("プロフィールを開いた: " + reads + " 件 / **外す候補 合計 " + cuts.length + " 件**" +
      (timeUp ? "（**" + DECIDE_BUDGET_S + " 秒 で打ち切った。相互を見切れていない**）" : ""));
  log("守った内訳: ホワイトリスト " + kept["ホワイトリスト"] + " / 反応をくれた人 " + kept["反応をくれた人"] + " / 猶予 " + kept["猶予"]);
  for (const c of cuts) log("  ✂ @" + c.h + " — " + c.why);

  if (DRY) {
    log("**DRY_RUN。1 件も外していない。**");
    await page.close();
    process.exit(0);
    return;
  }

  let state = {};
  try { state = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
  let done = 0;
  let notF = 0;   // **一覧に混ざっていた「そもそもフォローしていない」人の数**
  for (const c of cuts) {
    const h = c.h;
    try {
      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      // x219: 空のページは開き直す（2026-10-03。下調べで続けて開いたあと、本文が空のページが返り 0 件になっていた）
      const x219Ready = () => page.waitForSelector('[data-testid="UserName"], [data-testid="emptyState"]', { timeout: 15000 }).then(() => true).catch(() => false);
      if (!(await x219Ready())) {
        log("  @" + h + ": ページが空。開き直す");
```

## 外す順番（rank）
```
453:    cuts.push({ h, why: x227Why(h), rank: 1 });   // x227: 理由を「外された」「予定日を過ぎた」と分ける
473:      if (idle !== null && idle >= INACTIVE_DAYS) { cuts.push({ h, why: "休眠 " + idle + " 日", rank: 2 }); continue; }
474:      if (fc !== null && fc >= BIG) { cuts.push({ h, why: "大きいアカウント " + fc + " フォロワー", rank: 3 }); continue; }
597:        state[h] = { unfollowed_at: new Date().toISOString(), why: c.why, rank: c.rank };
```
