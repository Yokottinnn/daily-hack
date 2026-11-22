# 投稿の仕組みは引用と ALT に対応しているか（2026-10-22 22:47:47 JST・読むだけ・$0）

## 1. run-publish.sh が呼ぶもの
```
2:# run-publish.sh (v3.2 2026-05-15: thread_chain サポート)
9:#   - 2個目以降 = reply chain (post-comment.js with previous tweet URL as target)
11:/Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh || { echo '{"ok":false,"step":"ensure-chrome","error":"Chrome failed to start"}'; exit 1; }
14:ENTRY_JSON=$(/usr/local/bin/node -e "
15:const q = require('./data/post_queue.json');
32:HAS_THREAD=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
39:# 🆕 2026-06-07: trend_qt は post-quote-tweet.js で実 QT 化 (旧: 平 post 扱いで意味なかった)
40:KIND=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
46:TARGET_URL=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
53:  echo "[run-publish] trend_qt mode (post-quote-tweet.js)" >&2
54:  QT_TEXT_B64=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
60:  QT_IMG=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
68:    QT_RES=$(/usr/local/bin/node scripts/post-quote-tweet.js "$QT_TEXT_B64" "$TARGET_URL" "$QT_IMG" 2>"$ERR_TMP")
70:    QT_RES=$(/usr/local/bin/node scripts/post-quote-tweet.js "$QT_TEXT_B64" "$TARGET_URL" 2>"$ERR_TMP")
81:  ENTRY_JSON="$ENTRY_JSON" /usr/local/bin/node -e "
104:        ? \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\" \"\${imagePath}\"\`
105:        : \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\"\`;
122:      const cmd = \`/usr/local/bin/node scripts/post-comment.js \"\${textB64}\" \"\${prevUrl}\" \"\${imagePath}\"\`;
151:TEXT_B64=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
157:IMAGE_PATH=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
163:THREAD_TEXT=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
172:  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" "$IMAGE_PATH" 2>"$ERR_TMP")
174:  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" 2>"$ERR_TMP")
179:MAIN_OK=$(echo "$MAIN_RES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
180:MAIN_URL=$(echo "$MAIN_RES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).url||'')}catch{console.log('')}})")
188:  THREAD_RES=$(/usr/local/bin/node scripts/post-comment.js "$THREAD_TEXT_B64" "$MAIN_URL" 2>"$ERR_TMP2")
194:/usr/local/bin/node -e "
```

## 2. scripts/ と lib/ の中で quote / alt / attachment_url を扱っている行
```
/Users/ny/.openclaw/workspace/scripts/run-quote-tweet.sh:2:# run-quote-tweet.sh <entry-id>
/Users/ny/.openclaw/workspace/scripts/run-quote-tweet.sh:3:# Posts a quote tweet for the given queue entry.
/Users/ny/.openclaw/workspace/scripts/run-quote-tweet.sh:21:/usr/local/bin/node scripts/post-quote-tweet.js "$TEXT_B64" "$TARGET"
/Users/ny/.openclaw/workspace/scripts/post-qt-manual.js:40:    // Check if there's a quote card
/Users/ny/.openclaw/workspace/scripts/follow-via-playwright.js:148:  // 注: この filter は follow pipeline のみ。reply/quote engagement 対象には影響なし (別 script)
/Users/ny/.openclaw/workspace/scripts/pipeline-guardian.js:196:// post-quote-tweet.js に同じバグが残っていた（lintで発見）。
/Users/ny/.openclaw/workspace/scripts/cookie-backup.sh:54:  # v2 fix: JSON in VERIFY_OUT contains quotes — write to tmp file to avoid shell interpolation issues
/Users/ny/.openclaw/workspace/scripts/qt-probe-v2.js:3: * qt-probe-v2.js — Wait for embedded quote tweet to load in compose modal, then dump.
/Users/ny/.openclaw/workspace/scripts/qt-probe-v2.js:27:    const quoteLink = page.locator('a[role="menuitem"][href*="/compose/"]').first();
/Users/ny/.openclaw/workspace/scripts/qt-probe-v2.js:28:    await quoteLink.click({ timeout: 5000 });
/Users/ny/.openclaw/workspace/scripts/qt-probe-v2.js:30:    // Wait longer for compose modal + embedded quote to fully render
/Users/ny/.openclaw/workspace/scripts/qt-probe-v2.js:57:      // Look for the embedded quote target. It might be:
/Users/ny/.openclaw/workspace/scripts/qt-probe-v2.js:60:      // - <a href="/X/status/Y"> (link to quoted)
/Users/ny/.openclaw/workspace/scripts/qt-probe-v2.js:62:      const quoteEvidence = {
/Users/ny/.openclaw/workspace/scripts/qt-probe-v2.js:80:        quoteEvidence,
/Users/ny/.openclaw/workspace/scripts/asuka-gen.js:7: *   --kind trend_qt    : quote-tweet style commentary (target_url given)
/Users/ny/.openclaw/workspace/scripts/asuka-gen.js:201:    // Strip surrounding quotes if any
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:39:# 🆕 2026-06-07: trend_qt は post-quote-tweet.js で実 QT 化 (旧: 平 post 扱いで意味なかった)
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:53:  echo "[run-publish] trend_qt mode (post-quote-tweet.js)" >&2
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:68:    QT_RES=$(/usr/local/bin/node scripts/post-quote-tweet.js "$QT_TEXT_B64" "$TARGET_URL" "$QT_IMG" 2>"$ERR_TMP")
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:70:    QT_RES=$(/usr/local/bin/node scripts/post-quote-tweet.js "$QT_TEXT_B64" "$TARGET_URL" 2>"$ERR_TMP")
/Users/ny/.openclaw/workspace/scripts/poll-approvals.js:8: *   - "trend_qt"    → run-quote-tweet.sh     (immediate)
/Users/ny/.openclaw/workspace/scripts/poll-approvals.js:36:  "trend_qt":   "run-quote-tweet.sh",
/Users/ny/.openclaw/workspace/scripts/qt-orchestrator.sh:285:  # Slack draft (post/quote は承認必須継続なので draft-trend.sh 経由 = ✅ 承認待ち format)
/Users/ny/.openclaw/workspace/scripts/queue-manager.js:3: * queue-manager.js v2 — adds support for trend posts, quote tweets, comments, threads.
/Users/ny/.openclaw/workspace/scripts/queue-manager.js:18: *   - "trend_qt"   : quote tweet (text + target_url)
/Users/ny/.openclaw/workspace/scripts/queue-manager.js:105:      //   「post / quote / DM は承認必須。reply / comment のみ自動投稿＋事後報告」
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:3: * post-quote-tweet.js (v5 — 2026-05-22, DOM-probed selectors)
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:4: * Post a quote tweet via Playwright on existing Chrome CDP.
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:6: * Args: <text-base64> <quote-target-url>
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:10: *   - Quote menu = <a href="/compose/post" role="menuitem">引用する</a>
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:11: *   - Compose modal opens, embedded quote shows as:
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:73:    step = "click-quote-menu";
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:74:    const quoteLink = page.locator('a[role="menuitem"][href="/compose/post"]').first();
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:75:    await quoteLink.click({ timeout: 5000 });
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:78:    // Compose opens with embedded quote loading async. Wait for progressBar to complete.
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:89:    step = "verify-quote-embedded";
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:90:    // Probed: embedded quote shown as [data-testid="UserAvatar-Container-<handle>"] inside dialog
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:92:    const quoteOk = await page.locator(handleSelector).count() > 0;
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:93:    if (!quoteOk) {
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:107:        out({ ok: false, step, error: `embedded quote not detected for @${targetHandle} — aborting` });
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:133:      console.log("[post-quote-tweet] attached " + imagePaths.length + " image(s)");
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:201:    step = "post-verify-is-quote";
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:202:    // Visit the new tweet, check it has an embedded quote (UserAvatar-Container-<targetHandle> appears in primary article)
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:205:    const isQuote = await page.evaluate((h) => {
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:209:      // The embedded quoted user's avatar should appear in the primary article
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:225:    if (!isQuote.ok) {
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:228:        step: "post-verify-is-quote",
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:229:        error: "post completed but verification did NOT find embedded quote — bare post may have been created",
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:233:        verify: isQuote,
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js:246:    out({ ok: true, tweet_id: tweetId, url: tweetUrl, mode: "v5-probed-selectors", verify: isQuote });
/Users/ny/.openclaw/workspace/scripts/qt-probe.js:3: * qt-probe.js — Non-destructive DOM probe of X UI quote-tweet menu.
/Users/ny/.openclaw/workspace/scripts/qt-probe.js:4: * Walks: navigate target → click Repost → dump dropdown DOM → click Quote anchor → dump compose modal → ESC (no submit).
/Users/ny/.openclaw/workspace/scripts/qt-probe.js:82:    // Step 5: click Quote menu item (try multiple ways)
/Users/ny/.openclaw/workspace/scripts/qt-probe.js:83:    let quoteClicked = false;
/Users/ny/.openclaw/workspace/scripts/qt-probe.js:87:      quoteClicked = "anchor /compose/post";
/Users/ny/.openclaw/workspace/scripts/qt-probe.js:89:    if (!quoteClicked) {
/Users/ny/.openclaw/workspace/scripts/qt-probe.js:91:        const byText = page.locator('[role="menuitem"]:has-text("引用"), [role="menuitem"]:has-text("Quote"), [role="menuitem"]:has-text("引用ポスト")').first();
/Users/ny/.openclaw/workspace/scripts/qt-probe.js:93:        quoteClicked = "text-based 引用/Quote";
/Users/ny/.openclaw/workspace/scripts/qt-probe.js:96:    probe.steps.push({ step: "quote-menu-click", clicked: quoteClicked || false });
```

## 3. 投稿本体のファイル（run-publish.sh から辿れるもの）の、テキストと画像を入れる箇所
```
--- post-comment.js (363 行)
49:    // primary: tweetTextarea_0 (inline compose、 常時表示 bar)
52:      'div[data-testid^="tweetTextarea_"][contenteditable="true"]',
53:      'div[data-testid="tweetTextarea_0"]',
144:    // 2026-07-13 REWRITE: insertText は JS 直接注入で React onChange 発火せず → submit button disabled のまま
145:    //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
146:    await page.keyboard.type(text, { delay: 4 });
150:    // run-publish.sh が chain[i].image_path を第 3 引数で渡してくる（i>=1 の reply）。
151:    // これが無かったため、スキーマに image_path? と書いてあっても
162:      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
163:      if (!fileInput) fileInput = await page.$('input[type="file"]');
164:      if (!fileInput) { out({ ok: false, step, error: "file input not found on reply composer" }); process.exit(1); }
165:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
166:      // **付いたことを確かめてから送信する。** setInputFiles は投げるだけで待たない。
182:        const t = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
252:      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
--- post-quote-tweet.js (255 行)
3: * post-quote-tweet.js (v5 — 2026-05-22, DOM-probed selectors)
4: * Post a quote tweet via Playwright on existing Chrome CDP.
6: * Args: <text-base64> <quote-target-url>
10: *   - Quote menu = <a href="/compose/post" role="menuitem">引用する</a>
11: *   - Compose modal opens, embedded quote shows as:
14: *   - Textarea: dialog > [data-testid="tweetTextarea_0"]
73:    step = "click-quote-menu";
74:    const quoteLink = page.locator('a[role="menuitem"][href="/compose/post"]').first();
75:    await quoteLink.click({ timeout: 5000 });
78:    // Compose opens with embedded quote loading async. Wait for progressBar to complete.
89:    step = "verify-quote-embedded";
90:    // Probed: embedded quote shown as [data-testid="UserAvatar-Container-<handle>"] inside dialog
92:    const quoteOk = await page.locator(handleSelector).count() > 0;
93:    if (!quoteOk) {
95:      const altOk = await page.evaluate((h) => {
106:      if (!altOk) {
107:        out({ ok: false, step, error: `embedded quote not detected for @${targetHandle} — aborting` });
113:    const ta = page.locator('div[role="dialog"] div[data-testid="tweetTextarea_0"][contenteditable="true"]').first();
119:    await page.keyboard.type(text, { delay: 4 });
126:      let fileInput = await dialog.locator('input[type="file"][data-testid="fileInput"]').first().elementHandle().catch(() => null);
127:      if (!fileInput) fileInput = await dialog.locator('input[type="file"]').first().elementHandle().catch(() => null);
128:      if (!fileInput) {
132:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
133:      console.log("[post-quote-tweet] attached " + imagePaths.length + " image(s)");
201:    step = "post-verify-is-quote";
202:    // Visit the new tweet, check it has an embedded quote (UserAvatar-Container-<targetHandle> appears in primary article)
205:    const isQuote = await page.evaluate((h) => {
209:      // The embedded quoted user's avatar should appear in the primary article
225:    if (!isQuote.ok) {
228:        step: "post-verify-is-quote",
--- post-comment.js (363 行)
49:    // primary: tweetTextarea_0 (inline compose、 常時表示 bar)
52:      'div[data-testid^="tweetTextarea_"][contenteditable="true"]',
53:      'div[data-testid="tweetTextarea_0"]',
144:    // 2026-07-13 REWRITE: insertText は JS 直接注入で React onChange 発火せず → submit button disabled のまま
145:    //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
146:    await page.keyboard.type(text, { delay: 4 });
150:    // run-publish.sh が chain[i].image_path を第 3 引数で渡してくる（i>=1 の reply）。
151:    // これが無かったため、スキーマに image_path? と書いてあっても
162:      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
163:      if (!fileInput) fileInput = await page.$('input[type="file"]');
164:      if (!fileInput) { out({ ok: false, step, error: "file input not found on reply composer" }); process.exit(1); }
165:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
166:      // **付いたことを確かめてから送信する。** setInputFiles は投げるだけで待たない。
182:        const t = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
252:      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
--- post-quote-tweet.js (255 行)
3: * post-quote-tweet.js (v5 — 2026-05-22, DOM-probed selectors)
4: * Post a quote tweet via Playwright on existing Chrome CDP.
6: * Args: <text-base64> <quote-target-url>
10: *   - Quote menu = <a href="/compose/post" role="menuitem">引用する</a>
11: *   - Compose modal opens, embedded quote shows as:
14: *   - Textarea: dialog > [data-testid="tweetTextarea_0"]
73:    step = "click-quote-menu";
74:    const quoteLink = page.locator('a[role="menuitem"][href="/compose/post"]').first();
75:    await quoteLink.click({ timeout: 5000 });
78:    // Compose opens with embedded quote loading async. Wait for progressBar to complete.
89:    step = "verify-quote-embedded";
90:    // Probed: embedded quote shown as [data-testid="UserAvatar-Container-<handle>"] inside dialog
92:    const quoteOk = await page.locator(handleSelector).count() > 0;
93:    if (!quoteOk) {
95:      const altOk = await page.evaluate((h) => {
106:      if (!altOk) {
107:        out({ ok: false, step, error: `embedded quote not detected for @${targetHandle} — aborting` });
113:    const ta = page.locator('div[role="dialog"] div[data-testid="tweetTextarea_0"][contenteditable="true"]').first();
119:    await page.keyboard.type(text, { delay: 4 });
126:      let fileInput = await dialog.locator('input[type="file"][data-testid="fileInput"]').first().elementHandle().catch(() => null);
127:      if (!fileInput) fileInput = await dialog.locator('input[type="file"]').first().elementHandle().catch(() => null);
128:      if (!fileInput) {
132:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
133:      console.log("[post-quote-tweet] attached " + imagePaths.length + " image(s)");
201:    step = "post-verify-is-quote";
202:    // Visit the new tweet, check it has an embedded quote (UserAvatar-Container-<targetHandle> appears in primary article)
205:    const isQuote = await page.evaluate((h) => {
209:      // The embedded quoted user's avatar should appear in the primary article
225:    if (!isQuote.ok) {
228:        step: "post-verify-is-quote",
--- post-via-playwright.js (276 行)
56:    const textareaSelector = 'div[data-testid^="tweetTextarea_"][contenteditable="true"]';
62:    await page.keyboard.insertText(text);
68:      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
69:      if (!fileInput) fileInput = await page.$('input[type="file"]');
70:      if (!fileInput) throw new Error("file input not found on compose page");
71:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
103:      // 2026-10-11 x264: 画像の説明（ALT）。ALT_TEXTS_FILE（JSON 配列）があれば、i 枚目に alts[i] を入れる（空ならその画像は飛ばす）。
104:      // CC BY / CC BY-SA の撮影者名を ALT に書く運用（CLAUDE.md 最上位ルール 8）。**入れられなければ投稿しない**（throw → 投稿ボタンを押さない）。
105:      // 画面の作りは x263 で実物を読んだ: 添付ごとの [data-testid="altTextWrapper"] → 編集画面の textarea → [data-testid="endEditingButton"]
106:      if (process.env.ALT_TEXTS_FILE) {
107:        step = "alt-text";
108:        const alts = JSON.parse(fs.readFileSync(process.env.ALT_TEXTS_FILE, "utf8"));
109:        for (let i = 0; i < alts.length; i++) {
110:          if (!alts[i]) continue;
111:          // 2026-10-11 x265: 複数枚を添付すると altTextWrapper は 1 個にまとまる（x264 で実測）。
114:          const wrappers = page.locator('[data-testid="attachments"] [data-testid="altTextWrapper"]');
116:          if (n === 0) throw new Error("altTextWrapper が無い");
141:          if (!(await box.count())) throw new Error("ALT の入力欄が見つからない（" + (i + 1) + " 枚目）");
142:          await box.fill(alts[i]);
145:          if (got.replace(/\s/g, "") !== String(alts[i]).replace(/\s/g, "")) throw new Error("ALT が入りきらない（" + (i + 1) + " 枚目） got_len=" + got.length + " want_len=" + alts[i].length);
147:          if (!(await save.count())) throw new Error("ALT の保存ボタンが無い");
150:          console.error("[post-via-playwright] alt set for image " + (i + 1) + " (" + got.length + " chars)");
208:      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
```

**読んだだけ。投稿していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
