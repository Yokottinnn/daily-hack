# 12:00 の告知が落ちた理由（2026-10-18 12:17:50 JST・読むだけ・$0）

## 1. post-via-playwright.js の長さ・上限の扱い

```
       276 /Users/ny/.openclaw/workspace/scripts/post-via-playwright.js
18:const { decodeBase64Safe, weightedLength } = require("./lib/text-safety");
36:  const hasImage = imagePaths.length > 0 && !isCharOnly && imagePaths.every(p => fs.existsSync(p));
37:  if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }
44:    if (contexts.length === 0) { out({ ok: false, step, error: "no contexts" }); process.exit(1); }
71:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
79:      const want = imagePaths.length;
85:          const imgs = box.querySelectorAll("img").length;
86:          const removes = document.querySelectorAll('[aria-label*="削除"], [data-testid="removeMedia"]').length;
109:        for (let i = 0; i < alts.length; i++) {
145:          if (got.replace(/\s/g, "") !== String(alts[i]).replace(/\s/g, "")) throw new Error("ALT が入りきらない（" + (i + 1) + " 枚目） got_len=" + got.length + " want_len=" + alts[i].length);
150:          console.error("[post-via-playwright] alt set for image " + (i + 1) + " (" + got.length + " chars)");
177:            reason: submittable.reason, weighted_length: weightedLength(text), image_attached: imageAttached });
```

## 2. 失敗時に出す step の一覧

```
22:ok: false, error: "missing text arg (base64
25:ok: false, step: "text-safety", error: "decode/validation failed", reason: decoded.reason, details: decoded.details }
40:step = "connect"
44:ok: false, step, error: "no contexts" }
50:step = "navigate-compose"
53:step = "wait-textarea"
59:step = "focus-and-type"
67:step = "attach-image"
72:step = "wait-image-upload"
95:ok: false, step, error: "画像のアップロードが完了しないため投稿を中止しました",
107:step = "alt-text"
156:step = "arm-response-listener"
166:step = "verify-submittable"
170:ok: false, reason: "post_button_not_found" };
171:ok: false, reason: "post_button_disabled" };
176:ok: false, step, error: "X refused to enable the post button — nothing was posted",
181:step = "submit-via-keyboard"
191:step = "wait-response-or-confirm"
206:step = "wait-textarea-clear"
219:step = "fallback-scrape"
250:ok: false, step, error: "tweet posted but couldn't capture tweet ID (graphql + scrape both failed
271:ok: false, step, error: err.message }
```

## 3. 冒頭 60 行（引数の受け取りと、最初の検査）

```
#!/usr/bin/env node
/**
 * post-via-playwright.js v3 (2026-05-15: GraphQL response 捕捉、main post の tweet_id 確実取得)
 * Args: <text-base64> [<image-path>]
 * Output: {ok, tweet_id?, url?, error?, step?, image_attached?, captured_via?}
 */
const { chromium } = require("playwright-core");
const fs = require("fs");

const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const X_PROFILE_USERNAME = "heng_ji31590";
const COMPOSE_URL = "https://x.com/compose/post";
const TIMELINE_URL = `https://x.com/${X_PROFILE_USERNAME}`;

function out(obj) { console.log(JSON.stringify(obj)); }

// 2026-06-12: 文字化け投稿事故対策 — base64 decode + UTF-8 + 文字列 strict validation
const { decodeBase64Safe, weightedLength } = require("./lib/text-safety");

async function main() {
  const arg = process.argv[2];
  if (!arg) { out({ ok: false, error: "missing text arg (base64)" }); process.exit(1); }
  const decoded = decodeBase64Safe(arg);
  if (!decoded.ok) {
    out({ ok: false, step: "text-safety", error: "decode/validation failed", reason: decoded.reason, details: decoded.details });
    process.exit(1);
  }
  const text = decoded.text;
  // 2026-05-21: multi-image support — accept comma-separated list, X allows up to 4 images
  const imagePathArg = process.argv[3] || null;
  const imagePaths = (imagePathArg && imagePathArg !== "null") ? imagePathArg.split(",").map(p => p.trim()).filter(Boolean) : [];
  const imagePath = imagePaths[0] || null;  // backward compat
  // 2026-05-20: CHAR_ONLY guard — bare-character images rejected by user (low quality)
  const isCharOnly = imagePaths.some(p => p.includes("/character-library/"));
  if (isCharOnly) { console.warn("[post-via-playwright] CHAR_ONLY image refused:", imagePaths.find(p => p.includes("/character-library/"))); }
  const hasImage = imagePaths.length > 0 && !isCharOnly && imagePaths.every(p => fs.existsSync(p));
  if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }

  let browser, context, page;
  let step = "connect";
  try {
    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
    const contexts = browser.contexts();
    if (contexts.length === 0) { out({ ok: false, step, error: "no contexts" }); process.exit(1); }
    context = contexts[0];
    page = await context.newPage();
    // 2026-05-31 fix: dialog 自動 dismiss (notification permission 等で Playwright が死ぬ問題回避)
    page.on("dialog", d => { d.dismiss().catch(() => {}); });

    step = "navigate-compose";
    await page.goto(COMPOSE_URL, { waitUntil: "domcontentloaded", timeout: 30000 });

    step = "wait-textarea";
    // 2026-07-06: X UI render 遅延で 20s timeout 発生 → 5s pre-wait + 30s に緩和 (post-comment.js と同様)
    await page.waitForTimeout(5000);
    const textareaSelector = 'div[data-testid^="tweetTextarea_"][contenteditable="true"]';
    await page.waitForSelector(textareaSelector, { timeout: 30000 });

    step = "focus-and-type";
    const ta = await page.$(textareaSelector);
```

## 4. run-publish.sh の thread-main-exec まわり

```
8:#   - 1個目 = main post (post-via-playwright)
82:const { execSync } = require('child_process');
104:        ? \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\" \"\${imagePath}\"\`
105:        : \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\"\`;
107:        const out = execSync(cmd, { encoding: 'utf8' });
114:        console.log(JSON.stringify({ ok: false, step: 'thread-main-exec', error: e.message, child_stdout: String(e.stdout || '').slice(-700), child_stderr: String(e.stderr || '').slice(-700), thread_results: results 
124:        const out = execSync(cmd, { encoding: 'utf8' });
172:  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" "$IMAGE_PATH" 2>"$ERR_TMP")
174:  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" 2>"$ERR_TMP")
```

## 5. CDP

```
{"ok":true,"healthy":true,"round_trip_ms":4043,"product":"Chrome/140.0.7339.207","tabs":12}
```

**投稿していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
