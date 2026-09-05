# フィルタ本体 `follow-handle.js`（2026-09-05 16:47:19 JST・費用 $0）

> フィルタは 2 つのジョブの中に無く、**ここに集まっている。1 箇所 直せば両方に効く。**
> **全文を出す。** 抜粋にすると、また推測することになる。
> **書き換えない。フォローしない。ジョブも触らない。**

## 1. `follow-handle.js` 全文

- 220 行 / 更新 2026-08-09 17:52

```javascript
     1	#!/usr/bin/env node
     2	// follow-handle.js — Follow a single X handle via CDP.
     3	// 2026-05-20 大幅強化: profile scrape + 多段 filter (bio/influencer/活発度) を追加。
     4	//   過去 Tier A/B/C は filter なしで follow しており、 user 留意点 (influencer 除外) も未適用だった。
     5	//
     6	// Usage: node follow-handle.js <handle> [--no-filter]
     7	// Output: JSON {ok, status: followed/already_following/cannot_follow/filtered/click_failed/error, reason?, profile?}
     8	
     9	const { chromium } = require("playwright-core");
    10	const fs = require("fs");
    11	const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
    12	const BLACKLIST_PATH = "/Users/ny/.openclaw/workspace/data/refollow-blacklist.json";
    13	
    14	const NO_FILTER = process.argv.includes("--no-filter");
    15	const handle = process.argv.find((a, i) => i >= 2 && !a.startsWith("--"));
    16	
    17	// 2026-05-31 #96: refollow blacklist load (lazy、 ファイル無くてもエラーにしない)
    18	function loadBlacklist() {
    19	  try { return new Set(Object.keys(JSON.parse(fs.readFileSync(BLACKLIST_PATH, "utf8")).handles || {})); }
    20	  catch { return new Set(); }
    21	}
    22	const BLACKLIST = loadBlacklist();
    23	
    24	// 2026-05-31 #96: off-niche bio negative-list (節約・ポイ活と無関係なジャンル特化アカ)
    25	const OFF_NICHE_RE = /ダイエット|減量|筋トレ|筋肉|オタ活|推し活|声優|アニメ垢|ジャニ|男性アイドル|韓流|kpop|k-pop|ファッション垢|コスメ垢|スキン
    26	
    27	// 2026-05-31 #96: 数字 only / ランダム文字列 handle 検出 (フォロバ来ない属性が多い)
    28	function isRandomLookingHandle(h) {
    29	  if (!h) return false;
    30	  const clean = h.replace(/^@/, "");
    31	  if (/^\d{6,}$/.test(clean)) return true;
    32	  if (clean.length >= 10) {
    33	    const digits = (clean.match(/\d/g) || []).length;
    34	    if (digits / clean.length >= 0.4) return true;
    35	  }
    36	  if (clean.length >= 10 && /[A-Z]/.test(clean) && /[a-z]/.test(clean) && /\d/.test(clean)) {
    37	    const vowels = (clean.match(/[aeiou]/gi) || []).length;
    38	    if (vowels / clean.length < 0.15) return true;
    39	  }
    40	  return false;
    41	}
    42	
    43	// 2026-05-31 #96: bio 情報密度判定 (空 OR 「無言フォロー大歓迎」のみ等の低密度 bio)
    44	function isLowDensityBio(bio) {
    45	  if (!bio) return true;
    46	  // URLとhashtagを除いた残り文字数
    47	  const stripped = bio.replace(/https?:\/\/\S+/g, "").replace(/[#＃]\S+/g, "").trim();
    48	  if (stripped.length < 25) return true;
    49	  // 「無言フォロー大歓迎」「相互フォロー」 等のテンプレ的キーワードしか含んでない
    50	  const onlyTemplate = /^[\s　・\-/、。!！?？]*(無言フォロー(大?歓迎|失礼)?|相互フォロー?(歓迎|大歓迎)?|フォロバ(100|歓迎)?|FF外(から)?(失礼|歓迎)?)[\s�
    51	  if (onlyTemplate) return true;
    52	  return false;
    53	}
    54	
    55	if (!handle) {
    56	  console.log(JSON.stringify({ ok: false, error: "missing handle arg" }));
    57	  process.exit(1);
    58	}
    59	
    60	// --- Filter logic (ported from follow-via-playwright.js + 2026-05-20 強化) ---
    61	function decidePhase(followerCount) {
    62	  if (followerCount < 100) return 1;
    63	  if (followerCount < 300) return 2;
    64	  return 3;
    65	}
    66	
    67	function passFilter(profile) {
    68	  const { bio, follower_count, following_count, last_post_age_days } = profile;
    69	  const phase = decidePhase(follower_count);
    70	  const followingCount = following_count || 0;
    71	
    72	  // Common: follower count range
    73	  const minFollowers = phase === 1 ? 10 : 100;
    74	  if (follower_count < minFollowers || follower_count > 10000) {
    75	    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-10000)`, phase };
    76	  }
    77	
    78	  // 🚨 2026-05-25 改定 user 指示: 規模問わず ratio<0.3 で skip (フォロワー>>フォロー = 人気アカ、 フォロバ率低)
    79	  // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
    80	  if (follower_count >= 50) {
    81	    const ratio = followingCount / follower_count;
    82	    if (ratio < 0.3) {
    83	      return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, phase };
    84	    }
    85	  }
    86	
    87	  // 🚨 2026-05-31 #96: refollow blacklist チェック (手動 unfollow 履歴あれば skip)
    88	  if (BLACKLIST.has(handle) || BLACKLIST.has("@" + handle)) {
    89	    return { ok: false, reason: "refollow blacklist (manually unfollowed in past)", phase };
    90	  }
    91	
    92	  // 🚨 2026-05-31 #96: 数字 only / ランダム文字列 handle 検出 (フォロバ来ない属性)
    93	  if (isRandomLookingHandle(handle)) {
    94	    return { ok: false, reason: `random-looking handle (likely throwaway/spam): ${handle}`, phase };
    95	  }
    96	
    97	  // 🚨 2026-05-31 #96: off-niche bio negative-list (節約・ポイ活と無関係なジャンル特化アカ)
    98	  if (OFF_NICHE_RE.test(bio || "")) {
    99	    return { ok: false, reason: `off-niche bio (ダイエット/オタ活/ペット等)`, phase };
   100	  }
   101	
   102	  // 🚨 2026-05-31 #96: bio 情報密度判定 (空 or テンプレキーワードのみ → 質低)
   103	  if (isLowDensityBio(bio)) {
   104	    return { ok: false, reason: `low-density bio (空 or テンプレキーワードのみ)`, phase };
   105	  }
   106	
   107	  // Common: skip inactive (30+ days no post)
   108	  if (last_post_age_days != null && last_post_age_days > 30) {
   109	    return { ok: false, reason: `inactive (last post ${last_post_age_days}d ago)`, phase };
   110	  }
   111	
   112	  // Phase-specific bio checks
   113	  if (phase === 1) {
   114	    // 2026-05-18 broad mutual-intent keyword set
   115	    const bioMatch = /フォロバ|フォローバック|フォロー返し|フォロー返却|フォロー返します|リフォロー|相互(フォロー)?|ふぉろば|フォロー(歓迎|we
   116	    const ratioMatch = followingCount > 0 && (
   117	      (followingCount >= follower_count * 0.8 && followingCount <= follower_count * 1.5) ||
   118	      (followingCount > follower_count && followingCount < 1000)
   119	    );
   120	    const spamMatch = /いいね回し|相互いいね|拡散希望|相互RT/i.test(bio || "");
   121	    if (spamMatch) return { ok: false, reason: "Phase 1: spam pattern in bio", phase };
   122	    if (!bioMatch && !ratioMatch) return { ok: false, reason: `Phase 1: no mutual-intent keyword & ratio mismatch (fw=${followingCount}/fr=${follower_count})`, phase };
   123	  }
   124	  if (phase === 2) {
   125	    if (!/節約|ポイ活|お得|貯金|ふるさと|格安|nisa|投資|キャッシュレス|ポイント|還元|家計|貯蓄/i.test(bio || "")) {
   126	      return { ok: false, reason: "Phase 2: no relevant topic in bio", phase };
   127	    }
   128	  }
   129	  // Phase 3: just rely on common filters (already passed range + influencer + activity)
   130	  return { ok: true, phase };
   131	}
   132	
   133	async function getProfileData(page, handle) {
   134	  await page.goto(`https://x.com/${handle}`, { waitUntil: "domcontentloaded", timeout: 20000 });
   135	  await page.waitForTimeout(2000);
   136	  return await page.evaluate((u) => {
   137	    const bio = document.querySelector('[data-testid="UserDescription"]')?.textContent || "";
   138	    let followerCount = 0;
   139	    const flLink = document.querySelector(`a[href$="/${u}/verified_followers"], a[href$="/${u}/followers"]`);
   140	    if (flLink) {
   141	      const txt = (flLink.querySelector("span span")?.textContent || "0").replace(/,/g, "");
   142	      if (/万/.test(txt)) followerCount = Math.round(parseFloat(txt.replace(/万/g, "")) * 10000);
   143	      else if (/k/i.test(txt)) followerCount = Math.round(parseFloat(txt.replace(/k/i, "")) * 1000);
   144	      else followerCount = parseInt(txt, 10) || 0;
   145	    }
   146	    let followingCount = 0;
   147	    const fwLink = document.querySelector(`a[href$="/${u}/following"]`);
   148	    if (fwLink) {
   149	      const txt = (fwLink.querySelector("span span")?.textContent || "0").replace(/,/g, "");
   150	      if (/万/.test(txt)) followingCount = Math.round(parseFloat(txt.replace(/万/g, "")) * 10000);
   151	      else if (/k/i.test(txt)) followingCount = Math.round(parseFloat(txt.replace(/k/i, "")) * 1000);
   152	      else followingCount = parseInt(txt, 10) || 0;
   153	    }
   154	    // Latest post timestamp
   155	    let lastPostAge = null;
   156	    const t = document.querySelector('article time');
   157	    if (t) {
   158	      const ts = new Date(t.getAttribute("datetime")).getTime();
   159	      lastPostAge = Math.floor((Date.now() - ts) / (86400 * 1000));
   160	    }
   161	    // Follow button state
   162	    const followBtn = document.querySelector('[data-testid$="-follow"]');
   163	    const unfollowBtn = document.querySelector('[data-testid$="-unfollow"]');
   164	    return {
   165	      bio,
   166	      follower_count: followerCount,
   167	      following_count: followingCount,
   168	      last_post_age_days: lastPostAge,
   169	      canFollow: !!followBtn,
   170	      alreadyFollowing: !!unfollowBtn,
   171	    };
   172	  }, handle);
   173	}
   174	
   175	async function main() {
   176	  // 2026-08-09: 専用ウィンドウ。Jordanのウィンドウに触れない。
   177	  const { openWorkTab } = require("./lib/work-window.js");
   178	  const _w = await openWorkTab("follow");
   179	  const browser = _w.browser;
   180	  const page = _w.page;
   181	  try {
   182	    const profile = await getProfileData(page, handle);
   183	
   184	    if (profile.alreadyFollowing) {
   185	      console.log(JSON.stringify({ ok: true, status: "already_following", profile }));
   186	      return;
   187	    }
   188	    if (!profile.canFollow) {
   189	      console.log(JSON.stringify({ ok: false, status: "cannot_follow", reason: "no follow button (private/blocked/deleted)", profile }));
   190	      return;
   191	    }
   192	
   193	    // Apply filter unless --no-filter (for explicit refollow / manual override)
   194	    if (!NO_FILTER) {
   195	      const f = passFilter(profile);
   196	      if (!f.ok) {
   197	        console.log(JSON.stringify({ ok: false, status: "filtered", reason: f.reason, phase: f.phase, profile }));
   198	        return;
   199	      }
   200	    }
   201	
   202	    // Execute follow
   203	    const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
   204	    await btn.click();
   205	    await page.waitForTimeout(1500);
   206	    const verifyUnfollow = await page.$('[data-testid$="-unfollow"]');
   207	    if (verifyUnfollow) {
   208	      console.log(JSON.stringify({ ok: true, status: "followed", profile }));
   209	    } else {
   210	      console.log(JSON.stringify({ ok: false, status: "click_failed", reason: "follow button click didn't change to unfollow", profile }));
   211	    }
   212	  } catch (e) {
   213	    console.log(JSON.stringify({ ok: false, status: "error", reason: e.message }));
   214	  } finally {
   215	    await page.close();
   216	    await browser.close();
   217	  }
   218	}
   219	
   220	main();
```

## 2. 使っている環境変数（**plist だけで変えられる範囲**）

```
CHROME_CDP_URL
COMPETITOR_FOLLOW_DAILY_CAP
FORCE_RUN
HASHTAG_FOLLOW_DAILY_CAP
```

## 3. plist の環境変数の現在値

### `ai.openclaw.competitor-follower-follow`

```
Dict {
    COMPETITOR_FOLLOW_DAILY_CAP = 10
    PATH = /usr/local/bin:/usr/bin:/bin
}
```

### `ai.openclaw.hashtag-follow`

```
Dict {
    PATH = /usr/local/bin:/usr/bin:/bin
    HASHTAG_FOLLOW_DAILY_CAP = 90
}
```


---

**何も変えていない（$0）。** 次はここの数字と正規表現だけを、根拠を持って動かす。
