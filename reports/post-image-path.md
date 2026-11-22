# 画像が付かなかった原因を読む（2026-10-23 08:25:31 JST・$0）
## 1. run-publish.sh の 1 本だけの経路（140〜200 行）
```
  echo '{"ok":false,"step":"read-entry","error":"entry not found"}'
  exit 1
fi

HAS_THREAD=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const o = JSON.parse(d);
  process.stdout.write((o.thread_chain && Array.isArray(o.thread_chain) && o.thread_chain.length > 1) ? 'yes' : 'no');
});
")

# 🆕 2026-06-07: trend_qt は post-quote-tweet.js で実 QT 化 (旧: 平 post 扱いで意味なかった)
KIND=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
    url: main.url,
    thread_count: results.length,
    thread_results: results,
    captured_via: main.captured_via || 'thread_main',
  }));
})();
"
  exit 0
fi

# === Branch 2: legacy single-post mode (with optional image + thread_url_text) ===
TEXT_B64=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const o = JSON.parse(d);
  process.stdout.write(Buffer.from(o.text, 'utf8').toString('base64'));
});
")
IMAGE_PATH=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const o = JSON.parse(d);
  process.stdout.write(o.image_path || '');
});
")
THREAD_TEXT=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const o = JSON.parse(d);
  process.stdout.write(o.thread_url_text || '');
});
")

ERR_TMP=$(mktemp)
if [ -n "$IMAGE_PATH" ] && [ -f "$IMAGE_PATH" ]; then
  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" "$IMAGE_PATH" 2>"$ERR_TMP")
else
  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" 2>"$ERR_TMP")
fi
if [ -s "$ERR_TMP" ]; then cat "$ERR_TMP" >&2; fi
rm -f "$ERR_TMP"

MAIN_OK=$(echo "$MAIN_RES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
MAIN_URL=$(echo "$MAIN_RES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).url||'')}catch{console.log('')}})")

THREAD_RES=""
if [ "$MAIN_OK" = "true" ] && [ -n "$THREAD_TEXT" ] && [ -n "$MAIN_URL" ]; then
  echo "[run-publish] thread_url_text present, sleeping 8s..." >&2
  sleep 8
  THREAD_TEXT_B64=$(printf "%s" "$THREAD_TEXT" | base64)
  ERR_TMP2=$(mktemp)
  THREAD_RES=$(/usr/local/bin/node scripts/post-comment.js "$THREAD_TEXT_B64" "$MAIN_URL" 2>"$ERR_TMP2")
  if [ -s "$ERR_TMP2" ]; then cat "$ERR_TMP2" >&2; fi
  rm -f "$ERR_TMP2"
  echo "[run-publish] thread reply: $THREAD_RES" >&2
fi

/usr/local/bin/node -e "
let main;
try {
  const raw = process.env.MAIN_RES || '';
  // 2026-07-19: log line が stdout 混入する場合対策 — LAST line で { で始まる ものを parse
  const lines = raw.split(/\r?\n/).filter(x => x.trim().startsWith('{'));
  const jsonLine = lines.length > 0 ? lines[lines.length - 1] : raw;
```
## 2. post-via-playwright.js の全体（行番号つき）
```
     1	#!/usr/bin/env node
     2	/**
     3	 * post-via-playwright.js v3 (2026-05-15: GraphQL response 捕捉、main post の tweet_id 確実取得)
     4	 * Args: <text-base64> [<image-path>]
     5	 * Output: {ok, tweet_id?, url?, error?, step?, image_attached?, captured_via?}
     6	 */
     7	const { chromium } = require("playwright-core");
     8	const fs = require("fs");
     9	
    10	const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
    11	const X_PROFILE_USERNAME = "heng_ji31590";
    12	const COMPOSE_URL = "https://x.com/compose/post";
    13	const TIMELINE_URL = `https://x.com/${X_PROFILE_USERNAME}`;
    14	
    15	function out(obj) { console.log(JSON.stringify(obj)); }
    16	
    17	// 2026-06-12: 文字化け投稿事故対策 — base64 decode + UTF-8 + 文字列 strict validation
    18	const { decodeBase64Safe, weightedLength } = require("./lib/text-safety");
    19	
    20	async function main() {
    21	  const arg = process.argv[2];
    22	  if (!arg) { out({ ok: false, error: "missing text arg (base64)" }); process.exit(1); }
    23	  const decoded = decodeBase64Safe(arg);
    24	  if (!decoded.ok) {
    25	    out({ ok: false, step: "text-safety", error: "decode/validation failed", reason: decoded.reason, details: decoded.details });
    26	    process.exit(1);
    27	  }
    28	  const text = decoded.text;
    29	  // 2026-05-21: multi-image support — accept comma-separated list, X allows up to 4 images
    30	  const imagePathArg = process.argv[3] || null;
    31	  const imagePaths = (imagePathArg && imagePathArg !== "null") ? imagePathArg.split(",").map(p => p.trim()).filter(Boolean) : [];
    32	  const imagePath = imagePaths[0] || null;  // backward compat
    33	  // 2026-05-20: CHAR_ONLY guard — bare-character images rejected by user (low quality)
    34	  const isCharOnly = imagePaths.some(p => p.includes("/character-library/"));
    35	  if (isCharOnly) { console.warn("[post-via-playwright] CHAR_ONLY image refused:", imagePaths.find(p => p.includes("/character-library/"))); }
    36	  const hasImage = imagePaths.length > 0 && !isCharOnly && imagePaths.every(p => fs.existsSync(p));
    37	  if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }
    38	
    39	  let browser, context, page;
    40	  let step = "connect";
    41	  try {
    42	    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
    43	    const contexts = browser.contexts();
    44	    if (contexts.length === 0) { out({ ok: false, step, error: "no contexts" }); process.exit(1); }
    45	    context = contexts[0];
    46	    page = await context.newPage();
    47	    // 2026-05-31 fix: dialog 自動 dismiss (notification permission 等で Playwright が死ぬ問題回避)
    48	    page.on("dialog", d => { d.dismiss().catch(() => {}); });
    49	
    50	    step = "navigate-compose";
    51	    await page.goto(COMPOSE_URL, { waitUntil: "domcontentloaded", timeout: 30000 });
    52	
    53	    step = "wait-textarea";
    54	    // 2026-07-06: X UI render 遅延で 20s timeout 発生 → 5s pre-wait + 30s に緩和 (post-comment.js と同様)
    55	    await page.waitForTimeout(5000);
    56	    const textareaSelector = 'div[data-testid^="tweetTextarea_"][contenteditable="true"]';
    57	    await page.waitForSelector(textareaSelector, { timeout: 30000 });
    58	
    59	    step = "focus-and-type";
    60	    const ta = await page.$(textareaSelector);
    61	    await ta.click();
    62	    await page.keyboard.insertText(text);
    63	    await page.waitForTimeout(800);
    64	
    65	    let imageAttached = false;
    66	    if (hasImage) {
    67	      step = "attach-image";
    68	      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
    69	      if (!fileInput) fileInput = await page.$('input[type="file"]');
    70	      if (!fileInput) throw new Error("file input not found on compose page");
    71	      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
    72	      step = "wait-image-upload";
    73	
    74	      // 2026-08-09 修正: 旧実装は role="progressbar" が 0 になるのを完了条件にしていたが、
    75	      // これは X の「文字数カウンターの円形インジケータ」で常時 3 個存在する。
    76	      // よって条件は永遠に成立せず、.catch() で握り潰されたままアップロード途中で送信され、
    77	      // 画像が 1 枚も付かないまま投稿されていた (画像つき投稿がほぼ毎回これで失敗)。
    78	      // 正しい完了サインは「添付プレビューの画像枚数」と「各画像の削除ボタン数」。
    79	      const want = imagePaths.length;
    80	      let attachedCount = 0;
    81	      for (let i = 0; i < 45; i++) {
    82	        attachedCount = await page.evaluate(() => {
    83	          const box = document.querySelector('[data-testid="attachments"]');
    84	          if (!box) return 0;
    85	          const imgs = box.querySelectorAll("img").length;
    86	          const removes = document.querySelectorAll('[aria-label*="削除"], [data-testid="removeMedia"]').length;
    87	          // プレビューと削除ボタンが揃って初めて「その枚数はアップロード済み」と見なせる
    88	          return Math.min(imgs, removes || imgs);
    89	        });
    90	        if (attachedCount >= want) break;
    91	        await page.waitForTimeout(2000);
    92	      }
    93	      if (attachedCount < want) {
    94	        await page.close(); await browser.close();
    95	        out({ ok: false, step, error: "画像のアップロードが完了しないため投稿を中止しました",
    96	              images_expected: want, images_attached: attachedCount });
    97	        process.exit(1);
    98	      }
    99	      console.error(`[post-via-playwright] attached ${attachedCount}/${want} image(s)`);
   100	      await page.waitForTimeout(1500);
   101	      imageAttached = true;
   102	
   103	      // 2026-10-11 x264: 画像の説明（ALT）。ALT_TEXTS_FILE（JSON 配列）があれば、i 枚目に alts[i] を入れる（空ならその画像は飛ばす）。
   104	      // CC BY / CC BY-SA の撮影者名を ALT に書く運用（CLAUDE.md 最上位ルール 8）。**入れられなければ投稿しない**（throw → 投稿ボタンを押さない）。
   105	      // 画面の作りは x263 で実物を読んだ: 添付ごとの [data-testid="altTextWrapper"] → 編集画面の textarea → [data-testid="endEditingButton"]
   106	      if (process.env.ALT_TEXTS_FILE) {
   107	        step = "alt-text";
   108	        const alts = JSON.parse(fs.readFileSync(process.env.ALT_TEXTS_FILE, "utf8"));
   109	        for (let i = 0; i < alts.length; i++) {
   110	          if (!alts[i]) continue;
   111	          // 2026-10-11 x265: 複数枚を添付すると altTextWrapper は 1 個にまとまる（x264 で実測）。
   112	          // そのときは押して編集画面を開き「次へ」で i 枚目まで送る。**送った先が i 枚目かを画像の src で確かめる**。確かめられなければ投稿しない
   113	          const thumbs = await page.$$eval('[data-testid="attachments"] img', (xs) => xs.map((x) => x.getAttribute("src") || ""));
   114	          const wrappers = page.locator('[data-testid="attachments"] [data-testid="altTextWrapper"]');
   115	          const n = await wrappers.count();
   116	          if (n === 0) throw new Error("altTextWrapper が無い");
   117	          await wrappers.nth(n > i ? i : 0).click();
   118	          await page.waitForTimeout(2500);
   119	          const curIndex = async () => {
   120	            const srcs = await page.$$eval('[role="dialog"] img', (xs) => xs.filter((x) => x.offsetWidth > 120 && x.offsetHeight > 120).map((x) => x.getAttribute("src") || ""));
   121	            for (const sv of srcs) { const k = thumbs.indexOf(sv); if (k >= 0) return k; }
   122	            return -1;
   123	          };
   124	          let at = await curIndex();
   125	          for (let guard = 0; at !== i && guard < 4; guard++) {
   126	            const nx = page.locator('[role="dialog"]:has([data-testid="endEditingButton"]) button[aria-label="次へ"]').last();
   127	            if (!(await nx.count())) break;
   128	            await nx.click(); await page.waitForTimeout(1500);
   129	            at = await curIndex();
   130	          }
   131	          if (at !== i) {
   132	            const dbg = await page.$$eval('[role="dialog"] img', (xs) => xs.map((x) => (x.getAttribute("src") || "").slice(0, 60) + " " + x.offsetWidth + "x" + x.offsetHeight));
   133	            throw new Error("編集画面で " + (i + 1) + " 枚目を特定できない（at=" + at + "） thumbs=" + JSON.stringify(thumbs.map((t) => t.slice(0, 60))) + " dialog_imgs=" + JSON.stringify(dbg));
   134	          }
   135	          let box = page.locator('[role="dialog"] textarea').first();
   136	          if (!(await box.count())) {
   137	            await page.locator('[role="dialog"] a[aria-label="画像の説明を編集"]').first().click().catch(() => {});
   138	            await page.waitForTimeout(1500);
   139	            box = page.locator('[role="dialog"] textarea').first();
   140	          }
   141	          if (!(await box.count())) throw new Error("ALT の入力欄が見つからない（" + (i + 1) + " 枚目）");
   142	          await box.fill(alts[i]);
   143	          await page.waitForTimeout(500);
   144	          const got = await box.inputValue();
   145	          if (got.replace(/\s/g, "") !== String(alts[i]).replace(/\s/g, "")) throw new Error("ALT が入りきらない（" + (i + 1) + " 枚目） got_len=" + got.length + " want_len=" + alts[i].length);
   146	          const save = page.locator('[role="dialog"] [data-testid="endEditingButton"]').first();
   147	          if (!(await save.count())) throw new Error("ALT の保存ボタンが無い");
   148	          await save.click();
   149	          await page.waitForTimeout(1500);
   150	          console.error("[post-via-playwright] alt set for image " + (i + 1) + " (" + got.length + " chars)");
   151	        }
   152	      }
   153	    }
   154	
   155	    // 2026-05-15 v3: arm GraphQL response listener BEFORE submit
   156	    step = "arm-response-listener";
   157	    const responsePromise = page.waitForResponse(
   158	      (resp) => /\/(CreateTweet|CreateNoteTweet|create_tweet)/i.test(resp.url()) && resp.request().method() === "POST",
   159	      { timeout: 30000 }
   160	    ).catch(() => null);
   161	
   162	    // 2026-08-07: 送信は Meta+Enter だが、X 側が投稿を受け付けない状態
   163	    // (文字数超過・画像処理中など) だとボタンが aria-disabled のままで、キーを押しても
   164	    // 何も起きない。従来はそれを検知せず後段の fallback が別ツイートの ID を拾って
   165	    // 成功扱いにしていた。押す前に必ず投稿可能かを確認する。
   166	    step = "verify-submittable";
   167	    const submittable = await page.evaluate(() => {
   168	      const btn = document.querySelector('[data-testid="tweetButton"]')
   169	               || document.querySelector('[data-testid="tweetButtonInline"]');
   170	      if (!btn) return { ok: false, reason: "post_button_not_found" };
   171	      if (btn.getAttribute("aria-disabled") === "true") return { ok: false, reason: "post_button_disabled" };
   172	      return { ok: true };
   173	    });
   174	    if (!submittable.ok) {
   175	      await page.close(); await browser.close();
   176	      out({ ok: false, step, error: "X refused to enable the post button — nothing was posted",
   177	            reason: submittable.reason, weighted_length: weightedLength(text), image_attached: imageAttached });
   178	      process.exit(1);
   179	    }
   180	
   181	    step = "submit-via-keyboard";
   182	    // 2026-08-09: 画像を添付するとコンポーザーが再描画され、最初に取得した
   183	    // ElementHandle が DOM から外れる ("Element is not attached to the DOM")。
   184	    // 画像つき投稿が毎回ここで落ちていたので、送信直前に取り直す。
   185	    await page.locator(textareaSelector).first().click({ timeout: 10000 }).catch(async () => {
   186	      await page.locator(textareaSelector).first().focus().catch(() => {});
   187	    });
   188	    await page.waitForTimeout(300);
   189	    await page.keyboard.press("Meta+Enter");
   190	
   191	    step = "wait-response-or-confirm";
   192	    const response = await responsePromise;
   193	    let capturedTweetId = null;
   194	    let capturedVia = null;
   195	    if (response) {
   196	      try {
   197	        const json = await response.json();
   198	        capturedTweetId = json?.data?.create_tweet?.tweet_results?.result?.rest_id
   199	                       || json?.data?.notetweet_create?.tweet_results?.result?.rest_id
   200	                       || json?.data?.tweet?.rest_id
   201	                       || null;
   202	        if (capturedTweetId) capturedVia = "graphql_response";
   203	      } catch (e) { /* ignore */ }
   204	    }
   205	
   206	    step = "wait-textarea-clear";
   207	    await page.waitForFunction(() => {
   208	      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
   209	      return !ta || ta.textContent.trim() === "";
   210	    }, { timeout: 15000 }).catch(() => null);
   211	    await page.waitForTimeout(2500);
   212	
   213	    // Fallback: scrape /username with pinned skip
   214	    // 2026-08-07 修正: 旧実装は「タイムライン先頭の非固定ツイート」を無条件に採用していた。
   215	    // そのため投稿が失敗していても直近の無関係なツイート ID を掴んで ok:true を返し、
   216	    // 呼び出し側 (run-publish.sh) がその URL を親として後続の返信をぶら下げ、
   217	    // 他人のツイート配下へ誤爆した。本文の一致を必ず確認してから採用する。
   218	    if (!capturedTweetId) {
   219	      step = "fallback-scrape";
   220	      await page.goto(TIMELINE_URL, { waitUntil: "domcontentloaded", timeout: 30000 });
   221	      await page.waitForTimeout(2500);
   222	      // 記号や空白の差で外さないよう、本文先頭を正規化した部分列で突き合わせる
   223	      const needle = text.replace(/\s+/g, "").slice(0, 18);
   224	      const tweetUrl = await page.$$eval(
   225	        'article',
   226	        (articles, args) => {
   227	          const { username, needle } = args;
   228	          for (const article of articles) {
   229	            const socialContext = article.querySelector('[data-testid="socialContext"]');
   230	            if (socialContext && /固定|Pinned/i.test(socialContext.textContent || "")) continue;
   231	            const body = (article.innerText || "").replace(/\s+/g, "");
   232	            if (needle && !body.includes(needle)) continue;   // 本文が一致しないものは採用しない
   233	            const links = article.querySelectorAll('a[href*="/status/"]');
   234	            for (const a of links) {
   235	              const m = a.getAttribute("href").match(new RegExp(`/${username}/status/(\\d+)`, "i"));
   236	              if (m) return m[1];
   237	            }
   238	          }
   239	          return null;
   240	        },
   241	        { username: X_PROFILE_USERNAME, needle }
   242	      );
   243	      if (tweetUrl) { capturedTweetId = tweetUrl; capturedVia = "scrape_fallback_verified"; }
   244	    }
   245	
   246	    await page.close();
   247	    await browser.close();
   248	
   249	    if (!capturedTweetId) {
   250	      out({ ok: false, step, error: "tweet posted but couldn't capture tweet ID (graphql + scrape both failed)", image_attached: imageAttached });
   251	      process.exit(1);
   252	    }
   253	    // 2026-06-12: 投稿成功後 30s 内に文字化け watchdog を背景 spawn
   254	    try {
   255	      const { spawn } = require("child_process");
   256	      const watchdog = spawn("/usr/local/bin/node", [require("path").join(__dirname, "post-publish-watchdog.js"), capturedTweetId], {
   257	        detached: true, stdio: "ignore", env: process.env,
   258	      });
   259	      watchdog.unref();
   260	    } catch (e) { /* watchdog spawn failure must not break main return */ }
```
## 3. 予約ジョブの出力ファイル（stderr 側）
```
==> /Users/ny/.openclaw/workspace/logs/publish-hanabi-oneshot-out.log <==

==> /Users/ny/.openclaw/workspace/logs/publish-hanabi-oneshot-err.log <==
```
## 4. text-safety の上限まわり（長文で何かを切っていないか）
```
```
**読んだだけ。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
