# フォローの的を認証済みに寄せる（2026-10-12 21:33:21 JST・$0・フォローは実行していない）

```json
{"ok":true,"report":["follow-handle.js: 書いた・node --check 通過","competitor-follower-follow.js: 書いた・node --check 通過","hashtag-follow.js: 書いた・node --check 通過"]}
```

## 当たった行（印 x278 の前後）

```javascript
// --- follow-handle.js
95:  // 2026-10-12 x278: 呼び出し側が求めたときだけ、未認証を弾く（青バッジのアカウントに寄せる）
96-  if (process.env.FOLLOW_REQUIRE_VERIFIED === "1" && profile.verified === false) {
97-    return { ok: false, reason: "not verified (FOLLOW_REQUIRE_VERIFIED)", phase };
98-  }
--
225:      // 2026-10-12 x278: 青バッジ（認証済み）か。UserName の中のバッジのアイコンで見る
226-      verified: !!document.querySelector('[data-testid="UserName"] [data-testid="icon-verified"]'),
227-      canFollow: !!followBtn,
228-      alreadyFollowing: !!unfollowBtn,
// --- competitor-follower-follow.js
85:    // 2026-10-12 x278: 認証済みフォロワーだけの一覧から取る（COMPETITOR_VERIFIED_ONLY=0 で従来どおり）
86-    const listPath = process.env.COMPETITOR_VERIFIED_ONLY === "0" ? "followers" : "verified_followers";
87-    await page.goto(`https://x.com/${competitor}/${listPath}`, { waitUntil: "domcontentloaded", timeout: 30000 });
88-    await page.waitForTimeout(3500);
// --- hashtag-follow.js
145:      // 2026-10-12 x278: 認証済みの投稿者だけをフォローする（HASHTAG_REQUIRE_VERIFIED=0 で従来どおり）
146-      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2 * 1024 * 1024, env: Object.assign({}, process.env, { FOLLOW_REQUIRE_VERIFIED: process.env.HASHTAG_REQUIRE_VERIFIED === "0" ? "" : "1" }) });
147-      const r = JSON.parse(out.trim().split("\n").pop());
148-      results.push({ author: p.author, ok: r.ok, info: r });
```

**フォローは実行していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。** 戻すときは各ファイルの .bak-x278。
