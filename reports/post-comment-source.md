# reply に画像を足すために実物を読む（2026-09-23 20:59 JST・$0）

**このレポートが作られた時刻: 2026-09-23 20:59:38 JST**

> **読むだけ。** 投稿も、積むことも、書き換えもしていない。

## 0. 大きさ

```
  post-comment.js                265 行     12643 bytes
  post-via-playwright.js         225 行     11446 bytes
  run-publish.sh                 210 行      8770 bytes
```

## 1. `post-comment.js` の全文

**足す場所を決めるために通しで読む。** 引数の受け口・投稿ボタンの押し方・
返している JSON の形が要る。

```javascript
     1	#!/usr/bin/env node
     2	/**
     3	 * post-comment.js v2 (2026-05-15: pinned-tweet ID bug 真の修正)
     4	 * Capture CreateTweet GraphQL response for reliable tweet ID, scraping fallback.
     5	 *
     6	 * Args: <text-base64> <reply-target-url>
     7	 * Output: JSON {ok, reply_tweet_id?, url?, error?, step?, captured_via?}
     8	 */
     9	const { chromium } = require("playwright-core");
    10	
    11	const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
    12	const X_USERNAME = "heng_ji31590";
    13	
    14	function out(obj) { console.log(JSON.stringify(obj)); }
    15	
    16	// 2026-06-12: 文字化け投稿事故対策
    17	const { decodeBase64Safe } = require("./lib/text-safety");
    18	
    19	async function main() {
    20	  const [textArg, targetUrl] = process.argv.slice(2);
    21	  if (!textArg || !targetUrl) { out({ ok: false, error: "args: <text-b64> <target-url>" }); process.exit(1); }
    22	  const decoded = decodeBase64Safe(textArg);
    23	  if (!decoded.ok) {
    24	    out({ ok: false, step: "text-safety", error: "decode/validation failed", reason: decoded.reason, details: decoded.details });
    25	    process.exit(1);
    26	  }
    27	  const text = decoded.text;
    28	
    29	  let browser, page;
    30	  const t0 = Date.now();
    31	  let step = "connect";
    32	    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
    33	  try {
    34	    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 60000 });
    35	    const ctx = browser.contexts()[0];
    36	    page = await ctx.newPage();
    37	
    38	    step = "navigate-target";
    39	    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
    40	    await page.bringToFront().catch(()=>{});
    41	    await page.goto(targetUrl, { waitUntil: "domcontentloaded", timeout: 20000 }).catch((e)=>{ console.error("[goto-err]", e.message.slice(0,80)); });
    42	    // 2026-07-25: 3s → 6s + waitForLoadState 追加、 SPA 遅延吸収
    43	    await page.waitForLoadState("domcontentloaded", { timeout: 5000 }).catch(()=>{});
    44	    await page.waitForTimeout(6000);
    45	
    46	    step = "find-reply-textarea";
    47	    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
    48	    // 2026-07-25 REVIVAL: 4日 comment 0件事故 → 選択子 4 個 順次 try、 失敗時 reply btn click fallback、 各段階 log
    49	    // primary: tweetTextarea_0 (inline compose、 常時表示 bar)
    50	    // fallback: role=textbox, aria-label 系
    51	    const selectors = [
    52	      'div[data-testid^="tweetTextarea_"][contenteditable="true"]',
    53	      'div[data-testid="tweetTextarea_0"]',
    54	      'div[role="textbox"][contenteditable="true"][aria-label*="ポスト"]',
    55	      'div[role="textbox"][contenteditable="true"]',
    56	    ];
    57	    let ta = null;
    58	    for (const sel of selectors) {
    59	      try {
    60	        ta = await page.waitForSelector(sel, { timeout: 6000 });
    61	        if (ta) { console.error("[textarea] found via primary sel: " + sel + " t=" + ((Date.now()-t0)|0) + "ms"); break; }
    62	      } catch (_) {
    63	        console.error("[textarea] not via: " + sel + " t=" + ((Date.now()-t0)|0) + "ms");
    64	      }
    65	    }
    66	    if (!ta) {
    67	      console.error("[textarea] primary all failed, trying reply btn click t=" + ((Date.now()-t0)|0) + "ms");
    68	      const replyBtn = await page.$('[data-testid="reply"]').catch(()=>null);
    69	      if (replyBtn) {
    70	        await replyBtn.click().catch((e)=>{ console.error("[reply-click-err]", e.message.slice(0,60)); });
    71	        await page.waitForTimeout(4000);
    72	        for (const sel of selectors) {
    73	          try {
    74	            ta = await page.waitForSelector(sel, { timeout: 5000 });
    75	            if (ta) { console.error("[textarea] found post-click via: " + sel + " t=" + ((Date.now()-t0)|0) + "ms"); break; }
    76	          } catch (_) {}
    77	        }
    78	      } else {
    79	        console.error("[textarea] no reply btn either t=" + ((Date.now()-t0)|0) + "ms");
    80	      }
    81	    }
    82	    if (!ta) {
    83	      // DOM snapshot for debug
    84	      const dumpPath = "/tmp/post-comment-no-textarea-" + Date.now() + ".html";
    85	      try {
    86	        const html = await page.content();
    87	        require("fs").writeFileSync(dumpPath, html);
    88	        console.error("[textarea] DOM dumped: " + dumpPath);
    89	      } catch (_) {}
    90	      out({ ok: false, step, error: "no reply textarea", dump: dumpPath });
    91	      process.exit(1);
    92	    }
    93	
    94	    step = "type-text";
    95	    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
    96	    await ta.click();
    97	    await page.waitForTimeout(400);
    98	    // 2026-07-13 REWRITE: insertText は JS 直接注入で React onChange 発火せず → submit button disabled のまま
    99	    //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
   100	    await page.keyboard.type(text, { delay: 4 });
   101	    await page.waitForTimeout(1500);
   102	
   103	    step = "arm-response-listener";
   104	    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
   105	    // 2026-05-15 v2: Listen for CreateTweet GraphQL response (most reliable tweet ID source)
   106	    const responsePromise = page.waitForResponse(
   107	      (resp) => /\/(CreateTweet|CreateNoteTweet|create_tweet)/i.test(resp.url()) && resp.request().method() === "POST",
   108	      { timeout: 20000 }
   109	    ).catch(() => null);
   110	
   111	    step = "submit";
   112	    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
   113	    // 2026-07-13 REWRITE: button click 優先 (enabled 確認後)、 fallback で Meta+Enter
   114	    const submitBtn = page.locator('[data-testid="tweetButtonInline"], [data-testid="tweetButton"]').first();
   115	    let submitted = false;
   116	    try {
   117	      await submitBtn.waitFor({ timeout: 8000 });
   118	      // Verify enabled — text がちゃんと React state に入ってれば aria-disabled=false
   119	      const isDisabled = await submitBtn.evaluate(el => el.getAttribute("aria-disabled") === "true" || el.disabled).catch(() => false);
   120	      if (!isDisabled) {
   121	        await submitBtn.click({ timeout: 5000 });
   122	        submitted = true;
   123	      }
   124	    } catch (_) {}
   125	    // Fallback: keyboard shortcut (Meta+Enter or Ctrl+Enter)
   126	    if (!submitted) {
   127	      await ta.focus().catch(() => {});
   128	      await page.waitForTimeout(200);
   129	      await page.keyboard.press("Meta+Enter").catch(() => {});
   130	      await page.waitForTimeout(500);
   131	      await page.keyboard.press("Control+Enter").catch(() => {});
   132	    }
   133	
   134	    step = "wait-response-or-confirm";
   135	    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
   136	    const response = await responsePromise;
   137	    let capturedTweetId = null;
   138	    let capturedVia = null;
   139	    if (response) {
   140	      try {
   141	        const json = await response.json();
   142	        // X GraphQL has multiple shapes; cover the common ones
   143	        capturedTweetId = json?.data?.create_tweet?.tweet_results?.result?.rest_id
   144	                       || json?.data?.notetweet_create?.tweet_results?.result?.rest_id
   145	                       || json?.data?.tweet?.rest_id
   146	                       || null;
   147	        if (capturedTweetId) capturedVia = "graphql_response";
   148	      } catch (e) { /* ignore parse errors */ }
   149	    }
   150	
   151	    step = "wait-textarea-clear";
   152	    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
   153	    await page.waitForFunction(() => {
   154	      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
   155	      return !ta || ta.textContent.trim() === "";
   156	    }, { timeout: 15000 }).catch(() => null);
   157	    await page.waitForTimeout(2000);
   158	
   159	    // If GraphQL capture failed, fall back to scraping /with_replies (smarter than v1)
   160	    if (!capturedTweetId) {
   161	      step = "fallback-fetch-reply-id";
   162	    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
   163	      await page.goto(`https://x.com/${X_USERNAME}/with_replies`, { waitUntil: "domcontentloaded", timeout: 20000 }).catch(() => {});
   164	      await page.waitForTimeout(4000);
   165	      // Get the parent tweet ID we replied to (to exclude it)
   166	      const parentMatch = targetUrl.match(/status\/(\d+)/);
   167	      const parentId = parentMatch ? parentMatch[1] : null;
   168	
   169	      // 2026-08-07 修正: 旧実装は「親以外で最初に見つかった自分の status」を無条件に採用していた。
   170	      // 返信が実際には投稿されていなくても直近の別ツイート ID を掴んで ok:true を返すため、
   171	      // スレッドの複数投稿が同じ ID になったり、誤爆に気付けなかった。本文一致を必須にする。
   172	      const needle = text.replace(/\s+/g, "").slice(0, 18);
   173	      capturedTweetId = await page.$$eval(
   174	        'article',
   175	        (articles, args) => {
   176	          const { username, parentId, needle } = args;
   177	          for (const article of articles) {
   178	            // Skip pinned
   179	            const sc = article.querySelector('[data-testid="socialContext"]');
   180	            if (sc && /固定|Pinned/i.test(sc.textContent || "")) continue;
   181	            const body = (article.innerText || "").replace(/\s+/g, "");
   182	            if (needle && !body.includes(needle)) continue;   // 本文が違うものは採用しない
   183	            // Collect ALL status links in this article, return the LAST own status that is NOT the parent
   184	            const links = article.querySelectorAll('a[href*="/status/"]');
   185	            const ownStatusIds = [];
   186	            for (const a of links) {
   187	              const m = a.getAttribute("href").match(new RegExp(`/${username}/status/(\\d+)`, "i"));
   188	              if (m && m[1] !== parentId) ownStatusIds.push(m[1]);
   189	            }
   190	            if (ownStatusIds.length > 0) return ownStatusIds[0]; // first own (= the reply we just posted)
   191	          }
   192	          return null;
   193	        },
   194	        { username: X_USERNAME, parentId, needle }
   195	      );
   196	      if (capturedTweetId) capturedVia = "scrape_fallback_verified";
   197	    }
   198	
   199	    await page.close();
   200	    await browser.close();
   201	
   202	    if (!capturedTweetId) { out({ ok: false, step, error: "couldn't capture reply tweet id (graphql + scrape both failed)" }); process.exit(1); }
   203	
   204	    // 2026-07-20 Layer 2: reply linkage post-verify
   205	    // 独立 tweet 化 (X 側で 親 tweet と の 関係 保持失敗) を検知して 即削除
   206	    step = "verify-reply-linkage";
   207	    let linkageOK = false;
   208	    try {
   209	      const verifyPage = await browser.contexts()[0].newPage();
   210	      await verifyPage.goto(`https://x.com/${X_USERNAME}/status/${capturedTweetId}`, { waitUntil: "domcontentloaded", timeout: 15000 }).catch(()=>{});
   211	      await verifyPage.waitForTimeout(4000);
   212	      const parentMatch = targetUrl.match(/status\/(\d+)/);
   213	      const parentTweetId = parentMatch ? parentMatch[1] : null;
   214	      linkageOK = await verifyPage.evaluate((args) => {
   215	        const { parentId } = args;
   216	        // 返信先 indicator: socialContext with "返信先" text, OR link to parent status ID
   217	        const socialCtxs = document.querySelectorAll('[data-testid="socialContext"], [data-testid="reply-context"]');
   218	        for (const el of socialCtxs) {
   219	          if (/返信先|Replying to/i.test(el.textContent || "")) return true;
   220	        }
   221	        // Or: any link to the parent tweet
   222	        if (parentId) {
   223	          const links = document.querySelectorAll(`a[href*="/status/${parentId}"]`);
   224	          if (links.length > 0) return true;
   225	        }
   226	        return false;
   227	      }, { parentId: parentTweetId }).catch(()=>false);
   228	      await verifyPage.close().catch(()=>{});
   229	    } catch (e) { /* verify page error → treat as unknown, skip delete */ linkageOK = true; }
   230	
   231	    if (!linkageOK) {
   232	      // 独立 tweet 化検出 → 即削除
   233	      try {
   234	        const { execSync } = require("child_process");
   235	        execSync(`ALLOW_DESTRUCTIVE=1 /usr/local/bin/node ${require("path").join(__dirname, "delete-tweet.js")} ${capturedTweetId} ${X_USERNAME}`, { timeout: 30000, stdio: "ignore" });
   236	      } catch (e) { /* delete fail, still report linkage-lost */ }
   237	      await page.close().catch(()=>{});
   238	      await browser.close().catch(()=>{});
   239	      out({ ok: false, step: "reply-linkage-lost", error: "posted but reply linkage lost, auto-deleted", tweet_id: capturedTweetId, target_url: targetUrl });
   240	      process.exit(1);
   241	    }
   242	
   243	    // 2026-06-12: 投稿成功後 30s 内に文字化け watchdog を背景 spawn
   244	    try {
   245	      const { spawn } = require("child_process");
   246	      const watchdog = spawn("/usr/local/bin/node", [require("path").join(__dirname, "post-publish-watchdog.js"), capturedTweetId], {
   247	        detached: true, stdio: "ignore", env: process.env,
   248	      });
   249	      watchdog.unref();
   250	    } catch (e) { /* watchdog spawn failure must not break main return */ }
   251	    out({
   252	      ok: true,
   253	      reply_tweet_id: capturedTweetId,
   254	      url: `https://x.com/${X_USERNAME}/status/${capturedTweetId}`,
   255	      captured_via: capturedVia,
   256	    });
   257	  } catch (e) {
   258	    if (page) try { await page.close(); } catch {}
   259	    if (browser) try { await browser.close(); } catch {}
   260	    out({ ok: false, step, error: e.message });
   261	    process.exit(1);
   262	  }
   263	}
   264	
   265	main();
```

## 2. `post-via-playwright.js` の画像添付（**この書き方を写す**）

同じことを既にやっている箇所。**セレクタも待ちも実績がある。**

```javascript
     1	    out({ ok: false, step: "text-safety", error: "decode/validation failed", reason: decoded.reason, details: decoded.details });
     2	    process.exit(1);
     3	  }
     4	  const text = decoded.text;
     5	  // 2026-05-21: multi-image support — accept comma-separated list, X allows up to 4 images
     6	  const imagePathArg = process.argv[3] || null;
     7	  const imagePaths = (imagePathArg && imagePathArg !== "null") ? imagePathArg.split(",").map(p => p.trim()).filter(Boolean) : [];
     8	  const imagePath = imagePaths[0] || null;  // backward compat
     9	  // 2026-05-20: CHAR_ONLY guard — bare-character images rejected by user (low quality)
    10	  const isCharOnly = imagePaths.some(p => p.includes("/character-library/"));
    11	  if (isCharOnly) { console.warn("[post-via-playwright] CHAR_ONLY image refused:", imagePaths.find(p => p.includes("/character-library/"))); }
    12	  const hasImage = imagePaths.length > 0 && !isCharOnly && imagePaths.every(p => fs.existsSync(p));
    13	  if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }
    14	
    15	  let browser, context, page;
    16	  let step = "connect";
    17	  try {
    18	    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
    19	    const contexts = browser.contexts();
    20	    if (contexts.length === 0) { out({ ok: false, step, error: "no contexts" }); process.exit(1); }
    21	    context = contexts[0];
    22	    page = await context.newPage();
    23	    // 2026-05-31 fix: dialog 自動 dismiss (notification permission 等で Playwright が死ぬ問題回避)
    24	    page.on("dialog", d => { d.dismiss().catch(() => {}); });
    25	
    26	    step = "navigate-compose";
    27	    await page.goto(COMPOSE_URL, { waitUntil: "domcontentloaded", timeout: 30000 });
    28	
    29	    step = "wait-textarea";
    30	    // 2026-07-06: X UI render 遅延で 20s timeout 発生 → 5s pre-wait + 30s に緩和 (post-comment.js と同様)
    31	    await page.waitForTimeout(5000);
    32	    const textareaSelector = 'div[data-testid^="tweetTextarea_"][contenteditable="true"]';
    33	    await page.waitForSelector(textareaSelector, { timeout: 30000 });
    34	
    35	    step = "focus-and-type";
    36	    const ta = await page.$(textareaSelector);
    37	    await ta.click();
    38	    await page.keyboard.insertText(text);
    39	    await page.waitForTimeout(800);
    40	
    41	    let imageAttached = false;
    42	    if (hasImage) {
    43	      step = "attach-image";
    44	      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
    45	      if (!fileInput) fileInput = await page.$('input[type="file"]');
    46	      if (!fileInput) throw new Error("file input not found on compose page");
    47	      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
    48	      step = "wait-image-upload";
    49	
    50	      // 2026-08-09 修正: 旧実装は role="progressbar" が 0 になるのを完了条件にしていたが、
    51	      // これは X の「文字数カウンターの円形インジケータ」で常時 3 個存在する。
    52	      // よって条件は永遠に成立せず、.catch() で握り潰されたままアップロード途中で送信され、
    53	      // 画像が 1 枚も付かないまま投稿されていた (画像つき投稿がほぼ毎回これで失敗)。
    54	      // 正しい完了サインは「添付プレビューの画像枚数」と「各画像の削除ボタン数」。
    55	      const want = imagePaths.length;
    56	      let attachedCount = 0;
    57	      for (let i = 0; i < 45; i++) {
    58	        attachedCount = await page.evaluate(() => {
    59	          const box = document.querySelector('[data-testid="attachments"]');
    60	          if (!box) return 0;
    61	          const imgs = box.querySelectorAll("img").length;
    62	          const removes = document.querySelectorAll('[aria-label*="削除"], [data-testid="removeMedia"]').length;
    63	          // プレビューと削除ボタンが揃って初めて「その枚数はアップロード済み」と見なせる
    64	          return Math.min(imgs, removes || imgs);
    65	        });
    66	        if (attachedCount >= want) break;
    67	        await page.waitForTimeout(2000);
    68	      }
    69	      if (attachedCount < want) {
    70	        await page.close(); await browser.close();
    71	        out({ ok: false, step, error: "画像のアップロードが完了しないため投稿を中止しました",
    72	              images_expected: want, images_attached: attachedCount });
    73	        process.exit(1);
    74	      }
    75	      console.error(`[post-via-playwright] attached ${attachedCount}/${want} image(s)`);
    76	      await page.waitForTimeout(1500);
    77	      imageAttached = true;
    78	    }
    79	
    80	    // 2026-05-15 v3: arm GraphQL response listener BEFORE submit
    81	    step = "arm-response-listener";
    82	    const responsePromise = page.waitForResponse(
    83	      (resp) => /\/(CreateTweet|CreateNoteTweet|create_tweet)/i.test(resp.url()) && resp.request().method() === "POST",
    84	      { timeout: 30000 }
    85	    ).catch(() => null);
    86	
```

## 3. `run-publish.sh` の reply を組み立てている行の前後

**ここに `imagePath` を足す。** 行番号を確かめる。

```bash
     1	        results.push({ index: i, role: item.role || 'main', ...r });
     2	        if (r.ok && r.url) prevUrl = r.url;
     3	        else { console.log(JSON.stringify({ ok: false, step: 'thread-main', error: r.error || 'main post failed', thread_results: results })); return; }
     4	      } catch (e) {
     5	        console.log(JSON.stringify({ ok: false, step: 'thread-main-exec', error: e.message, thread_results: results }));
     6	        return;
     7	      }
     8	    } else {
     9	      // Reply to previous
    10	      if (!prevUrl) { console.log(JSON.stringify({ ok: false, step: 'thread-reply', error: 'no prev url for reply ' + i, thread_results: results })); return; }
    11	      // Brief delay for X to process previous
    12	      await new Promise(r => setTimeout(r, 5000));
    13	      const cmd = \`/usr/local/bin/node scripts/post-comment.js \"\${textB64}\" \"\${prevUrl}\"\`;
    14	      try {
    15	        const out = execSync(cmd, { encoding: 'utf8' });
    16	        const lines = out.trim().split('\n');
    17	        const r = JSON.parse(lines[lines.length - 1]);
    18	        results.push({ index: i, role: item.role || 'reply', ...r });
    19	        if (r.ok && r.url) prevUrl = r.url;
    20	        else { console.log(JSON.stringify({ ok: false, step: 'thread-reply-' + i, error: r.error || 'reply ' + i + ' failed', thread_results: results })); return; }
    21	      } catch (e) {
    22	        console.log(JSON.stringify({ ok: false, step: 'thread-reply-' + i + '-exec', error: e.message, thread_results: results })); return;
    23	      }
    24	    }
    25	  }
    26	  // All succeeded
```

---

## 直すときの注意（**このタスクでは直さない**）

- **macOS には `sed -i` が無い**（`-i ''` が要る）。**`awk` で書いて `mv`**（最上位ルール 14）
- **一時ファイルに `.new` を付けない。** node が拡張子で弾く。隠しファイル名にする
- **`playwright` ではなく `playwright-core`**（契約書 §1）
- **書き換えたら `node --check` を通す。** 通らなければ元に戻す
- **元ファイルのバックアップを取ってから書く。** 投稿経路の本体である

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
