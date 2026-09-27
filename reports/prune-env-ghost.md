# 実装前の最後の確認（2026-09-27 15:11 JST・$0）

**このレポートが作られた時刻: 2026-09-27 15:11:45 JST**

> **読むだけ。** これを最後にして実装に入る。

## 1. `mutual-prune` はどう起動されているか

**`DRY_RUN=1` が立っていれば、何をしても 1 件も外れない。**

```
  Dict {
      WorkingDirectory = /Users/ny/.openclaw/workspace
      StandardOutPath = /Users/ny/.openclaw/workspace/logs/mutual-prune.out
      EnvironmentVariables = Dict {
          OPS_WS = /Users/ny/.openclaw/workspace
          ABS_MIN = 300
          INACTIVE_DAYS = 30
          HOME = /Users/ny
          MAX_UNFOLLOW = 8
          PATH = /usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
          CDP_URL = http://127.0.0.1:18810
          GRACE_DAYS = 14
          RATIO = 0.20
      }
      StartCalendarInterval = Array {
          Dict {
              Hour = 6
              Minute = 0
          }
          Dict {
              Hour = 18
              Minute = 0
          }
      }
      ProgramArguments = Array {
          /usr/local/bin/node
          /Users/ny/.openclaw/workspace/scripts/mutual-prune.js
      }
      StandardErrorPath = /Users/ny/.openclaw/workspace/logs/mutual-prune.err
      RunAtLoad = false
      Label = ai.openclaw.mutual-prune
  }
```

直近のログの先頭行（**start 行に dry と max が出る**）:

```
  [2026-09-22T20:03:18.484Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-23T20:03:06.815Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-24T20:03:08.492Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-25T20:02:20.206Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===
  [2026-09-26T20:02:21.832Z] === mutual-prune start (dry=false max=8 inactive=30d ratio=0.2 absMin=300 grace=14d) ===

  --- 直近の結果行 ---
  [2026-09-21T20:03:50.778Z] フォロー中: 202 件
  [2026-09-21T20:04:31.527Z] フォロワー: 283 件
  [2026-09-21T20:04:31.540Z] 相互フォロー: 145 件
  [2026-09-21T20:11:48.745Z] 見たプロフィール: 118 件 / **外す候補: 1 件**
  [2026-09-22T20:04:07.917Z] フォロー中: 193 件
  [2026-09-22T20:04:42.922Z] フォロワー: 295 件
  [2026-09-22T20:04:42.937Z] 相互フォロー: 128 件
  [2026-09-22T20:11:20.979Z] 見たプロフィール: 95 件 / **外す候補: 0 件**
  [2026-09-24T20:03:43.408Z] フォロー中: 228 件
  [2026-09-24T20:04:14.426Z] フォロワー: 306 件
  [2026-09-24T20:04:14.435Z] 相互フォロー: 169 件
  [2026-09-24T20:12:34.109Z] 見たプロフィール: 135 件 / **外す候補: 0 件**
  [2026-09-25T20:02:56.952Z] フォロー中: 249 件
  [2026-09-25T20:03:27.553Z] フォロワー: 308 件
  [2026-09-25T20:03:27.569Z] 相互フォロー: 173 件
  [2026-09-25T20:11:50.095Z] 見たプロフィール: 135 件 / **外す候補: 0 件**
  [2026-09-26T20:02:56.810Z] フォロー中: 259 件
  [2026-09-26T20:03:27.193Z] フォロワー: 308 件
  [2026-09-26T20:03:27.207Z] 相互フォロー: 174 件
  [2026-09-26T20:11:44.785Z] 見たプロフィール: 135 件 / **外す候補: 2 件**
```

## 2. `mutual-prune.js` の 1〜119 行（**写して使う部品**）

```javascript
       1	// 相互フォローでも「休眠」「格下」なら そっと外す。
       2	//
       3	// 2026-09-13 作成。LLM を呼ばない（DOM を読むだけ）ので API 課金は $0。
       4	//
       5	// **x17 で実際に動いたコードをそのまま使っている。** 書き直して壊さない。
       6	//   - playwright-core（`playwright` はこのワークスペースに存在しない）
       7	//   - connectOverCDP で既存の Chrome に繋ぐ（新しく起動しない）
       8	//   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
       9	//
      10	// 環境変数で調整する（既定値は安全側）:
      11	//   DRY_RUN=1          1 件も外さず、判定だけ出す
      12	//   MAX_UNFOLLOW=8     1 回に外す上限
      13	//   INACTIVE_DAYS=30   最終投稿がこれより前なら「休眠」
      14	//   RATIO=0.20         自分のフォロワー数に対する比率。これ未満なら「格下」候補
      15	//   ABS_MIN=300        かつ、この絶対値 未満のときだけ「格下」と判定する
      16	//   GRACE_DAYS=14      フォローしてからこの日数 未満は触らない
      17	const { chromium } = require("playwright-core");
      18	const fs = require("fs");
      19	const path = require("path");
      20	
      21	const WS = process.env.OPS_WS || path.join(process.env.HOME || "", ".openclaw", "workspace");
      22	const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
      23	const DRY = process.env.DRY_RUN === "1";
      24	const MAXN = Number(process.env.MAX_UNFOLLOW || 8);
      25	const INACTIVE_DAYS = Number(process.env.INACTIVE_DAYS || 30);
      26	const RATIO = Number(process.env.RATIO || 0.20);
      27	const ABS_MIN = Number(process.env.ABS_MIN || 300);
      28	const GRACE_DAYS = Number(process.env.GRACE_DAYS || 14);
      29	
      30	const LOG = path.join(WS, "logs", "mutual-prune.log");
      31	const STATE = path.join(WS, "data", "mutual-prune-state.json");
      32	const FOLLOW_STATE = path.join(WS, "data", "reply-followers.json");
      33	
      34	const FOLLOWING_RE = /^(フォロー中|Following)$/;
      35	const FOLLOW_RE = /^(フォロー|フォローする|Follow|Follow back|フォローバック)$/;
      36	
      37	function log(msg) {
      38	  const line = "[" + new Date().toISOString() + "] " + msg;
      39	  console.log(line);
      40	  try { fs.appendFileSync(LOG, line + "\n"); } catch (e) {}
      41	}
      42	
      43	function loadWhitelist() {
      44	  const out = new Set();
      45	  for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
      46	    try {
      47	      const d = JSON.parse(fs.readFileSync(path.join(WS, p), "utf8"));
      48	      const arr = Array.isArray(d) ? d : (d.handles || d.whitelist || Object.keys(d));
      49	      for (const h of arr) out.add(String(h).replace(/^@/, "").toLowerCase());
      50	    } catch (e) {}
      51	  }
      52	  return out;
      53	}
      54	
      55	// 「1,234」「12.3K」「1.2万」を数値にする。読めなければ null。
      56	// **読めないものを 0 とみなさない。** 0 にすると全員「格下」になる。
      57	function parseCount(s) {
      58	  if (!s) return null;
      59	  const t = String(s).replace(/[\s,]/g, "");
      60	  let m = t.match(/([0-9]+(?:\.[0-9]+)?)(万|億|K|M|k|m)?/);
      61	  if (!m) return null;
      62	  let n = parseFloat(m[1]);
      63	  if (!isFinite(n)) return null;
      64	  const u = m[2];
      65	  if (u === "万") n *= 10000;
      66	  else if (u === "億") n *= 100000000;
      67	  else if (u === "K" || u === "k") n *= 1000;
      68	  else if (u === "M" || u === "m") n *= 1000000;
      69	  return Math.round(n);
      70	}
      71	
      72	async function scrapeList(page, url, want) {
      73	  const seen = new Set();
      74	  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
      75	  await page.waitForTimeout(4000);
      76	  let stable = 0, last = 0;
      77	  while (seen.size < want && stable < 6) {
      78	    const got = await page.evaluate(() => {
      79	      const a = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
      80	      const out = [];
      81	      for (const el of a) {
      82	        const m = (el.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
      83	        if (m && !["home", "explore", "notifications", "messages", "i"].includes(m[1])) out.push(m[1]);
      84	      }
      85	      return out;
      86	    });
      87	    got.forEach((h) => seen.add(h));
      88	    if (seen.size === last) stable++; else stable = 0;
      89	    last = seen.size;
      90	    await page.mouse.wheel(0, 2600);
      91	    await page.waitForTimeout(1200);
      92	  }
      93	  return seen;
      94	}
      95	
      96	// プロフィールから「フォロワー数」「最終投稿日時」「認証済みか」を読む。
      97	// **読めなかった項目は null を返す。推測で埋めない。**
      98	async function readProfile(page, handle) {
      99	  await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 30000 });
     100	  await page.waitForTimeout(3500);
     101	  return await page.evaluate(() => {
     102	    const res = { followersText: null, lastPost: null, verified: false, protected: false };
     103	    const a = document.querySelector('a[href$="/verified_followers"]') ||
     104	              document.querySelector('a[href$="/followers"]');
     105	    if (a) res.followersText = (a.innerText || "").trim();
     106	    // 固定ツイートが混ざるので**最新の 1 件**を取る
     107	    const ts = Array.from(document.querySelectorAll("article time[datetime]"))
     108	      .map((t) => t.getAttribute("datetime")).filter(Boolean);
     109	    if (ts.length) {
     110	      const ms = ts.map((x) => new Date(x).getTime()).filter((n) => isFinite(n) && n > 0);
     111	      if (ms.length) res.lastPost = new Date(Math.max.apply(null, ms)).toISOString();
     112	    }
     113	    res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
     114	    res.protected = !!document.querySelector('[data-testid="UserName"] svg[aria-label*="鍵"]');
     115	    return res;
     116	  });
     117	}
     118	
     119	(async () => {
```

## 3. 片思いを外す口は在るか

**在れば載せ直すだけで済む。** 無ければ書く。

```
  --- unfollow を実際に押しているスクリプト ---
  audit-wrong-unfollows.js
  auto_detect_and_unfollow_inactive.js
  badge-followback.js
  batch_activity_update.js
  canary-silent-gap.js
  check-unfollowed-status.js
  check_accounts_activity.js
  daily-action-norm.js
  daily-follow-summary.js
  delete-tweet.js
  detect_inactive_accounts.js
  fetch-following.js
  follow-handle.js
  follow-via-playwright.js
  follower-growth-monitor.js
  follower-snapshot.js
  hashtag-follow.js
  incoming-reply-watcher.js
  monthly-kpi-report.js
  mutual-prune.js
  pipeline-heartbeat.js
  probe-followback-truth.js
  qt-probe-v2.js
  qt-probe.js
  refollow-may18-incident.js
  reply-followback-check.js
  reply-followers-cleanup.js
  revenge-unfollow.js
  scan_and_update_activity.js
  unfollow-cleanup.js
  unfollow-handle.js
  unfollow-stats-monitor.js
  unfollow-via-playwright.js
  unfollow_inactive_batch.js
  update_followed_after_cleanup.js

  --- 片思い / not following back を扱っていそうな箇所 ---
  badge-followback.js:96:    return await nx.notify(text, { kind: "badge-followback-report" });
  mutual-prune.js:174:  // **相互だけを対象にする。** 片思いは既存の別ジョブの担当。
  revenge-unfollow.js:3: * revenge-unfollow.js — 「相互→片思い」 detection → 報復 unfollow
  revenge-unfollow.js:8: *   - 存在しない = 向こうが unfollow した = 片思い化 → 即 unfollow + blacklist + reply-followers 更新
  revenge-unfollow.js:131:  const ghostSkipped = [];
  revenge-unfollow.js:154:      ghostSkipped.push(h);
  revenge-unfollow.js:155:      entry.followback_status = "revenge_ghost_already_unfollowed";
  revenge-unfollow.js:196:    if (ghostSkipped.length > 0) lines.push(`• ghost ${ghostSkipped.length}件 (既に未 follow、 マーク済)`);
  revenge-unfollow.js:206:    ghost_skipped: ghostSkipped.length,
  revenge-unfollow.js:208:    detail: { revenged, stillMutual, ghostSkipped, checkFail },
  unfollow-via-playwright.js:114:  const ghosts = [];     // already not followed (data drift)
  unfollow-via-playwright.js:134:        // 🆕 ghost check: does an -unfollow button exist (= we're following)?
  unfollow-via-playwright.js:144:        ghosts.push(c.handle);
  unfollow-via-playwright.js:147:        c.ghost_detected = true;
  unfollow-via-playwright.js:157:  // Persist followback=true / ghost status=unfollowed updates regardless of verified count
  unfollow-via-playwright.js:158:  if (cancelled.length > 0 || ghosts.length > 0) {
  unfollow-via-playwright.js:167:    if (ghosts.length > 0) parts.push(`👻ghost (既に未フォロー、 status更新): ${ghosts.length}件`);
  unfollow-via-playwright.js:169:    out({ ok: true, total_candidates: candidates.length, unfollowed: [], cancelled, ghosts, failed: [] });
  unfollow-via-playwright.js:173:  await slackPost(`<@${OWNER_USER_ID}> 🗑️ アンフォロー実行 (live check pass分): ${verified.map(c => "@"+c.handle).joi
  unfollow-via-playwright.js:204:  await slackPost(`<@${OWNER_USER_ID}> ✅ アンフォロー完了: ${unfollowed.length}件 / 残: ${total}件${failed.length > 0 
  unfollow-via-playwright.js:205:  out({ ok: true, total_candidates: candidates.length, unfollowed, ghosts, failed });
```

### `unfollow-handle.js`（108 行・更新 1789280759-16777234 09-13 15:25）

```javascript
  4:// Output: JSON {ok, status: unfollowed/not_following/unconfirmed/error, reason?}
  72:      console.log(JSON.stringify({ ok: false, status: "not_following", reason: "no unfollow button" }));
```

### `revenge-unfollow.js`（212 行・更新 1786265571-16777234 08-09 17:52）

```javascript
  11: *   - 1 fire = MAX 10 (DOS 防止 + ban 緩和)
  13: *   - DRY_RUN env で dry-run 可
  17: * Output: {ok, checked, revenge_unfollowed:[], still_mutual:[], check_fail:[]}
  31:const MAX_PER_RUN = parseInt(process.env.REVENGE_MAX_PER_RUN || "10", 10);
  32:const DRY_RUN = process.env.REVENGE_DRY_RUN === "true"; // default OFF (= real unfollow)
  55:  // past-mutual entries (yes or yes_late), exclude already-revenged
  56:  const candidates = [];
  64:    candidates.push({ handle, entry: v });
  67:  candidates.sort((a, b) => {
  72:  return candidates.slice(0, MAX_PER_RUN);
  116:  const candidates = pickCandidates();
  117:  if (candidates.length === 0) {
  118:    out({ ok: true, checked: 0, msg: "no past-mutual candidates" });
  133:  for (const { handle, entry } of candidates) {
  152:    // Not mutual anymore. Check if we still follow:
  159:    if (DRY_RUN) {
  182:  for (const { handle, entry } of candidates) {
  194:    if (revenged.length > 0) lines.push(`• 報復 ${revenged.length}件: ${revenged.map(r => "@"+r.handle).join(", ")}${DRY_RUN ? " [DRY_RUN]" : ""}`);
  203:    checked: candidates.length,
  205:    still_mutual: stillMutual.length,
```


---

## 実装の方針（**この後すぐ書く**）

決まっている基準（2026-09-27）。

| | |
| --- | --- |
| 外す順 | ① 返していない相手 → ② 休眠 → ③ 大きいアカウント |
| 守る | 反応をくれた人 ／ フォローから 7 日未満 |
| 目標 | **1 日のアンフォロー数 ≧ 1 日のフォロー数** |

フォロー側は **11:30 と 18:30 に撃ち、`COMPETITOR_FOLLOW_DAILY_CAP=30`**。
**追いつくには 1 日 30 件 以上 外せる必要がある。** いまの `MAX_UNFOLLOW=8` では足りない。

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
