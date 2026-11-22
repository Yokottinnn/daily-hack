# follow-handle.js の全文（2026-11-15 21:31:47 JST・読むだけ・$0）

280 行・15037 bytes
```js
1: #!/usr/bin/env node
2: /* x352: X のアクションの間隔待ち（x-action-pacer）。空かなければ押さずに終わる */ { const _r=require("child_process").spawnSync(process.execPath,["/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs","until","follow","150"],{stdio:["ignore","ignore","inherit"]}); if(_r.status===3){console.log(JSON.stringify({ok:false,step:"paced",error:"X のアクションの間隔
3: // follow-handle.js — Follow a single X handle via CDP.
4: // 2026-05-20 大幅強化: profile scrape + 多段 filter (bio/influencer/活発度) を追加。
5: //   過去 Tier A/B/C は filter なしで follow しており、 user 留意点 (influencer 除外) も未適用だった。
6: //
7: // Usage: node follow-handle.js <handle> [--no-filter]
8: // Output: JSON {ok, status: followed/already_following/cannot_follow/filtered/click_failed/error, reason?, profile?}
9: 
10: const { chromium } = require("playwright-core");
11: const fs = require("fs");
12: const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
13: const BLACKLIST_PATH = "/Users/ny/.openclaw/workspace/data/refollow-blacklist.json";
14: 
15: const NO_FILTER = process.argv.includes("--no-filter");
16: const handle = process.argv.find((a, i) => i >= 2 && !a.startsWith("--"));
17: 
18: // 2026-05-31 #96: refollow blacklist load (lazy、 ファイル無くてもエラーにしない)
19: function loadBlacklist() {
20:   try { return new Set(Object.keys(JSON.parse(fs.readFileSync(BLACKLIST_PATH, "utf8")).handles || {})); }
21:   catch { return new Set(); }
22: }
23: const BLACKLIST = loadBlacklist();
24: 
25: // --- 2026-09-25 x144: 公式・法人アカウントの名前フィルタ ---
26: // FOLLOW_NAME_FILTER=log(既定) 記録するだけでフォローは止めない / on 弾く / off 何もしない
27: // **日本語の「【公式】」「株式会社」は handle に入らない。表示名にしか出ない。**
28: const NAME_FILTER_MODE = process.env.FOLLOW_NAME_FILTER || "log";
29: const NAME_FILTER_LOG = "/Users/ny/.openclaw/workspace/data/name-filter-dryrun.jsonl";
30: 
31: // 強い手がかり: 当たればほぼ公式・法人。on のとき弾くのはこれだけ
32: const OFFICIAL_NAME_RE = /[【\[(（]\s*公式\s*[】\])）]|公式(アカウント|ツイッター|ストア|通販|サイト)|株式会社|有限会社|合同会社|[(（]\s*[株有]\s*[)）]|Co\.,?\s?Ltd|Inc\.|Corporation|編集部|広報(部|室|担当)|カスタマー(サポート|サービス)|お客様(サポート|センター)|採用(担当|情報)/i;
33: // 弱い手がかり: 個人でも使う。**記録はするが on でも弾かない**
34: const OFFICIAL_WEAK_RE = /_(jp|pr|co|inc|corp|press|staff)$/i;
35: 
36: function officialStrong(name, bio, h) {
37:   let m = (name || "").match(OFFICIAL_NAME_RE); if (m) return "name:" + m[0];
38:   m = (bio || "").match(OFFICIAL_NAME_RE);      if (m) return "bio:" + m[0];
39:   m = (h || "").match(/(^|_)official/i);         if (m) return "handle:official";
40:   return null;
41: }
42: function officialWeak(h) {
43:   const m = (h || "").match(OFFICIAL_WEAK_RE);
44:   return m ? "handle:" + m[0] : null;
45: }
46: 
47: 
48: // 2026-05-31 #96: off-niche bio negative-list (節約・ポイ活と無関係なジャンル特化アカ)
49: const OFF_NICHE_RE = /ダイエット|減量|筋トレ|筋肉|オタ活|推し活|声優|アニメ垢|ジャニ|男性アイドル|韓流|kpop|k-pop|ファッション垢|コスメ垢|スキンケア|ペット|犬好き|猫好き|柴犬|チワワ|懸賞 only|懸賞メイン|懸賞専用|RT専用|RTのみ/i;
50: 
51: // 2026-05-31 #96: 数字 only / ランダム文字列 handle 検出 (フォロバ来ない属性が多い)
52: function isRandomLookingHandle(h) {
53:   if (!h) return false;
54:   const clean = h.replace(/^@/, "");
55:   if (/^\d{6,}$/.test(clean)) return true;
56:   if (clean.length >= 10) {
57:     const digits = (clean.match(/\d/g) || []).length;
58:     if (digits / clean.length >= 0.6) return true;
59:   }
60:   if (clean.length >= 10 && /[A-Z]/.test(clean) && /[a-z]/.test(clean) && /\d/.test(clean)) {
61:     const vowels = (clean.match(/[aeiou]/gi) || []).length;
62:     if (vowels / clean.length < 0.15) return true;
63:   }
64:   return false;
65: }
66: 
67: // 2026-05-31 #96: bio 情報密度判定 (空 OR 「無言フォロー大歓迎」のみ等の低密度 bio)
68: function isLowDensityBio(bio) {
69:   if (!bio) return true;
70:   // URLとhashtagを除いた残り文字数
71:   const stripped = bio.replace(/https?:\/\/\S+/g, "").replace(/[#＃]\S+/g, "").trim();
72:   if (stripped.length < 15) return true;
73:   // 「無言フォロー大歓迎」「相互フォロー」 等のテンプレ的キーワードしか含んでない
74:   const onlyTemplate = /^[\s　・\-/、。!！?？]*(無言フォロー(大?歓迎|失礼)?|相互フォロー?(歓迎|大歓迎)?|フォロバ(100|歓迎)?|FF外(から)?(失礼|歓迎)?)[\s　・\-/、。!！?？]*$/i.test(stripped);
75:   if (onlyTemplate) return true;
76:   return false;
77: }
78: 
79: if (!handle) {
80:   console.log(JSON.stringify({ ok: false, error: "missing handle arg" }));
81:   process.exit(1);
82: }
83: 
84: // --- Filter logic (ported from follow-via-playwright.js + 2026-05-20 強化) ---
85: function decidePhase(followerCount) {
86:   if (followerCount < 100) return 1;
87:   if (followerCount < 300) return 2;
88:   return 3;
89: }
90: 
91: function passFilter(profile) {
92:   const { bio, follower_count, following_count, last_post_age_days } = profile;
93:   const phase = decidePhase(follower_count);
94:   const followingCount = following_count || 0;
95: 
96:   // 2026-10-12 x278: 呼び出し側が求めたときだけ、未認証を弾く（青バッジのアカウントに寄せる）
97:   if (process.env.FOLLOW_REQUIRE_VERIFIED === "1" && profile.verified === false) {
98:     return { ok: false, reason: "not verified (FOLLOW_REQUIRE_VERIFIED)", phase };
99:   }
100:   // Common: follower count range
101:   const minFollowers = phase === 1 ? 10 : 100;
102:   if (follower_count < minFollowers || follower_count > 50000) {
103:     return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
104:   }
105: 
106:   // 🚨 2026-05-25 改定 user 指示: 規模問わず ratio<0.3 で skip (フォロワー>>フォロー = 人気アカ、 フォロバ率低)
107:   // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
108:   if (follower_count >= 50) {
109:     const ratio = followingCount / follower_count;
110:     if (ratio < Number(process.env.FOLLOW_MIN_RATIO || "0")) {
111:       return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, phase };
112:     }
113:   }
114: 
115:   // 🚨 2026-05-31 #96: refollow blacklist チェック (手動 unfollow 履歴あれば skip)
116:   if (BLACKLIST.has(handle) || BLACKLIST.has("@" + handle)) {
117:     return { ok: false, reason: "refollow blacklist (manually unfollowed in past)", phase };
118:   }
119: 
120:   // 🚨 2026-05-31 #96: 数字 only / ランダム文字列 handle 検出 (フォロバ来ない属性)
121:   if (isRandomLookingHandle(handle)) {
122:     return { ok: false, reason: `random-looking handle (likely throwaway/spam): ${handle}`, phase };
123:   }
124: 
125:   // 🚨 2026-05-31 #96: off-niche bio negative-list (節約・ポイ活と無関係なジャンル特化アカ)
126:   if (OFF_NICHE_RE.test(bio || "")) {
127:     return { ok: false, reason: `off-niche bio (ダイエット/オタ活/ペット等)`, phase };
128:   }
129: 
130:   // 🚨 2026-05-31 #96: bio 情報密度判定 (空 or テンプレキーワードのみ → 質低)
131:   if (isLowDensityBio(bio)) {
132:     return { ok: false, reason: `low-density bio (空 or テンプレキーワードのみ)`, phase };
133:   }
134: 
135:   // Common: skip inactive (30+ days no post)
136:   if (last_post_age_days != null && last_post_age_days > 30) {
137:     return { ok: false, reason: `inactive (last post ${last_post_age_days}d ago)`, phase };
138:   }
139: 
140:   // Phase-specific bio checks
141:   if (phase === 1) {
142:     // 2026-05-18 broad mutual-intent keyword set
143:     const bioMatch = /フォロバ|フォローバック|フォロー返し|フォロー返却|フォロー返します|リフォロー|相互(フォロー)?|ふぉろば|フォロー(歓迎|welcome|お気軽|大歓迎)|フォロワー(募集|歓迎|大歓迎|お待ちしてます)|お気軽(に|フォロー)|気軽に(フォロー|どうぞ)|仲間|同志|つながり|繋がり|無言フォ�
144:     const ratioMatch = followingCount > 0 && (
145:       (followingCount >= follower_count * 0.8 && followingCount <= follower_count * 1.5) ||
146:       (followingCount > follower_count && followingCount < 1000)
147:     );
148:     const spamMatch = /いいね回し|相互いいね|拡散希望|相互RT/i.test(bio || "");
149:     if (spamMatch) return { ok: false, reason: "Phase 1: spam pattern in bio", phase };
150:     if (!bioMatch && !ratioMatch) return { ok: false, reason: `Phase 1: no mutual-intent keyword & ratio mismatch (fw=${followingCount}/fr=${follower_count})`, phase };
151:   }
152:   if (phase === 2) {
153:     if (!/節約|ポイ活|お得|貯金|ふるさと|格安|nisa|投資|キャッシュレス|ポイント|還元|家計|貯蓄/i.test(bio || "")) {
154:       return { ok: false, reason: "Phase 2: no relevant topic in bio", phase };
155:     }
156:   }
157:   // 2026-09-25 x144: **ここまで来たもの＝「通るはずだったもの」だけを見る。**
158:   // log のときは記録するだけで返り値を変えない（供給を 1 件も減らさない）
159:   if (NAME_FILTER_MODE !== "off") {
160:     const strong = officialStrong(profile.display_name, bio, handle);
161:     const weak = strong ? null : officialWeak(handle);
162:     const hit = strong || weak;
163:     if (hit) {
164:       try {
165:         fs.appendFileSync(NAME_FILTER_LOG, JSON.stringify({
166:           ts: new Date().toISOString(),
167:           handle,
168:           hit,
169:           strength: strong ? "strong" : "weak",
170:           name: profile.display_name || "",
171:           follower_count, following_count: followingCount,
172:           mode: NAME_FILTER_MODE,
173:           acted: NAME_FILTER_MODE === "on" && !!strong,
174:         }) + "\n");
175:       } catch (e) { /* 記録に失敗してもフォローは止めない */ }
176:       if (NAME_FILTER_MODE === "on" && strong) {
177:         return { ok: false, reason: `official/corporate account (${strong})`, phase };
178:       }
179:     }
180:   }
181: 
182:   // Phase 3: just rely on common filters (already passed range + influencer + activity)
183:   return { ok: true, phase };
184: }
185: 
186: async function getProfileData(page, handle) {
187:   await page.goto(`https://x.com/${handle}`, { waitUntil: "domcontentloaded", timeout: 20000 });
188:   await page.waitForTimeout(2000);
189:   return await page.evaluate((u) => {
190:     const bio = document.querySelector('[data-testid="UserDescription"]')?.textContent || "";
191:     // 2026-09-25 x144: 表示名。**UserName は表示名と @handle が繋がって取れる**が、
192:     // 「【公式】」の判定にはそれで足りる
193:     const displayName = document.querySelector('[data-testid="UserName"]')?.textContent || "";
194:     let followerCount = 0;
195:     const flLink = document.querySelector(`a[href$="/${u}/verified_followers"], a[href$="/${u}/followers"]`);
196:     if (flLink) {
197:       const txt = (flLink.querySelector("span span")?.textContent || "0").replace(/,/g, "");
198:       if (/万/.test(txt)) followerCount = Math.round(parseFloat(txt.replace(/万/g, "")) * 10000);
199:       else if (/k/i.test(txt)) followerCount = Math.round(parseFloat(txt.replace(/k/i, "")) * 1000);
200:       else followerCount = parseInt(txt, 10) || 0;
201:     }
202:     let followingCount = 0;
203:     const fwLink = document.querySelector(`a[href$="/${u}/following"]`);
204:     if (fwLink) {
205:       const txt = (fwLink.querySelector("span span")?.textContent || "0").replace(/,/g, "");
206:       if (/万/.test(txt)) followingCount = Math.round(parseFloat(txt.replace(/万/g, "")) * 10000);
207:       else if (/k/i.test(txt)) followingCount = Math.round(parseFloat(txt.replace(/k/i, "")) * 1000);
208:       else followingCount = parseInt(txt, 10) || 0;
209:     }
210:     // Latest post timestamp
211:     let lastPostAge = null;
212:     const t = document.querySelector('article time');
213:     if (t) {
214:       const ts = new Date(t.getAttribute("datetime")).getTime();
215:       lastPostAge = Math.floor((Date.now() - ts) / (86400 * 1000));
216:     }
217:     // Follow button state
218:     const followBtn = document.querySelector('[data-testid$="-follow"]');
219:     const unfollowBtn = document.querySelector('[data-testid$="-unfollow"]');
220:     return {
221:       bio,
222:       display_name: displayName,
223:       follower_count: followerCount,
224:       following_count: followingCount,
225:       last_post_age_days: lastPostAge,
226:       // 2026-10-12 x278: 青バッジ（認証済み）か。UserName の中のバッジのアイコンで見る
227:       verified: !!document.querySelector('[data-testid="UserName"] [data-testid="icon-verified"]'),
228:       canFollow: !!followBtn,
229:       alreadyFollowing: !!unfollowBtn,
230:     };
231:   }, handle);
232: }
233: 
234: async function main() {
235:   // 2026-08-09: 専用ウィンドウ。Jordanのウィンドウに触れない。
236:   const { openWorkTab } = require("./lib/work-window.js");
237:   const _w = await openWorkTab("follow");
238:   const browser = _w.browser;
239:   const page = _w.page;
240:   try {
241:     const profile = await getProfileData(page, handle);
242: 
243:     if (profile.alreadyFollowing) {
244:       console.log(JSON.stringify({ ok: true, status: "already_following", profile }));
245:       return;
246:     }
247:     if (!profile.canFollow) {
248:       console.log(JSON.stringify({ ok: false, status: "cannot_follow", reason: "no follow button (private/blocked/deleted)", profile }));
249:       return;
250:     }
251: 
252:     // Apply filter unless --no-filter (for explicit refollow / manual override)
253:     if (!NO_FILTER) {
254:       const f = passFilter(profile);
255:       if (!f.ok) {
256:         console.log(JSON.stringify({ ok: false, status: "filtered", reason: f.reason, phase: f.phase, profile }));
257:         return;
258:       }
259:     }
260: 
261:     // Execute follow
262:     /* x480: 押す直前に間隔の決まりを通す（記録する）。絞り込みで落ちた相手は数えない。空かなければ押さずに終わる */ { const _pr = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("follow", 150 * 1000); if (!_pr.ok) { console.log(JSON.stringify({ ok: false, status: "paced", reason: _pr.reason })); process.exit(0);
263:     const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
264:     await btn.click();
265:     await page.waitForTimeout(1500);
266:     const verifyUnfollow = await page.$('[data-testid$="-unfollow"]');
267:     if (verifyUnfollow) {
268:       console.log(JSON.stringify({ ok: true, status: "followed", profile }));
269:     } else {
270:       console.log(JSON.stringify({ ok: false, status: "click_failed", reason: "follow button click didn't change to unfollow", profile }));
271:     }
272:   } catch (e) {
273:     console.log(JSON.stringify({ ok: false, status: "error", reason: e.message }));
274:   } finally {
275:     await page.close();
276:     await browser.close();
277:   }
278: }
279: 
280: main();
```

## いいねのボタンを押している既存のスクリプト（書き方を写すため）
```
/Users/ny/.openclaw/workspace/scripts/bookmark-watcher.js
/Users/ny/.openclaw/workspace/scripts/engage-via-playwright.js
/Users/ny/.openclaw/workspace/scripts/fetch-4-tweets.js
/Users/ny/.openclaw/workspace/scripts/fetch-ffbuncho.js
/Users/ny/.openclaw/workspace/scripts/incoming-reply-responder.js
--- bookmark-watcher.js
81:      const likeAria = a.querySelector('[data-testid="like"], [data-testid="unlike"]')?.getAttribute("aria-label") || "";
90:        likes: parseNum(likeAria),
135:    msg += `• @${b.author} (♥${b.likes} 💬${b.replies} 🔁${b.retweets}): ${b.tweet_url}\n  "${b.text.slice(0, 80).replace(/\n/g," ")}..."\n\n`;
--- engage-via-playwright.js
57: * For each (max 10): navigates to x.com/<handle>, finds latest tweet, clicks like.
61: * Output: single-line JSON {ok, attempted, liked, failed}
91:  if (!fs.existsSync(ENGAGE_LOG_PATH)) return { engagements: [], stats: { total_engagements: 0, total_likes: 0, total_retweets: 0 } };
110:async function likeOne(page, handle) {
114:  // Like button: data-testid="like" (not "unlike")
115:  const likeBtn = await article.$('[data-testid="like"]');
116:  if (!likeBtn) {
117:    // Already liked or not found
118:    const unlike = await article.$('[data-testid="unlike"]');
119:    if (unlike) return { ok: true, status: "already_liked" };
120:    return { ok: false, status: "like_button_not_found" };
122:  await likeBtn.click();
126:  return { ok: true, status: "liked", post_url: tweetUrl };
134:    out({ ok: true, attempted: 0, liked: 0, failed: 0 });
147:  let liked = 0, failed = 0;
```

**読むだけ。LLM 不使用（$0）。**
