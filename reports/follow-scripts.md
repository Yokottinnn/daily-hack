# フォロー系スクリプトの全文（2026-10-12 19:52:58 JST・$0・何も変えていない）

## competitor-follower-follow.js

```javascript
// 177 行
   1  #!/usr/bin/env node
   2  /**
   3   * competitor-follower-follow.js — Tier B: 競合 follower scrape → follow
   4   * 2026-05-18 確立 (戦略再構築 Tier B、user 選定 7 competitors)
   5   *
   6   * Daily rotation: day-of-week mod len(competitors) で 1 competitor 選定、 follower list 先頭から scrape
   7   * filter: follow-handle.js 経由 (bio mutual-intent / follower-count range)
   8   * cap: COMPETITOR_FOLLOW_DAILY_CAP (default 10)
   9   * record: reply-followers.json source="competitor-follower:<competitor>"
  10   */
  11  const fs = require("fs");
  12  const https = require("https");
  13  const { execSync } = require("child_process");
  14  const { chromium } = require("playwright-core");
  15  
  16  const WS = "/Users/ny/.openclaw/workspace";
  17  const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
  18  const FOLLOWED_PATH = `${WS}/data/followed.json`;
  19  const REPLY_FOLLOWERS_PATH = `${WS}/data/reply-followers.json`;
  20  const LOG_PATH = `${WS}/logs/competitor-follower-follow.log`;
  21  const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
  22  const SLACK_TOKEN = JSON.parse(fs.readFileSync("/Users/ny/.openclaw/openclaw.json", "utf8")).channels.slack.botToken;
  23  const SLACK_CHANNEL = "C0A5FKU7T5M";
  24  const OWNER_USER_ID = "U0A5V22PVTQ";
  25  
  26  // User-selected 7 competitors (A + B + C 2026-05-18)
  27  // 2026-09-20 x102: **返り率の悪い 3 種 を外した。**
  28  //   ukk_hx 4.2% / money_yossy 8.6% / POIKATSU_OTAKE 10.0%
  29  //   群で見ると 外した 3 つ は mature 89 件 → 7 人（7.9%）、
  30  //   残した 4 つ は mature 133 件 → 28 人（21.1%）で **2.7 倍 の差**。
  31  //   9/08→9/20 に返ってきた 27 人 のうち、外した 3 種 は **2 人 だけ**だった。
  32  //   「全 follower 既 follow」で終わった回はログ上 **0 件** で、空振りの懸念は否定済み。
  33  //   **候補が揃ったら 7 種 に戻す。** 退避は .bak-* にある。
  34  const COMPETITORS = [
  35    "<伏せ>", "haiji_doctor",
  36    "<伏せ>", "tokufree3",
  37  ];
  38  
  39  const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);
  40  const FOLLOW_GAP_MS = 30 * 1000;
  41  const SCRAPE_TARGET_COUNT = 60;
  42  const TODAY = new Date().toISOString().slice(0, 10);
  43  
  44  function log(s) { try { fs.appendFileSync(LOG_PATH, `[${new Date().toISOString()}] ${s}\n`); } catch {} console.log(s); }
  45  
  46  function slackPost(text) {
  47    // 2026-07-25 migrated: silent_slack.json kind-based routing via slack-notify.js
  48    try {
  49      const nx = require("./lib/slack-notify.js");
  50      return nx.notify(text, { kind: "competitor-follower-progress" });
  51    } catch (e) {
  52      return Promise.resolve({ ok: false, error: "slack-notify-lib-missing" });
  53    }
  54  }
  55  
  56  function getFollowedHandles() {
  57    const set = new Set();
  58    if (fs.existsSync(FOLLOWED_PATH)) {
  59      try {
  60        const d = JSON.parse(fs.readFileSync(FOLLOWED_PATH, "utf8"));
  61        const list = d.followed || d.accounts || (Array.isArray(d) ? d : []);
  62        for (const a of list) {
  63          const h = (a.handle || "").replace(/^@/, "").toLowerCase();
  64          if (h) set.add(h);
  65        }
  66      } catch {}
  67    }
  68    if (fs.existsSync(REPLY_FOLLOWERS_PATH)) {
  69      try {
  70        const d = JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8"));
  71        for (const k of Object.keys(d)) set.add(k.toLowerCase());
  72      } catch {}
  73    }
  74    return set;
  75  }
  76  
  77  async function scrapeFollowers(competitor) {
  78    // 2026-08-09: 専用ウィンドウ。Jordanのウィンドウに触れない。
  79    const { openWorkTab } = require("./lib/work-window.js");
  80    const _w = await openWorkTab("competitor-follow");
  81    const browser = _w.browser;
  82    const page = _w.page;
  83    const handles = new Set();
  84    try {
  85      await page.goto(`https://x.com/${competitor}/followers`, { waitUntil: "domcontentloaded", timeout: 30000 });
  86      await page.waitForTimeout(3500);
  87      let stableCount = 0;
  88      let lastSize = 0;
  89      while (handles.size < SCRAPE_TARGET_COUNT && stableCount < 5) {
  90        const newOnes = await page.evaluate(() => {
  91          const links = Array.from(document.querySelectorAll('[data-testid="UserCell"] a[href^="/"]'));
  92          const seen = new Set();
  93          for (const a of links) {
  94            const m = a.getAttribute("href").match(/^\/([^/?#]+)$/);
  95            if (m && !/^(home|explore|notifications|messages|i|search)$/.test(m[1])) seen.add(m[1]);
  96          }
  97          return [...seen];
  98        });
  99        for (const h of newOnes) handles.add(h);
 100        if (handles.size === lastSize) stableCount++;
 101        else stableCount = 0;
 102        lastSize = handles.size;
 103        await page.evaluate(() => window.scrollBy(0, 800));
 104        await page.waitForTimeout(2000);
 105      }
 106    } catch (e) {
 107      log(`scrape err: ${e.message}`);
 108    } finally {
 109      await page.close(); await browser.close();
 110    }
 111    return [...handles];
 112  }
 113  
 114  (async () => {
 115    // 🆕 2026-06-07: 日曜(0)・月曜(1) はFB率0%のためスキップ
 116    const todayDate = new Date();
 117    const todayDow = todayDate.getDay();
 118    if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
 119      log(`=== competitor-follower SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
 120      process.exit(0);
 121    }
 122  
 123    const dayIndex = Math.floor(todayDate.getTime() / 86400000) % COMPETITORS.length;
 124    const competitor = COMPETITORS[dayIndex];
 125    log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITORS.length-1}) cap=${DAILY_CAP} ===`);
 126  
 127    const followed = getFollowedHandles();
 128    let scrapedHandles = [];
 129    try {
 130      scrapedHandles = await scrapeFollowers(competitor);
 131    } catch (e) {
 132      log(`scrape failure: ${e.message}`);
 133      await slackPost(`<@${OWNER_USER_ID}> 🌐 Tier B competitor-follower: scrape失敗 @${competitor} (${e.message})`);
 134      process.exit(2);
 135    }
 136    log(`scraped ${scrapedHandles.length} followers from @${competitor}`);
 137  
 138    const targets = scrapedHandles.filter(h => !followed.has(h.toLowerCase())).slice(0, DAILY_CAP);
 139    log(`new targets (after dedup): ${targets.length}`);
 140  
 141    if (targets.length === 0) {
 142      await slackPost(`<@${OWNER_USER_ID}> 🌐 Tier B (@${competitor}): 全 follower 既 follow か対象なし、skip`);
 143      return;
 144    }
 145  
 146    const results = [];
 147    for (const h of targets) {
 148      try {
 149        const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${h}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2*1024*1024 });
 150        const r = JSON.parse(out.trim().split("\n").pop());
 151        results.push({ handle: h, ok: r.ok, info: r });
 152        log(`  @${h}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
 153        if (r.ok) {
 154          try {
 155            const rf = fs.existsSync(REPLY_FOLLOWERS_PATH) ? JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8")) : {};
 156            rf[h] = {
 157              followed_at: new Date().toISOString(),
 158              followback_status: "pending",
 159              followers_at_follow: (r.profile && typeof r.profile.follower_count === "number") ? r.profile.follower_count : null,
 160              following_at_follow: (r.profile && typeof r.profile.following_count === "number") ? r.profile.following_count : null,
 161              phase_at_follow: (typeof r.phase === "number") ? r.phase : null,
 162              source: `competitor-follower:${competitor}`,
 163            };
 164            fs.writeFileSync(REPLY_FOLLOWERS_PATH, JSON.stringify(rf, null, 2));
 165          } catch (e) { log(`    rf-write err: ${e.message}`); }
 166        }
 167      } catch (e) {
 168        results.push({ handle: h, ok: false, error: e.message.slice(0, 200) });
 169        log(`  @${h}: ❌ exec err`);
 170      }
 171      await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
 172    }
 173  
 174    const ok = results.filter(r => r.ok).length;
 175    await slackPost(`<@${OWNER_USER_ID}> 🌐 Tier B competitor-follower 完了: @${competitor} の follower から ${ok}/${results.length} follow OK (scraped=${scrapedHandles.length})`);
 176    log(`=== end: ${ok}/${results.length} OK ===`);
 177  })();
```

## hashtag-follow.js

```javascript
// 177 行
   1  #!/usr/bin/env node
   2  /**
   3   * hashtag-follow.js — Tier A: ハッシュタグ active 投稿者を follow 候補化
   4   * 2026-05-18 確立 (戦略再構築 Tier A)
   5   *
   6   * Flow:
   7   *   1. trend-detect.js を実行 (or キャッシュから直近 candidates 取得)
   8   *   2. 各 candidate の author を抽出、dedupe
   9   *   3. 既 follow / 過去 unfollow / Tier C で followed の author を除外
  10   *   4. follow-handle.js 経由で follow (bio/follower-count filter 内蔵)
  11   *   5. reply-followers.json に source="hashtag-active" で記録 (live-check safety net 自動適用)
  12   *
  13   * Daily cap: env HASHTAG_FOLLOW_DAILY_CAP (default 10)
  14   * 間隔: 各 follow 30s 空ける (BAN avoidance)
  15   */
  16  const fs = require("fs");
  17  const https = require("https");
  18  const { execSync } = require("child_process");
  19  
  20  const WS = "/Users/ny/.openclaw/workspace";
  21  const TREND_DETECT = `${WS}/scripts/trend-detect.js`;
  22  const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
  23  const FOLLOWED_PATH = `${WS}/data/followed.json`;
  24  const REPLY_FOLLOWERS_PATH = `${WS}/data/reply-followers.json`;
  25  const LOG_PATH = `${WS}/logs/hashtag-follow.log`;
  26  const SLACK_TOKEN = JSON.parse(fs.readFileSync("/Users/ny/.openclaw/openclaw.json", "utf8")).channels.slack.botToken;
  27  const SLACK_CHANNEL = "C0A5FKU7T5M";
  28  const OWNER_USER_ID = "U0A5V22PVTQ";
  29  
  30  const DAILY_CAP = parseInt(process.env.HASHTAG_FOLLOW_DAILY_CAP || "10", 10);
  31  const FOLLOW_GAP_MS = 30 * 1000;
  32  const TODAY = new Date().toISOString().slice(0, 10);
  33  
  34  function log(s) { try { fs.appendFileSync(LOG_PATH, `[${new Date().toISOString()}] ${s}\n`); } catch {} console.log(s); }
  35  
  36  function slackPost(text) {
  37    // 2026-07-25 migrated: silent_slack.json kind-based routing via slack-notify.js
  38    try {
  39      const nx = require("./lib/slack-notify.js");
  40      return nx.notify(text, { kind: "hashtag-follow-progress" });
  41    } catch (e) {
  42      return Promise.resolve({ ok: false, error: "slack-notify-lib-missing" });
  43    }
  44  }
  45  
  46  function todayFollowCountFrom(p) {
  47    if (!fs.existsSync(p)) return 0;
  48    try {
  49      const d = JSON.parse(fs.readFileSync(p, "utf8"));
  50      let count = 0;
  51      if (d.followed && Array.isArray(d.followed)) {
  52        for (const a of d.followed) if (a.followed_at && a.followed_at.startsWith(TODAY)) count++;
  53      }
  54      if (typeof d === "object" && !d.followed) {  // reply-followers.json shape
  55        for (const [_, v] of Object.entries(d)) if (v.followed_at && v.followed_at.startsWith(TODAY)) count++;
  56      }
  57      return count;
  58    } catch { return 0; }
  59  }
  60  
  61  function getFollowedHandles() {
  62    const set = new Set();
  63    // followed.json
  64    if (fs.existsSync(FOLLOWED_PATH)) {
  65      try {
  66        const d = JSON.parse(fs.readFileSync(FOLLOWED_PATH, "utf8"));
  67        const list = d.followed || d.accounts || (Array.isArray(d) ? d : []);
  68        for (const a of list) {
  69          const h = (a.handle || "").replace(/^@/, "").toLowerCase();
  70          if (h) set.add(h);
  71        }
  72      } catch {}
  73    }
  74    // reply-followers.json
  75    if (fs.existsSync(REPLY_FOLLOWERS_PATH)) {
  76      try {
  77        const d = JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8"));
  78        for (const k of Object.keys(d)) set.add(k.toLowerCase());
  79      } catch {}
  80    }
  81    return set;
  82  }
  83  
  84  (async () => {
  85    // 🆕 2026-06-07: 日曜(0)・月曜(1) はFB率0%のためスキップ
  86    const todayDow = new Date().getDay(); // JST近似 (UTC+9 offset考慮)
  87    if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
  88      log(`=== hashtag-follow SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
  89      process.exit(0);
  90    }
  91  
  92    log(`=== hashtag-follow start (cap=${DAILY_CAP}) ===`);
  93  
  94    // 1. trend-detect 実行
  95    let detectOut;
  96    try {
  97      detectOut = execSync(`/usr/local/bin/node ${TREND_DETECT}`, { encoding: "utf8", maxBuffer: 32 * 1024 * 1024, timeout: 420000 });
  98    } catch (e) {
  99      log(`trend-detect failed: ${e.message} | stderr: ${(e.stderr||"").toString().slice(0,500)}`);
 100      process.exit(2);
 101    }
 102    let candidates = [];
 103    try {
 104      const o = JSON.parse(detectOut.trim().split("\n").pop());
 105      candidates = o.candidates || [];
 106    } catch (e) {
 107      log(`trend-detect output parse failed`); process.exit(3);
 108    }
 109    log(`trend candidates: ${candidates.length}`);
 110  
 111    // 2. authors unique + 除外
 112    const followed = getFollowedHandles();
 113    const seenAuthors = new Set();
 114    const targets = [];
 115    for (const c of candidates) {
 116      const a = (c.author || "").replace(/^@/, "");
 117      if (!a) continue;
 118      if (seenAuthors.has(a.toLowerCase())) continue;
 119      if (followed.has(a.toLowerCase())) continue;
 120      seenAuthors.add(a.toLowerCase());
 121      targets.push({ author: a, ...c });
 122    }
 123    log(`unique new authors: ${targets.length}`);
 124  
 125    // 3. cap check (今日既に follow した数を 2 source から合算)
 126    const alreadyTodayA = todayFollowCountFrom(FOLLOWED_PATH);
 127    const alreadyTodayB = todayFollowCountFrom(REPLY_FOLLOWERS_PATH);
 128    const usedToday = alreadyTodayA + alreadyTodayB;
 129    const remaining = Math.max(0, DAILY_CAP - usedToday);  // ※ Tier A 内の cap、他 source とは別計算がベターだがまず合算 conservative
 130    log(`today already follows: ${usedToday} (A:${alreadyTodayA}+B:${alreadyTodayB}) / DAILY_CAP=${DAILY_CAP} / remaining=${remaining}`);
 131  
 132    if (remaining <= 0) {
 133      log("cap reached, exit");
 134      await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow: cap到達でskip (today=${usedToday}/${DAILY_CAP})`);
 135      return;
 136    }
 137  
 138    const picks = targets.slice(0, remaining);
 139    log(`picks: ${picks.length} authors`);
 140  
 141    // 4. follow 実行
 142    const results = [];
 143    for (const p of picks) {
 144      try {
 145        const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2 * 1024 * 1024 });
 146        const r = JSON.parse(out.trim().split("\n").pop());
 147        results.push({ author: p.author, ok: r.ok, info: r });
 148        log(`  @${p.author}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
 149  
 150        // 5. record in reply-followers.json (live-check safety net for future unfollow)
 151        if (r.ok) {
 152          try {
 153            const rf = fs.existsSync(REPLY_FOLLOWERS_PATH) ? JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8")) : {};
 154            rf[p.author] = {
 155              followed_at: new Date().toISOString(),
 156              followback_status: "pending",
 157              followers_at_follow: (r.profile && typeof r.profile.follower_count === "number") ? r.profile.follower_count : null,
 158              following_at_follow: (r.profile && typeof r.profile.following_count === "number") ? r.profile.following_count : null,
 159              phase_at_follow: (typeof r.phase === "number") ? r.phase : null,
 160              source: "hashtag-follow",
 161              seed_post_url: p.tweet_url || null,
 162              seed_engagement: { likes: p.like_count, replies: p.reply_count, retweets: p.retweet_count },
 163            };
 164            fs.writeFileSync(REPLY_FOLLOWERS_PATH, JSON.stringify(rf, null, 2));
 165          } catch (e) { log(`    rf-write err: ${e.message}`); }
 166        }
 167      } catch (e) {
 168        results.push({ author: p.author, ok: false, error: e.message.slice(0, 200) });
 169        log(`  @${p.author}: ❌ exec err: ${e.message.slice(0, 150)}`);
 170      }
 171      await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
 172    }
 173  
 174    const ok = results.filter(r => r.ok).length;
 175    await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow 完了: ${ok}/${results.length} follow OK (今日合計 follow ≈${usedToday + ok}/${DAILY_CAP})`);
 176    log(`=== end: ${ok}/${results.length} OK ===`);
 177  })();
```

## follow-handle.js

```javascript
// 272 行
   1  #!/usr/bin/env node
   2  // follow-handle.js — Follow a single X handle via CDP.
   3  // 2026-05-20 大幅強化: profile scrape + 多段 filter (bio/influencer/活発度) を追加。
   4  //   過去 Tier A/B/C は filter なしで follow しており、 user 留意点 (influencer 除外) も未適用だった。
   5  //
   6  // Usage: node follow-handle.js <handle> [--no-filter]
   7  // Output: JSON {ok, status: followed/already_following/cannot_follow/filtered/click_failed/error, reason?, profile?}
   8  
   9  const { chromium } = require("playwright-core");
  10  const fs = require("fs");
  11  const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
  12  const BLACKLIST_PATH = "/Users/ny/.openclaw/workspace/data/refollow-blacklist.json";
  13  
  14  const NO_FILTER = process.argv.includes("--no-filter");
  15  const handle = process.argv.find((a, i) => i >= 2 && !a.startsWith("--"));
  16  
  17  // 2026-05-31 #96: refollow blacklist load (lazy、 ファイル無くてもエラーにしない)
  18  function loadBlacklist() {
  19    try { return new Set(Object.keys(JSON.parse(fs.readFileSync(BLACKLIST_PATH, "utf8")).handles || {})); }
  20    catch { return new Set(); }
  21  }
  22  const BLACKLIST = loadBlacklist();
  23  
  24  // --- 2026-09-25 x144: 公式・法人アカウントの名前フィルタ ---
  25  // FOLLOW_NAME_FILTER=log(既定) 記録するだけでフォローは止めない / on 弾く / off 何もしない
  26  // **日本語の「【公式】」「株式会社」は handle に入らない。表示名にしか出ない。**
  27  const NAME_FILTER_MODE = process.env.FOLLOW_NAME_FILTER || "log";
  28  const NAME_FILTER_LOG = "/Users/ny/.openclaw/workspace/data/name-filter-dryrun.jsonl";
  29  
  30  // 強い手がかり: 当たればほぼ公式・法人。on のとき弾くのはこれだけ
  31  const OFFICIAL_NAME_RE = /[【\[(（]\s*公式\s*[】\])）]|公式(アカウント|ツイッター|ストア|通販|サイト)|株式会社|有限会社|合同会社|[(（]\s*[株有]\s*[)）]|Co\.,?\s?Ltd|Inc\.|Corporation|編集部|広報(部|室|担当)|カスタマー(サポート|サービス)|お客様(サポート|センター)|採用(担当|情報)/i;
  32  // 弱い手がかり: 個人でも使う。**記録はするが on でも弾かない**
  33  const OFFICIAL_WEAK_RE = /_(jp|pr|co|inc|corp|press|staff)$/i;
  34  
  35  function officialStrong(name, bio, h) {
  36    let m = (name || "").match(OFFICIAL_NAME_RE); if (m) return "name:" + m[0];
  37    m = (bio || "").match(OFFICIAL_NAME_RE);      if (m) return "bio:" + m[0];
  38    m = (h || "").match(/(^|_)official/i);         if (m) return "handle:official";
  39    return null;
  40  }
  41  function officialWeak(h) {
  42    const m = (h || "").match(OFFICIAL_WEAK_RE);
  43    return m ? "handle:" + m[0] : null;
  44  }
  45  
  46  
  47  // 2026-05-31 #96: off-niche bio negative-list (節約・ポイ活と無関係なジャンル特化アカ)
  48  const OFF_NICHE_RE = /ダイエット|減量|筋トレ|筋肉|オタ活|推し活|声優|アニメ垢|ジャニ|男性アイドル|韓流|kpop|k-pop|ファッション垢|コスメ垢|スキンケア|ペット|犬好き|猫好き|柴犬|チワワ|懸賞 only|懸賞メイン|懸賞専用|RT専用|RTのみ/i;
  49  
  50  // 2026-05-31 #96: 数字 only / ランダム文字列 handle 検出 (フォロバ来ない属性が多い)
  51  function isRandomLookingHandle(h) {
  52    if (!h) return false;
  53    const clean = h.replace(/^@/, "");
  54    if (/^\d{6,}$/.test(clean)) return true;
  55    if (clean.length >= 10) {
  56      const digits = (clean.match(/\d/g) || []).length;
  57      if (digits / clean.length >= 0.6) return true;
  58    }
  59    if (clean.length >= 10 && /[A-Z]/.test(clean) && /[a-z]/.test(clean) && /\d/.test(clean)) {
  60      const vowels = (clean.match(/[aeiou]/gi) || []).length;
  61      if (vowels / clean.length < 0.15) return true;
  62    }
  63    return false;
  64  }
  65  
  66  // 2026-05-31 #96: bio 情報密度判定 (空 OR 「無言フォロー大歓迎」のみ等の低密度 bio)
  67  function isLowDensityBio(bio) {
  68    if (!bio) return true;
  69    // URLとhashtagを除いた残り文字数
  70    const stripped = bio.replace(/https?:\/\/\S+/g, "").replace(/[#＃]\S+/g, "").trim();
  71    if (stripped.length < 15) return true;
  72    // 「無言フォロー大歓迎」「相互フォロー」 等のテンプレ的キーワードしか含んでない
  73    const onlyTemplate = /^[\s　・\-/、。!！?？]*(無言フォロー(大?歓迎|失礼)?|相互フォロー?(歓迎|大歓迎)?|フォロバ(100|歓迎)?|FF外(から)?(失礼|歓迎)?)[\s　・\-/、。!！?？]*$/i.test(stripped);
  74    if (onlyTemplate) return true;
  75    return false;
  76  }
  77  
  78  if (!handle) {
  79    console.log(JSON.stringify({ ok: false, error: "missing handle arg" }));
  80    process.exit(1);
  81  }
  82  
  83  // --- Filter logic (ported from follow-via-playwright.js + 2026-05-20 強化) ---
  84  function decidePhase(followerCount) {
  85    if (followerCount < 100) return 1;
  86    if (followerCount < 300) return 2;
  87    return 3;
  88  }
  89  
  90  function passFilter(profile) {
  91    const { bio, follower_count, following_count, last_post_age_days } = profile;
  92    const phase = decidePhase(follower_count);
  93    const followingCount = following_count || 0;
  94  
  95    // Common: follower count range
  96    const minFollowers = phase === 1 ? 10 : 100;
  97    if (follower_count < minFollowers || follower_count > 50000) {
  98      return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
  99    }
 100  
 101    // 🚨 2026-05-25 改定 user 指示: 規模問わず ratio<0.3 で skip (フォロワー>>フォロー = 人気アカ、 フォロバ率低)
 102    // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
 103    if (follower_count >= 50) {
 104      const ratio = followingCount / follower_count;
 105      if (ratio < Number(process.env.FOLLOW_MIN_RATIO || "0")) {
 106        return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, phase };
 107      }
 108    }
 109  
 110    // 🚨 2026-05-31 #96: refollow blacklist チェック (手動 unfollow 履歴あれば skip)
 111    if (BLACKLIST.has(handle) || BLACKLIST.has("@" + handle)) {
 112      return { ok: false, reason: "refollow blacklist (manually unfollowed in past)", phase };
 113    }
 114  
 115    // 🚨 2026-05-31 #96: 数字 only / ランダム文字列 handle 検出 (フォロバ来ない属性)
 116    if (isRandomLookingHandle(handle)) {
 117      return { ok: false, reason: `random-looking handle (likely throwaway/spam): ${handle}`, phase };
 118    }
 119  
 120    // 🚨 2026-05-31 #96: off-niche bio negative-list (節約・ポイ活と無関係なジャンル特化アカ)
 121    if (OFF_NICHE_RE.test(bio || "")) {
 122      return { ok: false, reason: `off-niche bio (ダイエット/オタ活/ペット等)`, phase };
 123    }
 124  
 125    // 🚨 2026-05-31 #96: bio 情報密度判定 (空 or テンプレキーワードのみ → 質低)
 126    if (isLowDensityBio(bio)) {
 127      return { ok: false, reason: `low-density bio (空 or テンプレキーワードのみ)`, phase };
 128    }
 129  
 130    // Common: skip inactive (30+ days no post)
 131    if (last_post_age_days != null && last_post_age_days > 30) {
 132      return { ok: false, reason: `inactive (last post ${last_post_age_days}d ago)`, phase };
 133    }
 134  
 135    // Phase-specific bio checks
 136    if (phase === 1) {
 137      // 2026-05-18 broad mutual-intent keyword set
 138      const bioMatch = /フォロバ|フォローバック|フォロー返し|フォロー返却|フォロー返します|リフォロー|相互(フォロー)?|ふぉろば|フォロー(歓迎|welcome|お気軽|大歓迎)|フォロワー(募集|歓迎|大歓迎|お待ちしてます)|お気軽(に|フォロー)|気軽に(フォロー|どうぞ)|仲間|同志|つながり|繋がり|無言フォロー?(歓迎|失礼|OK|ok)?|FF外(から)?(失礼|OK)?|誰でも(歓迎|フォロー|どうぞ)|繋(が|げ)りた[いそ]|交流(歓迎|したい)|なかよく|仲良(し|く)/i.test(bio || "");
 139      const ratioMatch = followingCount > 0 && (
 140        (followingCount >= follower_count * 0.8 && followingCount <= follower_count * 1.5) ||
 141        (followingCount > follower_count && followingCount < 1000)
 142      );
 143      const spamMatch = /いいね回し|相互いいね|拡散希望|相互RT/i.test(bio || "");
 144      if (spamMatch) return { ok: false, reason: "Phase 1: spam pattern in bio", phase };
 145      if (!bioMatch && !ratioMatch) return { ok: false, reason: `Phase 1: no mutual-intent keyword & ratio mismatch (fw=${followingCount}/fr=${follower_count})`, phase };
 146    }
 147    if (phase === 2) {
 148      if (!/節約|ポイ活|お得|貯金|ふるさと|格安|nisa|投資|キャッシュレス|ポイント|還元|家計|貯蓄/i.test(bio || "")) {
 149        return { ok: false, reason: "Phase 2: no relevant topic in bio", phase };
 150      }
 151    }
 152    // 2026-09-25 x144: **ここまで来たもの＝「通るはずだったもの」だけを見る。**
 153    // log のときは記録するだけで返り値を変えない（供給を 1 件も減らさない）
 154    if (NAME_FILTER_MODE !== "off") {
 155      const strong = officialStrong(profile.display_name, bio, handle);
 156      const weak = strong ? null : officialWeak(handle);
 157      const hit = strong || weak;
 158      if (hit) {
 159        try {
 160          fs.appendFileSync(NAME_FILTER_LOG, JSON.stringify({
 161            ts: new Date().toISOString(),
 162            handle,
 163            hit,
 164            strength: strong ? "strong" : "weak",
 165            name: profile.display_name || "",
 166            follower_count, following_count: followingCount,
 167            mode: NAME_FILTER_MODE,
 168            acted: NAME_FILTER_MODE === "on" && !!strong,
 169          }) + "\n");
 170        } catch (e) { /* 記録に失敗してもフォローは止めない */ }
 171        if (NAME_FILTER_MODE === "on" && strong) {
 172          return { ok: false, reason: `official/corporate account (${strong})`, phase };
 173        }
 174      }
 175    }
 176  
 177    // Phase 3: just rely on common filters (already passed range + influencer + activity)
 178    return { ok: true, phase };
 179  }
 180  
 181  async function getProfileData(page, handle) {
 182    await page.goto(`https://x.com/${handle}`, { waitUntil: "domcontentloaded", timeout: 20000 });
 183    await page.waitForTimeout(2000);
 184    return await page.evaluate((u) => {
 185      const bio = document.querySelector('[data-testid="UserDescription"]')?.textContent || "";
 186      // 2026-09-25 x144: 表示名。**UserName は表示名と @<伏せ> が繋がって取れる**が、
 187      // 「【公式】」の判定にはそれで足りる
 188      const displayName = document.querySelector('[data-testid="UserName"]')?.textContent || "";
 189      let followerCount = 0;
 190      const flLink = document.querySelector(`a[href$="/${u}/verified_followers"], a[href$="/${u}/followers"]`);
 191      if (flLink) {
 192        const txt = (flLink.querySelector("span span")?.textContent || "0").replace(/,/g, "");
 193        if (/万/.test(txt)) followerCount = Math.round(parseFloat(txt.replace(/万/g, "")) * 10000);
 194        else if (/k/i.test(txt)) followerCount = Math.round(parseFloat(txt.replace(/k/i, "")) * 1000);
 195        else followerCount = parseInt(txt, 10) || 0;
 196      }
 197      let followingCount = 0;
 198      const fwLink = document.querySelector(`a[href$="/${u}/following"]`);
 199      if (fwLink) {
 200        const txt = (fwLink.querySelector("span span")?.textContent || "0").replace(/,/g, "");
 201        if (/万/.test(txt)) followingCount = Math.round(parseFloat(txt.replace(/万/g, "")) * 10000);
 202        else if (/k/i.test(txt)) followingCount = Math.round(parseFloat(txt.replace(/k/i, "")) * 1000);
 203        else followingCount = parseInt(txt, 10) || 0;
 204      }
 205      // Latest post timestamp
 206      let lastPostAge = null;
 207      const t = document.querySelector('article time');
 208      if (t) {
 209        const ts = new Date(t.getAttribute("datetime")).getTime();
 210        lastPostAge = Math.floor((Date.now() - ts) / (86400 * 1000));
 211      }
 212      // Follow button state
 213      const followBtn = document.querySelector('[data-testid$="-follow"]');
 214      const unfollowBtn = document.querySelector('[data-testid$="-unfollow"]');
 215      return {
 216        bio,
 217        display_name: displayName,
 218        follower_count: followerCount,
 219        following_count: followingCount,
 220        last_post_age_days: lastPostAge,
 221        canFollow: !!followBtn,
 222        alreadyFollowing: !!unfollowBtn,
 223      };
 224    }, handle);
 225  }
 226  
 227  async function main() {
 228    // 2026-08-09: 専用ウィンドウ。Jordanのウィンドウに触れない。
 229    const { openWorkTab } = require("./lib/work-window.js");
 230    const _w = await openWorkTab("follow");
 231    const browser = _w.browser;
 232    const page = _w.page;
 233    try {
 234      const profile = await getProfileData(page, handle);
 235  
 236      if (profile.alreadyFollowing) {
 237        console.log(JSON.stringify({ ok: true, status: "already_following", profile }));
 238        return;
 239      }
 240      if (!profile.canFollow) {
 241        console.log(JSON.stringify({ ok: false, status: "cannot_follow", reason: "no follow button (private/blocked/deleted)", profile }));
 242        return;
 243      }
 244  
 245      // Apply filter unless --no-filter (for explicit refollow / manual override)
 246      if (!NO_FILTER) {
 247        const f = passFilter(profile);
 248        if (!f.ok) {
 249          console.log(JSON.stringify({ ok: false, status: "filtered", reason: f.reason, phase: f.phase, profile }));
 250          return;
 251        }
 252      }
 253  
 254      // Execute follow
 255      const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
 256      await btn.click();
 257      await page.waitForTimeout(1500);
 258      const verifyUnfollow = await page.$('[data-testid$="-unfollow"]');
 259      if (verifyUnfollow) {
 260        console.log(JSON.stringify({ ok: true, status: "followed", profile }));
 261      } else {
 262        console.log(JSON.stringify({ ok: false, status: "click_failed", reason: "follow button click didn't change to unfollow", profile }));
 263      }
 264    } catch (e) {
 265      console.log(JSON.stringify({ ok: false, status: "error", reason: e.message }));
 266    } finally {
 267      await page.close();
 268      await browser.close();
 269    }
 270  }
 271  
 272  main();
```

## mutual-prune.js

```javascript
// 321 行
   1  // 相互フォローでも「休眠」「格下」なら そっと外す。
   2  //
   3  // 2026-09-13 作成。LLM を呼ばない（DOM を読むだけ）ので API 課金は $0。
   4  //
   5  // **x17 で実際に動いたコードをそのまま使っている。** 書き直して壊さない。
   6  //   - playwright-core（`playwright` はこのワークスペースに存在しない）
   7  //   - connectOverCDP で既存の Chrome に繋ぐ（新しく起動しない）
   8  //   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
   9  //
  10  // 環境変数で調整する（既定値は安全側）:
  11  //   DRY_RUN=1          1 件も外さず、判定だけ出す
  12  //   MAX_UNFOLLOW=8     1 回に外す上限
  13  //   INACTIVE_DAYS=30   最終投稿がこれより前なら「休眠」
  14  //   RATIO=0.20         自分のフォロワー数に対する比率。これ未満なら「格下」候補
  15  //   ABS_MIN=300        かつ、この絶対値 未満のときだけ「格下」と判定する
  16  //   GRACE_DAYS=14      フォローしてからこの日数 未満は触らない
  17  const { chromium } = require("playwright-core");
  18  const fs = require("fs");
  19  const path = require("path");
  20  
  21  const WS = process.env.OPS_WS || path.join(process.env.HOME || "", ".openclaw", "workspace");
  22  const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
  23  const DRY = process.env.DRY_RUN === "1";
  24  const MAXN = Number(process.env.MAX_UNFOLLOW || 8);
  25  const INACTIVE_DAYS = Number(process.env.INACTIVE_DAYS || 30);
  26  const RATIO = Number(process.env.RATIO || 0.20);
  27  const ABS_MIN = Number(process.env.ABS_MIN || 300);
  28  const GRACE_DAYS = Number(process.env.GRACE_DAYS || 14);
  29  
  30  const LOG = path.join(WS, "logs", "mutual-prune.log");
  31  const STATE = path.join(WS, "data", "mutual-prune-state.json");
  32  const FOLLOW_STATE = path.join(WS, "data", "reply-followers.json");
  33  
  34  const FOLLOWING_RE = /^(フォロー中|Following)$/;
  35  const FOLLOW_RE = /^(フォロー|フォローする|Follow|Follow back|フォローバック)$/;
  36  
  37  function log(msg) {
  38    const line = "[" + new Date().toISOString() + "] " + msg;
  39    console.log(line);
  40    try { fs.appendFileSync(LOG, line + "\n"); } catch (e) {}
  41  }
  42  
  43  function loadWhitelist() {
  44    const out = new Set();
  45    for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
  46      try {
  47        const d = JSON.parse(fs.readFileSync(path.join(WS, p), "utf8"));
  48        const arr = Array.isArray(d) ? d : (d.handles || d.whitelist || Object.keys(d));
  49        for (const h of arr) out.add(String(h).replace(/^@/, "").toLowerCase());
  50      } catch (e) {}
  51    }
  52    return out;
  53  }
  54  
  55  // 「1,234」「12.3K」「1.2万」を数値にする。読めなければ null。
  56  // **読めないものを 0 とみなさない。** 0 にすると全員「格下」になる。
  57  function parseCount(s) {
  58    if (!s) return null;
  59    const t = String(s).replace(/[\s,]/g, "");
  60    let m = t.match(/([0-9]+(?:\.[0-9]+)?)(万|億|K|M|k|m)?/);
  61    if (!m) return null;
  62    let n = parseFloat(m[1]);
  63    if (!isFinite(n)) return null;
  64    const u = m[2];
  65    if (u === "万") n *= 10000;
  66    else if (u === "億") n *= 100000000;
  67    else if (u === "K" || u === "k") n *= 1000;
  68    else if (u === "M" || u === "m") n *= 1000000;
  69    return Math.round(n);
  70  }
  71  
  72  async function scrapeList(page, url, want) {
  73    const seen = new Set();
  74    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
  75    await page.waitForTimeout(4000);
  76    let stable = 0, last = 0;
  77    while (seen.size < want && stable < 6) {
  78      const got = await page.evaluate(() => {
  79        const a = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
  80        const out = [];
  81        for (const el of a) {
  82          const m = (el.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
  83          if (m && !["home", "explore", "notifications", "messages", "i"].includes(m[1])) out.push(m[1]);
  84        }
  85        return out;
  86      });
  87      got.forEach((h) => seen.add(h));
  88      if (seen.size === last) stable++; else stable = 0;
  89      last = seen.size;
  90      await page.mouse.wheel(0, 2600);
  91      await page.waitForTimeout(1200);
  92    }
  93    return seen;
  94  }
  95  
  96  // プロフィールから「フォロワー数」「最終投稿日時」「認証済みか」を読む。
  97  // **読めなかった項目は null を返す。推測で埋めない。**
  98  async function readProfile(page, handle) {
  99    await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 30000 });
 100    // x224: 空のページは開き直す（2026-10-03。空のページで「ボタンが無い」「フォロワー数が読めない」になっていた）
 101    { const ok = () => page.waitForSelector('[data-testid="UserName"], [data-testid="emptyState"]', { timeout: 12000 }).then(() => true).catch(() => false);
 102      if (!(await ok())) { log("  @" + handle + ": ページが空。開き直す"); await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {}); await ok(); } }
 103    await page.waitForTimeout(3500 + Math.floor(Math.random() * 1500));   // x224: 続けて開きすぎない
 104    return await page.evaluate(() => {
 105      const res = { followersText: null, lastPost: null, verified: false, protected: false };
 106      const a = document.querySelector('a[href$="/verified_followers"]') ||
 107                document.querySelector('a[href$="/followers"]');
 108      if (a) res.followersText = (a.innerText || "").trim();
 109      // 固定ツイートが混ざるので**最新の 1 件**を取る
 110      const ts = Array.from(document.querySelectorAll("article time[datetime]"))
 111        .map((t) => t.getAttribute("datetime")).filter(Boolean);
 112      if (ts.length) {
 113        const ms = ts.map((x) => new Date(x).getTime()).filter((n) => isFinite(n) && n > 0);
 114        if (ms.length) res.lastPost = new Date(Math.max.apply(null, ms)).toISOString();
 115      }
 116      res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
 117      res.protected = !!document.querySelector('[data-testid="UserName"] svg[aria-label*="鍵"]');
 118      return res;
 119    });
 120  }
 121  
 122  (async () => {
 123    log("=== mutual-prune start (dry=" + DRY + " max=" + MAXN + " inactive=" + INACTIVE_DAYS +
 124        "d ratio=" + RATIO + " absMin=" + ABS_MIN + " grace=" + GRACE_DAYS + "d) ===");
 125  
 126    let b;
 127    try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
 128    catch (e) { log("CDP に繋がらない: " + String(e.message).slice(0, 120)); return; }
 129    const ctx = b.contexts()[0];
 130    if (!ctx) { log("context が無い。何もしない。"); return; }
 131    const page = await ctx.newPage();
 132  
 133    let me = null, myFollowers = null;
 134    try {
 135      await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 30000 });
 136      await page.waitForTimeout(3000);
 137      if (/login|i\/flow/.test(page.url())) { log("**ログインが切れている。何もしない。**"); await page.close(); return; }
 138      me = await page.evaluate(() => {
 139        const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
 140        const m = a && (a.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
 141        return m ? m[1] : null;
 142      });
 143    } catch (e) { log("/home を開けない: " + String(e.message).slice(0, 100)); await page.close(); return; }
 144    if (!me) { log("**自分のハンドルが読めない。何もしない。**"); await page.close(); return; }
 145  
 146    // 自分のフォロワー数。**読めなければ「格下」判定を丸ごと使わない。**
 147    try {
 148      const mine = await readProfile(page, me);
 149      myFollowers = parseCount(mine.followersText);
 150    } catch (e) {}
 151    log("自分: @" + me + " / フォロワー " + (myFollowers === null ? "読めない" : myFollowers));
 152  
 153    const following = await scrapeList(page, "https://x.com/" + me + "/following", 400);
 154    log("フォロー中: " + following.size + " 件");
 155    if (following.size === 0) { log("**0 件しか読めない。ページが壊れている。何もしない。**"); await page.close(); return; }
 156  
 157    const followers = await scrapeList(page, "https://x.com/" + me + "/followers", 600);
 158    log("フォロワー: " + followers.size + " 件");
 159  
 160    const wl = loadWhitelist();
 161    log("ホワイトリスト: " + wl.size + " 件");
 162  
 163    // フォローした日時。猶予の判定に使う
 164    const followedAt = {};
 165    for (const p of [FOLLOW_STATE, STATE]) {
 166      try {
 167        const d = JSON.parse(fs.readFileSync(p, "utf8"));
 168        for (const [h, e] of Object.entries(d)) {
 169          if (e && (e.followed_at || e.at)) followedAt[h.toLowerCase()] = e.followed_at || e.at;
 170        }
 171      } catch (e) {}
 172    }
 173  
 174    const lowerFollowers = new Set([...followers].map((h) => h.toLowerCase()));
 175    const now = Date.now();
 176  
 177    // **相互だけを対象にする。** 片思いは既存の別ジョブの担当。
 178    const mutual = [...following].filter((h) => lowerFollowers.has(h.toLowerCase()));
 179    log("相互フォロー: " + mutual.length + " 件");
 180  
 181    let state = {};
 182    try { state = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
 183  
 184    const decided = [];
 185    let looked = 0;
 186    for (const h of mutual) {
 187      if (decided.filter((d) => d.cut).length >= MAXN) break;
 188      const k = h.toLowerCase();
 189      if (wl.has(k)) { decided.push({ h, cut: false, why: "ホワイトリスト" }); continue; }
 190      const fa = followedAt[k];
 191      if (fa) {
 192        const days = (now - new Date(fa).getTime()) / 86400000;
 193        if (isFinite(days) && days < GRACE_DAYS) {
 194          decided.push({ h, cut: false, why: "フォローしてまだ " + Math.floor(days) + " 日（猶予 " + GRACE_DAYS + " 日）" });
 195          continue;
 196        }
 197      }
 198  
 199      let p;
 200      try { p = await readProfile(page, h); looked++; }
 201      catch (e) { decided.push({ h, cut: false, why: "プロフィールが開けない: " + String(e.message).slice(0, 50) }); continue; }
 202  
 203      if (p.verified) { decided.push({ h, cut: false, why: "認証済み" }); continue; }
 204  
 205      const fc = parseCount(p.followersText);
 206      if (fc === null) { decided.push({ h, cut: false, why: "フォロワー数が読めない（読めない＝悪いではない）" }); continue; }
 207      if (!p.lastPost) { decided.push({ h, cut: false, why: "最終投稿が読めない（読めない＝悪いではない）" }); continue; }
 208  
 209      const idle = Math.floor((now - new Date(p.lastPost).getTime()) / 86400000);
 210      const reasons = [];
 211      if (idle >= INACTIVE_DAYS) reasons.push("休眠 " + idle + " 日");
 212      if (myFollowers !== null && fc < myFollowers * RATIO && fc < ABS_MIN) {
 213        reasons.push("格下 " + fc + " < min(" + Math.round(myFollowers * RATIO) + ", " + ABS_MIN + ")");
 214      }
 215  
 216      if (!reasons.length) { decided.push({ h, cut: false, why: "残す（" + fc + " フォロワー / " + idle + " 日前に投稿）" }); continue; }
 217      decided.push({ h, cut: true, why: reasons.join(" ＋ "), followers: fc, idle: idle });
 218    }
 219  
 220    const cuts = decided.filter((d) => d.cut);
 221    log("見たプロフィール: " + looked + " 件 / **外す候補: " + cuts.length + " 件**");
 222    for (const d of decided) {
 223      log("  " + (d.cut ? "✂ " : "・ ") + "@" + d.h + " — " + d.why);
 224    }
 225  
 226    if (DRY) {
 227      log("**DRY_RUN。1 件も外していない。**");
 228      await page.close();
 229      return;
 230    }
 231  
 232    let done = 0;
 233    for (const d of cuts.slice(0, MAXN)) {
 234      const h = d.h;
 235      try {
 236        await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
 237        // x224: 空のページは開き直す（2026-10-03。空のページで「ボタンが無い」「フォロワー数が読めない」になっていた）
 238        { const ok = () => page.waitForSelector('[data-testid="UserName"], [data-testid="emptyState"]', { timeout: 15000 }).then(() => true).catch(() => false);
 239          if (!(await ok())) { log("  @" + h + ": ページが空。開き直す"); await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {}); await ok(); } }
 240        await page.waitForTimeout(1500);
 241        const btn = await page.evaluate(() => {
 242          const bs = Array.from(document.querySelectorAll("button,[role=button]"));
 243          for (const b of bs) {
 244            const t = b.getAttribute("data-testid") || "";
 245            if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
 246          }
 247          for (const b of bs) {
 248            const x = (b.innerText || "").trim();
 249            if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid") || "", text: x };
 250          }
 251          return null;
 252        });
 253        if (!btn) { log("  @" + h + ": フォロー中のボタンが無い（既に外れている可能性）"); continue; }
 254        if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
 255          log("  @" + h + ": 「フォロー中」ではないので押さない: " + (btn.text || btn.testid));
 256          continue;
 257        }
 258        await page.evaluate(() => {
 259          const bs = Array.from(document.querySelectorAll("button,[role=button]"));
 260          const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
 261                    bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
 262          if (t) t.click();
 263        });
 264        await page.waitForTimeout(1200);
 265        await page.evaluate(() => {
 266          const c = document.querySelector("[data-testid=confirmationSheetConfirm]");
 267          if (c) c.click();
 268        });
 269        await page.waitForTimeout(2500);
 270        const after = await page.evaluate(() => {
 271          const bs = Array.from(document.querySelectorAll("button,[role=button]"));
 272          const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
 273          return t ? ((t.innerText || "").trim() || t.getAttribute("data-testid")) : "-";
 274        });
 275        if (FOLLOW_RE.test(after)) {
 276          done++;
 277          state[h] = { unfollowed_at: new Date().toISOString(), why: d.why, followers: d.followers, idle_days: d.idle };
 278          log("  ✂ @" + h + " — 外れた（" + d.why + "）");
 279        } else {
 280          log("  @" + h + ": 押したが外れていない（" + after + "）");
 281        }
 282        await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));
 283      } catch (e) { log("  @" + h + ": 例外 " + String(e.message).slice(0, 90)); }
 284    }
 285  
 286    try { fs.writeFileSync(STATE, JSON.stringify(state, null, 2)); } catch (e) {}
 287  
 288    // 2026-09-15 x81: 外した相手を reply-followers.json にも反映する。
 289    // フォロー系ジョブはそちらを見て「既にフォロー済み」を判定するため、
 290    // 印を付けないと外したのに「フォロー中」と誤認される。
 291    try {
 292      if (fs.existsSync(FOLLOW_STATE)) {
 293        const rf = JSON.parse(fs.readFileSync(FOLLOW_STATE, "utf8"));
 294        const lower = {};
 295        for (const k of Object.keys(rf)) lower[k.toLowerCase()] = k;
 296        let touched = 0;
 297        for (const [h2, d2] of Object.entries(state)) {
 298          if (!d2 || !d2.unfollowed_at) continue;
 299          const key = lower[String(h2).toLowerCase()];
 300          if (!key) continue;
 301          const e2 = rf[key] || {};
 302          if (e2.unfollowed_at && e2.still_following === false) continue;
 303          e2.still_following = false;
 304          e2.unfollowed_at = e2.unfollowed_at || d2.unfollowed_at;
 305          e2.unfollow_source = "mutual-prune";
 306          e2.unfollow_reason = d2.why || null;
 307          rf[key] = e2;
 308          touched++;
 309        }
 310        if (touched) {
 311          const tmp2 = FOLLOW_STATE + ".tmp";
 312          fs.writeFileSync(tmp2, JSON.stringify(rf, null, 2));
 313          fs.renameSync(tmp2, FOLLOW_STATE);
 314        }
 315        log("reply-followers.json に反映: " + touched + " 件");
 316      }
 317    } catch (e) { log("reply-followers 反映に失敗: " + String(e.message).slice(0, 80)); }
 318    log("=== mutual-prune done: " + done + " 件 外した ===");
 319    await page.close();
 320    setTimeout(() => process.exit(0), 1000);   // x224: page.close() だけでは node が終わらず、次の定時を飛ばしていた
 321  })().catch((e) => { setTimeout(() => process.exit(1), 1000); log("落ちた: " + String(e && e.message).slice(0, 200)); });
```

## badge-followback.js

```javascript
// 222 行
   1  #!/usr/bin/env node
   2  // 2026-07-26 silence-enforce: intercept slackPost when kind is silent
   3  (function(){
   4    const __sn_fs = require("fs");
   5    const SILENCE_SCRIPT_KIND = "badge-followback-error";
   6    let __IS_SILENT = false;
   7    try {
   8      const cfgPath = process.env.HOME + "/.openclaw/workspace/config/silent_slack.json";
   9      const cfg = JSON.parse(__sn_fs.readFileSync(cfgPath, "utf8"));
  10      if (cfg.kill_switch_all || (cfg.silent_kinds && cfg.silent_kinds[SILENCE_SCRIPT_KIND])) {
  11        __IS_SILENT = true;
  12      }
  13    } catch (e) {}
  14    if (__IS_SILENT) {
  15      const __sn_https = require("https");
  16      const __sn_orig_request = __sn_https.request;
  17      __sn_https.request = function(opts, cb) {
  18        const host = (typeof opts === "string") ? new URL(opts).hostname : (opts.hostname || opts.host || "");
  19        if (host === "slack.com") {
  20          const fake = {
  21            on: () => fake,
  22            write: () => fake,
  23            setHeader: () => fake,
  24            removeHeader: () => fake,
  25            end: () => {
  26              if (cb) cb({
  27                statusCode: 200,
  28                on: (ev, fn) => {
  29                  if (ev === "data") fn(Buffer.from('{"ok":true,"skipped":"silent_kind:' + SILENCE_SCRIPT_KIND + '","ts":"silenced"}'));
  30                  if (ev === "end") fn();
  31                },
  32              });
  33            },
  34          };
  35          return fake;
  36        }
  37        return __sn_orig_request.apply(__sn_https, arguments);
  38      };
  39      if (typeof fetch !== "undefined") {
  40        const __sn_orig_fetch = fetch;
  41        global.fetch = async function(url, opts) {
  42          const u = typeof url === "string" ? url : (url && url.url);
  43          if (u && String(u).includes("slack.com")) {
  44            const body = '{"ok":true,"skipped":"silent_kind:' + SILENCE_SCRIPT_KIND + '"}';
  45            return { ok: true, status: 200, json: async () => JSON.parse(body), text: async () => body };
  46          }
  47          return __sn_orig_fetch(url, opts);
  48        };
  49      }
  50      console.error("[silence-enforce] this script kind=" + SILENCE_SCRIPT_KIND + " is silent, slack HTTP calls suppressed");
  51    }
  52  })();
  53  
  54  /**
  55   * badge-followback.js — 認証バッジ(青Premium/金企業/灰公式)保有の新規フォロワーを
  56   *   検出して自動フォローバックする運用スクリプト。
  57   *
  58   * 仕様(2026-06 ユーザー決定): 認証バッジ全般を対象 / 完全無条件・上限なし
  59   *   (BAN回避の人間的ディレイ5-15秒のみ) / 1日1回 follower-snapshot(00:35)の後に発火。
  60   *
  61   * Flow:
  62   *   1. /heng_ji31590/followers をスクロールして全フォロワー + 各人の verified バッジ有無を抽出
  63   *   2. state(処理済み)に無い「バッジ保有フォロワー」を候補に
  64   *   3. 各候補のプロフィールへ行き、未フォローならフォローバック
  65   *   4. state / followed.json を更新、Slackに報告
  66   *
  67   * Env:
  68   *   DRY_RUN=1       … フォローせず検出のみ(件数とサンプルを出力)
  69   *   BASELINE_ONLY=1 … 既存バッジフォロワーをフォローせず「処理済み」として記録(baseline化)。
  70   *                     以降は「設定後に新たにフォローしてきたバッジユーザー」だけをFB。
  71   */
  72  const fs = require("fs");
  73  const https = require("https");
  74  const { chromium } = require("playwright-core");
  75  
  76  const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
  77  const WS = "/Users/ny/.openclaw/workspace";
  78  const STATE_PATH = `${WS}/data/badge-followback-state.json`;
  79  const FOLLOWED_PATH = `${WS}/data/followed.json`;
  80  const LOG_PATH = `${WS}/logs/badge-followback.log`;
  81  const X_USERNAME = "heng_ji31590";
  82  const SLACK_CHANNEL = "C0A5FKU7T5M";
  83  const OWNER_USER_ID = "U0A5V22PVTQ";
  84  const MAX_SCROLL_LOOPS = 80;
  85  const DRY_RUN = process.env.DRY_RUN === "1";
  86  const BASELINE_ONLY = process.env.BASELINE_ONLY === "1";
  87  
  88  function log(s) { try { fs.appendFileSync(LOG_PATH, `[${new Date().toISOString()}] ${s}\n`); } catch {} ; console.log(s); }
  89  function out(o) { console.log(JSON.stringify(o)); }
  90  function rand(a, b) { return Math.floor(a + Math.random() * (b - a)); }
  91  
  92  async function slackPost(text) {
  93    // 2026-07-25 migrated: silent_slack.json kind-based routing via slack-notify.js
  94    try {
  95      const nx = require("./lib/slack-notify.js");
  96      return await nx.notify(text, { kind: "badge-followback-report" });
  97    } catch (e) {
  98      return { ok: false, error: "slack-notify-lib-missing" };
  99    }
 100  }
 101  
 102  function loadState() {
 103    if (!fs.existsSync(STATE_PATH)) return { processed: [], followed_back: [], initialized: false };
 104    try { const s = JSON.parse(fs.readFileSync(STATE_PATH, "utf8")); s.processed = s.processed || []; s.followed_back = s.followed_back || []; return s; }
 105    catch { return { processed: [], followed_back: [], initialized: false }; }
 106  }
 107  function saveState(s) { const tmp = STATE_PATH + ".tmp"; fs.writeFileSync(tmp, JSON.stringify(s, null, 2)); fs.renameSync(tmp, STATE_PATH); }
 108  function loadFollowed() { if (!fs.existsSync(FOLLOWED_PATH)) return { followed: [] }; try { return JSON.parse(fs.readFileSync(FOLLOWED_PATH, "utf8")); } catch { return { followed: [] }; } }
 109  function saveFollowed(d) { const tmp = FOLLOWED_PATH + ".tmp"; fs.writeFileSync(tmp, JSON.stringify(d, null, 2)); fs.renameSync(tmp, FOLLOWED_PATH); }
 110  
 111  async function scrollExtractVerified(page) {
 112    const map = new Map(); // handle -> verified(bool)
 113    let prevSize = 0, stable = 0;
 114    for (let i = 0; i < MAX_SCROLL_LOOPS; i++) {
 115      const batch = await page.evaluate(() => {
 116        const res = [];
 117        document.querySelectorAll('[data-testid="UserCell"]').forEach((c) => {
 118          const link = c.querySelector('a[href^="/"]');
 119          if (!link) return;
 120          const m = (link.getAttribute("href") || "").match(/^\/([A-Za-z0-9_]+)/);
 121          if (!m) return;
 122          const h = m[1];
 123          if (["i", "home", "search", "notifications", "messages", "explore"].includes(h)) return;
 124          const verified = !!c.querySelector('svg[data-testid="icon-verified"]');
 125          res.push([h, verified]);
 126        });
 127        return res;
 128      });
 129      for (const [h, v] of batch) { if (!map.has(h) || v) map.set(h, v); }
 130      if (map.size === prevSize) { stable++; if (stable >= 3) break; } else stable = 0;
 131      prevSize = map.size;
 132      await page.evaluate(() => window.scrollBy(0, 1400));
 133      await page.waitForTimeout(700);
 134    }
 135    return map;
 136  }
 137  
 138  async function getProfileFollowState(page, handle) {
 139    await page.goto(`https://x.com/${handle}`, { waitUntil: "domcontentloaded", timeout: 20000 });
 140    await page.waitForTimeout(1200);
 141    return await page.evaluate(() => {
 142      const followBtn = document.querySelector('[data-testid$="-follow"]');
 143      const unfollowBtn = document.querySelector('[data-testid$="-unfollow"]');
 144      return { can_follow: !!followBtn, already_following: !!unfollowBtn };
 145    });
 146  }
 147  async function clickFollow(page) {
 148    try {
 149      const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
 150      await btn.click();
 151      await page.waitForTimeout(1500);
 152      return !!(await page.$('[data-testid$="-unfollow"]'));
 153    } catch { return false; }
 154  }
 155  
 156  (async () => {
 157    let browser;
 158    const followedBackNow = [];
 159    try {
 160      browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
 161      const ctx = browser.contexts()[0];
 162      const page = await ctx.newPage();
 163      await page.goto(`https://x.com/${X_USERNAME}/followers`, { waitUntil: "domcontentloaded", timeout: 30000 });
 164      await page.waitForTimeout(2500);
 165      try { await page.waitForSelector('[data-testid="UserCell"]', { timeout: 10000 }); } catch {}
 166  
 167      const map = await scrollExtractVerified(page);
 168      const verifiedFollowers = [...map.entries()].filter(([, v]) => v).map(([h]) => h);
 169  
 170      const state = loadState();
 171      const processed = new Set(state.processed);
 172      const followedData = loadFollowed();
 173      const alreadyFollowing = new Set((followedData.followed || []).map((a) => a.handle));
 174      const candidates = verifiedFollowers.filter((h) => !processed.has(h));
 175  
 176      log(`scanned=${map.size} verified=${verifiedFollowers.length} new_candidates=${candidates.length} DRY_RUN=${DRY_RUN} BASELINE_ONLY=${BASELINE_ONLY}`);
 177  
 178      if (DRY_RUN) {
 179        out({ ok: true, dry_run: true, scanned: map.size, verified: verifiedFollowers.length, new_candidates: candidates.length, sample: candidates.slice(0, 40) });
 180        await browser.close().catch(() => {}); return;
 181      }
 182  
 183      if (BASELINE_ONLY) {
 184        for (const h of verifiedFollowers) processed.add(h);
 185        state.processed = [...processed]; state.initialized = true; saveState(state);
 186        await slackPost(`<@${OWNER_USER_ID}> ✅ バッジ自動フォローバック: baseline化完了。既存の認証バッジフォロワー ${verifiedFollowers.length} 件を「処理済み」として記録(フォローはせず)。今後フォローしてくる新規バッジユーザーを自動FBします。`);
 187        out({ ok: true, baseline: true, baselined: verifiedFollowers.length });
 188        await browser.close().catch(() => {}); return;
 189      }
 190  
 191      for (const h of candidates) {
 192        try {
 193          const st = await getProfileFollowState(page, h);
 194          processed.add(h);
 195          if (st.already_following || !st.can_follow) continue;
 196          if (await clickFollow(page)) {
 197            followedBackNow.push(h);
 198            if (!alreadyFollowing.has(h)) {
 199              followedData.followed = followedData.followed || [];
 200              followedData.followed.push({ handle: h, followed_at: new Date().toISOString(), source: "badge-followback", verified: true });
 201              alreadyFollowing.add(h);
 202            }
 203            state.followed_back.push({ handle: h, at: new Date().toISOString() });
 204            log(`followed back @${h}`);
 205          }
 206          await page.waitForTimeout(rand(5000, 15000));
 207        } catch (e) { log(`error @${h}: ${e.message}`); processed.add(h); }
 208      }
 209  
 210      state.processed = [...processed]; state.initialized = true;
 211      saveFollowed(followedData); saveState(state);
 212  
 213      if (followedBackNow.length) {
 214        const list = followedBackNow.slice(0, 30).map((h) => "@" + h).join(", ");
 215        await slackPost(`<@${OWNER_USER_ID}> 🔵 バッジ自動フォローバック ${followedBackNow.length}件: ${list}${followedBackNow.length > 30 ? "..." : ""}`);
 216      }
 217      out({ ok: true, scanned: map.size, verified: verifiedFollowers.length, followed_back: followedBackNow.length, handles: followedBackNow });
 218    } catch (e) {
 219      out({ ok: false, error: e.message });
 220      try { await slackPost(`<@${OWNER_USER_ID}> ⚠️ バッジ自動フォローバック エラー: ${e.message}`); } catch {}
 221    } finally { if (browser) await browser.close().catch(() => {}); }
 222  })();
```

## competitor の一覧（件数だけ）

34:const COMPETITORS = [
123:  const dayIndex = Math.floor(todayDate.getTime() / 86400000) % COMPETITORS.length;
124:  const competitor = COMPETITORS[dayIndex];
125:  log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITORS.length-1}) cap=${DAILY_CAP} ===`);

**何も変えていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
