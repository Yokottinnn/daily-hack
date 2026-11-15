# 落ちたことに気づく番人を入れる（2026-09-27 17:03 JST・$0）

**このレポートが作られた時刻: 2026-09-27 17:03:29 JST**

> **投稿しない。キューも触らない。** 番人は LLM を呼ばない（$0／回・$0／日・$0／月）。

## 1. 置く前の確認

```
  既に在るか: 無い（新規）
  書いたもの: 7503 bytes / 177 行
  一時ファイル名: .thread-guard-install-20260927-170329.js
```

**`node --check` を、置く名前と同じ拡張子で通す**（`x163` の教訓）。

```
  rc=0
```
```
  置いた: thread-guard.js（177 行）
```

## 2. まず DRY で 1 回（**鳴るか・鳴りすぎないか**）

**Slack へは出さない。** 何件 引っかかるかだけ見る。

```
  [thread-guard] DRY なので Slack へ出さない: 🚨 *予約投稿が出ていない*
  • id: `blog-promo-20260603-budget-gym-cost-per-visit-2026`
  • status: `skipped_expired_ttl_7d`（`posted` に
  [thread-guard]   B 通知: blog-promo-20260603-cheap-sim-speed-cost-2026 143103 分 遅れ
  [thread-guard] DRY なので Slack へ出さない: 🚨 *予約投稿が出ていない*
  • id: `blog-promo-20260603-cheap-sim-speed-cost-2026`
  • status: `skipped_expired_ttl_7d`（`posted` になっていな
  [thread-guard]   B 通知: blog-promo-20260603-money-hacks-hourly-wage-2026 141663 分 遅れ
  [thread-guard] DRY なので Slack へ出さない: 🚨 *予約投稿が出ていない*
  • id: `blog-promo-20260603-money-hacks-hourly-wage-2026`
  • status: `skipped_expired_ttl_7d`（`posted` になっ
  [thread-guard]   B 通知: blog-promo-20260603-video-subscription-cost-per-vi 140223 分 遅れ
  [thread-guard] DRY なので Slack へ出さない: 🚨 *予約投稿が出ていない*
  • id: `blog-promo-20260603-video-subscription-cost-per-vi`
  • status: `skipped_expired_ttl_7d`（`posted` に
  [thread-guard]   B 通知: blog-promo-20260921-tokyo-discount-supermarket-2026 8645 分 遅れ
  [thread-guard] DRY なので Slack へ出さない: 🚨 *予約投稿が出ていない*
  • id: `blog-promo-20260921-tokyo-discount-supermarket-2026`
  • status: `deleted_by_user`（`posted` になっていない
  [thread-guard]   B 通知: blog-promo-20260927-payid-a 303 分 遅れ
  [thread-guard] DRY なので Slack へ出さない: 🚨 *予約投稿が出ていない*
  • id: `blog-promo-20260927-payid-a`
  • status: `awaiting_approval`（`posted` になっていない）
  • 出るはずだった時刻: 2026-09
  [thread-guard]   A 通知: thread-reply-1-exec
  [thread-guard] DRY なので Slack へ出さない: 🚨 *スレッドの投稿が途中で落ちた*
  • ログ: `publish-payid-oneshot.log`
  • step: `thread-reply-1-exec`
  • error: ```Command failed: /usr/loc
  {"ok":true,"at":"2026-09-27 17:03:29","dry":true,"a_count":1,"b_count":14,"notified":["B:blog-promo-20260515-qr-payment-comparison-2026","B:blog-promo-20260516-cheap-sim-comparison-2026","B:blog-promo-20260516-fixed-cost
```

## 3. 本番で 1 回（**実際に Slack へ出す**）

**いま壊れているものが在れば、ここで鳴る。** 無ければ静かに終わる。

```
  [thread-guard] A（ログの ok:false / thread 系）: 1 件
  [thread-guard] B（出る時刻を過ぎても posted でない）: 14 件
  [thread-guard]   B 既報: blog-promo-20260515-qr-payment-comparison-2026
  [thread-guard]   B 既報: blog-promo-20260516-cheap-sim-comparison-2026
  [thread-guard]   B 既報: blog-promo-20260516-fixed-cost-reduction-guide-202
  [thread-guard]   B 既報: blog-promo-20260516-jre-bank-campaign-2026
  [thread-guard]   B 既報: blog-promo-20260516-june-2026-campaigns-roundup
  [thread-guard]   B 既報: blog-promo-20260516-nisa-investment-beginner-guide
  [thread-guard]   B 既報: blog-promo-20260530-matsuya-60th-cashless-2026-jun
  [thread-guard]   B 既報: blog-promo-20260602-gyudon-chains-cashless-2026-ju
  [thread-guard]   B 既報: blog-promo-20260603-budget-gym-cost-per-visit-2026
  [thread-guard]   B 既報: blog-promo-20260603-cheap-sim-speed-cost-2026
  [thread-guard]   B 既報: blog-promo-20260603-money-hacks-hourly-wage-2026
  [thread-guard]   B 既報: blog-promo-20260603-video-subscription-cost-per-vi
  [thread-guard]   B 既報: blog-promo-20260921-tokyo-discount-supermarket-2026
  [thread-guard]   B 既報: blog-promo-20260927-payid-a
  [thread-guard]   A 既報: thread-reply-1-exec
  {"ok":true,"at":"2026-09-27 17:03:29","dry":false,"a_count":1,"b_count":14,"notified":[]}
```

## 4. 30 分ごとの plist を置いて載せる

```
  bootstrap rc=0 
  （**2 回目が rc=5 なら「もう載っている」の出方**。消えた証拠ではない）

  --- 載ったかの証拠（`list | grep` では足りない）---
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.thread-guard.plist
    	state = not running
    	program = /usr/local/bin/node
    	runs = 0
    	last exit code = (never exited)
    → **載っている**
```

## 5. `post-comment.js` の stderr が落ちていない箇所（**次に直す材料**）

12:00 の失敗は `Command failed: node scripts/post-comment.js "<base64>"` だけで、
**本当のエラーが記録されていない。** どこで捨てているかを写す。

```javascript
  ===== auto-reply.js（211 行・post-comment.js が 5 箇所）=====
    57- * 2026-05-18 確立: kind=comment (リプライ) は user 承認不要、即時 X 投稿 + Slack 報告のみ。
    58- * 関連 memory: feedback_immediate_post_on_approval.md 「🟩 reply/comment: 承認不要・自動投稿」
    59- * 2026-05-19 fix: stderr キャプチャ + リトライ(最大2回, 10s待機) 追加
    60- *
    61- * Flow:
    62- *   1. queue.json から entry 取得
    63: *   2. post-comment.js で即時 Playwright 投稿 (失敗時は最大2回リトライ)
    64- *   3. queue.json 更新 (status=posted, x_tweet_id, posted_at)
    65- *   4. Slack に「✅ リプライ自動投稿 完了」 報告 (承認要求ではない)
    66- */
    67-const fs = require("fs");
    68-const https = require("https");
    69-const { execSync } = require("child_process");
    70-
    71-const WS = "/Users/ny/.openclaw/workspace";
    72-const QUEUE = `${WS}/data/post_queue.json`;
    73:const POST_COMMENT = `${WS}/scripts/post-comment.js`;
    74-const ENSURE_CHROME = `${WS}/scripts/ensure-chrome.sh`;
    75-const SLACK_CHANNEL = "C0A5FKU7T5M";
    76-const OWNER_USER_ID = "U0A5V22PVTQ";
    77-
    78-const MAX_RETRIES = 2;
    79-const RETRY_WAIT_MS = 10000;
    80-
    81-const id = process.argv[2];
    82-if (!id) { console.error("usage: auto-reply.js <entry-id>"); process.exit(1); }
    83-if (!process.env.SLACK_BOT_TOKEN) { console.error("missing SLACK_BOT_TOKEN env"); process.exit(1); }
    84-
    85-function slackPost(text) {
    86-  // 2026-07-25 migrated: silent_slack.json kind-based routing via slack-notify.js
    87-  try {
    --
    99-  if (!entry.text || !entry.target_url) { console.error("missing text/target_url"); process.exit(3); }
    100-
    101-  // Ensure Chrome up
    102-  try { execSync(`bash ${ENSURE_CHROME}`, { stdio: "ignore" }); }
    103-  catch (e) { console.error("Chrome ensure failed:", e.message); process.exit(4); }
    104-
    105:  // Step 1: Post via post-comment.js (リトライ最大2回、10s間隔)
    106-  const textB64 = Buffer.from(entry.text, "utf8").toString("base64");
    107-  let postRes = null;
    108-  let lastStderr = "";
    109-
    110-  for (let attempt = 1; attempt <= MAX_RETRIES + 1; attempt++) {
    111-    try {
    112-      const stdout = execSync(
    113-        `/usr/local/bin/node ${POST_COMMENT} ${JSON.stringify(textB64)} ${JSON.stringify(entry.target_url)}`,
    114-        { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }
    115-      );
    116-      postRes = JSON.parse(stdout.trim());
    117-    } catch (e) {
    118-      // e.stdout: 正常出力, e.stderr: エラー詳細 (Playwright stacktrace 等)
    119-      const stderrText = (e.stderr || "").toString().trim();
    --
    145-
    146-  if (!postRes || !postRes.ok) {
    147-    const stderrInfo = lastStderr ? `\nstderr: ${lastStderr.slice(0, 400)}` : "";
    148-    // 2026-07-20 Layer 3: reply-linkage-lost 専用 handling + 5-fail auto halt
    149-    const isLinkageLost = postRes && postRes.step === "reply-linkage-lost";
    150-    if (isLinkageLost) {

  ===== follow-up-reply.js（88 行・post-comment.js が 2 箇所）=====
    1-#!/usr/bin/env node
    2-// follow-up-reply.js — Post a self-reply 30min after main post (algorithm boost)
    3-// Cron: every 5min
    4-// Logic:
    5-//   - Find queue entries posted 28-35min ago, without follow_up_posted_at
    6-//   - Use entry.follow_up_text if present, else random fallback (5種ローテ)
    7://   - Post via post-comment.js with target_url = entry.posted_url
    8-//   - Update queue with follow_up_posted_at + follow_up_url
    9-const fs = require("fs");
    10-const { execSync } = require("child_process");
    11-
    12-const QUEUE_PATH = "/Users/ny/.openclaw/workspace/data/post_queue.json";
    13:const POST_COMMENT_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/post-comment.js";
    14-const LOG_PATH = "/Users/ny/.openclaw/workspace/logs/follow-up-reply.log";
    15-
    16-// 5種フォールバック (アタシ口調、エンゲージメント誘発)
    17-const FALLBACKS = [
    18-  "📌 損したくないなら保存しときなさい😉",
    19-  "💡 アタシのフォローしとくと損しないわよ😏",
    20-  "🔥 役に立ったらRTお願い、知らない人多すぎる💢",
    21-  "✨ 続きはアタシのプロフィールから (ブログのリンクあるわ)",
    22-  "📚 こういう情報、もっと知りたかったらフォローしてね😉",
    23-];
    24-
    25-function log(s) {
    26-  const line = `[${new Date().toISOString()}] ${s}\n`;
    27-  try { fs.appendFileSync(LOG_PATH, line); } catch {}

  ===== incoming-reply-responder.js（372 行・post-comment.js が 2 箇所）=====
    211-  }
    212-  return null;
    213-}
    214-
    215-async function postReply(text, targetUrl) {
    216-  const b64 = Buffer.from(text, "utf8").toString("base64");
    217:  const r = spawnSync("/usr/local/bin/node", [`${WS}/scripts/post-comment.js`, b64, targetUrl], { encoding: "utf8", timeout: 150000 });
    218-  try {
    219-    const o = JSON.parse(r.stdout.trim().split("\n").pop());
    220-    return o;
    221-  } catch {
    222-    console.error("[post-parse-fail] stdout(-500)=" + (r.stdout||"").slice(-500) + " | stderr(-200)=" + (r.stderr||"").slice(-200) + " | signal=" + r.signal + " | error=" + (r.error && r.error.mes
    223-    return { ok: false, error: "parse fail", stdout: r.stdout?.slice(-200) };
    224-  }
    225-}
    226-
    227-async function main() {
    228-  const browser = await chromium.connectOverCDP(CDP_URL, { timeout: 60000 });
    229-  const ctx = browser.contexts()[0];
    230-  const page = await ctx.newPage();
    231-
    --
    290-          muted_reason: "attack",
    291-        };
    292-      }
    293-      action = `react-only-${reason}`;
    294-      result.actions.push({ id: m.tweet_id, author: m.author, action, like: likeNote });
    295-    } else if (process.env.SKIP_POST === "1" || process.env.REACT_ONLY_MODE === "1") {
    296:      // 2026-07-19: post-comment.js の concurrent Chrome hang 対策で 一時 skip、 ❤️ のみに降格
    297-      handled.handled[m.tweet_id] = { action: "react-only-postskipped", at: new Date().toISOString(), chain: ourReplyId, note: "SKIP_POST env" };
    298-      action = "react-only-postskipped";
    299-      result.actions.push({ id: m.tweet_id, author: m.author, action, like: likeNote });
    300-      actionsThisFire++;
    301-      saveHandled(handled);
    302-      await page.waitForTimeout(2000);
    303-      continue;
    304-    } else {
    305-      // 通常 → 返信生成 + 投稿
    306-      replyText = await generateReplyText(m.text);
    307-      if (!replyText) {
    308-        result.fail++;
    309-        handled.handled[m.tweet_id] = { action: "react-only-genfail", at: new Date().toISOString(), chain: ourReplyId };
    310-        result.actions.push({ id: m.tweet_id, author: m.author, action: "react-only-genfail", like: likeNote });

  ===== incoming-reply-watcher.js（270 行・post-comment.js が 3 箇所）=====
    1-#!/usr/bin/env node
    2-// incoming-reply-watcher.js v2 (2026-05-17: Haiku auto-reply 追加、+75 weight 回収)
    3-// Cron: every 15min
    4:// Flow: new reply 検知 → Haiku generate アタシ口調返信 → post-comment.js で投稿 → Slack通知
    5-const { chromium } = require("playwright-core");
    6-const fs = require("fs");
    7-const https = require("https");
    8-const { execSync } = require("child_process");
    9-const ant = require("./anthropic-client.js");
    10-
    11-const QUEUE_PATH = "/Users/ny/.openclaw/workspace/data/post_queue.json";
    12-const STATE_PATH = "/Users/ny/.openclaw/workspace/data/incoming-reply-state.json";
    13-const LOG_PATH = "/Users/ny/.openclaw/workspace/logs/incoming-reply-watcher.log";
    14:const POST_COMMENT_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/post-comment.js";
    15-const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
    16-const X_USERNAME = "heng_ji31590";
    17-const SLACK_TOKEN = JSON.parse(fs.readFileSync("/Users/ny/.openclaw/openclaw.json", "utf8")).channels.slack.botToken;
    18-const SLACK_CHANNEL = "C0A5FKU7T5M";
    19-const OWNER_USER_ID = "U0A5V22PVTQ";
    20-const HAIKU_MODEL = "claude-haiku-4-5";
    21-const DAILY_AUTO_REPLY_CAP = 20;
    22-
    23-function log(s) { try { fs.appendFileSync(LOG_PATH, `[${new Date().toISOString()}] ${s}\n`); } catch {}; console.log(s); }
    24-
    25-function slackPost(text) {
    26-  // 2026-07-25 migrated: silent_slack.json kind-based routing via slack-notify.js
    27-  try {
    28-    const nx = require("./lib/slack-notify.js");
    --
    182-    let replyData;
    183-    try { replyData = await generateAutoReply(r.to_post_text, r); }
    184-    catch (e) { log(`    Haiku error: ${e.message}`); continue; }
    185-    if (!replyData) { log(`    Haiku gen failed`); continue; }
    186-    log(`    generated [${replyData.pattern}]: "${replyData.reply}"`);
    187-
    188:    // Post via post-comment.js (target = the incoming reply's URL)
    189-    try {
    190-      const textB64 = Buffer.from(replyData.reply, "utf8").toString("base64");
    191-      const out = execSync(`/usr/local/bin/node ${POST_COMMENT_SCRIPT} "${textB64}" "${r.reply_url}" 2>&1`, { encoding: "utf8", maxBuffer: 8*1024*1024 });
    192-      const result = JSON.parse(out.trim().split("\n").pop());
    193-      if (result.ok) {
    194-        log(`    ✅ posted: ${result.url}`);
    195-        postedCount++;
    196-        state.auto_replies.push({
    197-          incoming_reply_id: r.reply_id,
    198-          incoming_reply_author: r.author,
    199-          to_post_id: r.to_post_id,
    200-          auto_reply_url: result.url,
    201-          auto_reply_text: replyData.reply,
    202-          pattern: replyData.pattern,

  ===== post-comment.js（361 行・post-comment.js が 1 箇所）=====
    1-#!/usr/bin/env node
    2-/**
    3: * post-comment.js v2 (2026-05-15: pinned-tweet ID bug 真の修正)
    4- * Capture CreateTweet GraphQL response for reliable tweet ID, scraping fallback.
    5- *
    6- * Args: <text-base64> <reply-target-url> [<image-paths-csv>]
    7- * Output: JSON {ok, reply_tweet_id?, url?, error?, step?, captured_via?}
    8- */
    9-const { chromium } = require("playwright-core");
    10-
    11-const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
    12-const X_USERNAME = "heng_ji31590";
    13-
    14-function out(obj) { console.log(JSON.stringify(obj)); }
    15-
    16-// 2026-06-12: 文字化け投稿事故対策
    17-const { decodeBase64Safe } = require("./lib/text-safety");

  ===== post-publish-watchdog.js（118 行・post-comment.js が 1 箇所）=====
    104-    delResult = { ok: false, error: "safeDelete threw: " + e.message };
    105-  }
    106-
    107-  await page.close();
    108-  await browser.close();
    109-
    110:  const msg = `<@${OWNER}> 🔴 *post-publish-watchdog: 文字化け検出 + 自動削除*\n\nTweet ID: ${TWEET_ID}\nURL: ${url}\n検出: \`${validation.reason}\`\nDisplayed (前80文字): \`${dis
    111-  await slackPost(msg);
    112-
    113-  console.log(JSON.stringify({ ok: delResult.ok, action: "deleted", validation, delete_result: delResult }));
    114-})().catch(async e => {
    115-  console.error(JSON.stringify({ ok: false, error: e.message }));
    116-  await slackPost(`<@${OWNER}> 🔴 post-publish-watchdog 自体が fail: ${e.message}`);
    117-  process.exit(1);
    118-});

  ===== post-via-playwright.js（225 行・post-comment.js が 1 箇所）=====
    48-    page.on("dialog", d => { d.dismiss().catch(() => {}); });
    49-
    50-    step = "navigate-compose";
    51-    await page.goto(COMPOSE_URL, { waitUntil: "domcontentloaded", timeout: 30000 });
    52-
    53-    step = "wait-textarea";
    54:    // 2026-07-06: X UI render 遅延で 20s timeout 発生 → 5s pre-wait + 30s に緩和 (post-comment.js と同様)
    55-    await page.waitForTimeout(5000);
    56-    const textareaSelector = 'div[data-testid^="tweetTextarea_"][contenteditable="true"]';
    57-    await page.waitForSelector(textareaSelector, { timeout: 30000 });
    58-
    59-    step = "focus-and-type";
    60-    const ta = await page.$(textareaSelector);
    61-    await ta.click();
    62-    await page.keyboard.insertText(text);
    63-    await page.waitForTimeout(800);
    64-
    65-    let imageAttached = false;
    66-    if (hasImage) {
    67-      step = "attach-image";
    68-      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');

  ===== quick-reply-watcher.js（160 行・post-comment.js が 1 箇所）=====
    133-        history.push(record); saveLog(history);
    134-        done++; seen.add(tweetId);
    135-        continue;
    136-      }
    137-
    138-      const b64 = Buffer.from(gen.text, "utf8").toString("base64");
    139:      const out = execFileSync("/opt/homebrew/bin/node", [`${WS}/scripts/post-comment.js`, b64, url], {
    140-        encoding: "utf8", timeout: 120000,
    141-      });
    142-      const res = JSON.parse(out.trim().split("\n").pop());
    143-      if (res.ok) {
    144-        record.posted = true;
    145-        record.reply_url = res.url || null;
    146-        log(`@${t.handle}: 投稿成功 ${res.url || ""}（経過 ${ageMin.toFixed(1)}分）`);
    147-        done++;
    148-      } else {
    149-        log(`@${t.handle}: 投稿失敗 ${res.error || ""}`);
    150-      }
    151-      history.push(record); saveLog(history);
    152-      seen.add(tweetId);
    153-    } catch (e) {

  ===== respond-to-2-replies.js（135 行・post-comment.js が 1 箇所）=====
    67-    return { ok: false, error: e.message.slice(0, 120) };
    68-  }
    69-}
    70-
    71-async function postReply(text, targetUrl) {
    72-  const b64 = Buffer.from(text, "utf8").toString("base64");
    73:  const r = spawnSync("/usr/local/bin/node", [`${WS}/scripts/post-comment.js`, b64, targetUrl], {
    74-    encoding: "utf8", timeout: 90000, env: { ...process.env, CHROME_CDP_URL: CDP_URL },
    75-  });
    76-  try {
    77-    const o = JSON.parse(r.stdout.trim().split("\n").pop());
    78-    return o;
    79-  } catch {
    80-    return { ok: false, error: "parse-fail", stdout: (r.stdout || "").slice(-300), stderr: (r.stderr || "").slice(-300) };
    81-  }
    82-}
    83-
    84-(async () => {
    85-  const handled = loadHandled();
    86-  const browser = await chromium.connectOverCDP(CDP_URL, { timeout: 60000 });
    87-  const ctx = browser.contexts()[0];

  ===== retry-2-replies.js（98 行・post-comment.js が 1 箇所）=====
    44-  fs.writeFileSync(HANDLED + ".tmp", JSON.stringify(d, null, 2));
    45-  fs.renameSync(HANDLED + ".tmp", HANDLED);
    46-}
    47-
    48-function postReplyOnce(text, targetUrl) {
    49-  const b64 = Buffer.from(text, "utf8").toString("base64");
    50:  const r = spawnSync("/usr/local/bin/node", [`${WS}/scripts/post-comment.js`, b64, targetUrl], {
    51-    encoding: "utf8", timeout: 120000, env: { ...process.env, CHROME_CDP_URL: CDP_URL },
    52-  });
    53-  let parsed = null;
    54-  try { parsed = JSON.parse((r.stdout || "").trim().split("\n").pop()); } catch {}
    55-  return parsed || { ok: false, error: "parse-fail", stdout: (r.stdout||"").slice(-300), stderr: (r.stderr||"").slice(-300) };
    56-}
    57-
    58-async function postReplyWithRetry(text, url, max = 3) {
    59-  let last;
    60-  for (let i = 1; i <= max; i++) {
    61-    console.error(`[try ${i}/${max}] ${url}`);
    62-    last = postReplyOnce(text, url);
    63-    if (last.ok) return last;
    64-    console.error(`[fail ${i}] ${last.error?.slice(0,150)}`);

  ===== run-comment.sh（47 行・post-comment.js が 1 箇所）=====
    34-HANDLE=$(/usr/local/bin/node -e "
    35-const fs = require('fs');
    36-const e = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    37-process.stdout.write(e.target_handle || '');
    38-" "$ENTRY_FILE")
    39-
    40:RESULT=$(/usr/local/bin/node scripts/post-comment.js "$TEXT_B64" "$TARGET")
    41-echo "$RESULT"
    42-
    43-# If success, record to comment-state
    44-OK=$(echo "$RESULT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
    45-if [ "$OK" = "true" ] && [ -n "$HANDLE" ]; then
    46-  /usr/local/bin/node scripts/comment-state.js record-comment "$HANDLE" >/dev/null
    47-fi

  ===== run-publish.sh（210 行・post-comment.js が 3 箇所）=====
    3-# 既存機能: text + image + thread_url_text の自動 reply
    4-# 新規: kind=thread / thread_chain[] → main + 各 reply を順次投稿
    5-#
    6-# Schema:
    7-#   - thread_chain[]: [{text, role: hook|link|body|cta, image_path?, url?}]
    8-#   - 1個目 = main post (post-via-playwright)
    9:#   - 2個目以降 = reply chain (post-comment.js with previous tweet URL as target)
    10-ENTRY_ID="${1:-day2-1}"
    11-/Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh || { echo '{"ok":false,"step":"ensure-chrome","error":"Chrome failed to start"}'; exit 1; }
    12-cd /Users/ny/.openclaw/workspace
    13-
    14-ENTRY_JSON=$(/usr/local/bin/node -e "
    15-const q = require('./data/post_queue.json');
    16-const e = q.queue.find(x => x.id === '$ENTRY_ID');
    17-if (!e) { process.exit(1); }
    18-process.stdout.write(JSON.stringify({
    19-  text: e.text,
    20-  image_path: e.image_path || null,
    21-  thread_url_text: e.thread_url_text || null,
    22-  thread_chain: e.thread_chain || null,
    23-  kind: e.kind || null,
    --
    116-      }
    117-    } else {
    118-      // Reply to previous
    119-      if (!prevUrl) { console.log(JSON.stringify({ ok: false, step: 'thread-reply', error: 'no prev url for reply ' + i, thread_results: results })); return; }
    120-      // Brief delay for X to process previous
    121-      await new Promise(r => setTimeout(r, 5000));
    122:      const cmd = \`/usr/local/bin/node scripts/post-comment.js \"\${textB64}\" \"\${prevUrl}\" \"\${imagePath}\"\`;
    123-      try {
    124-        const out = execSync(cmd, { encoding: 'utf8' });
    125-        const lines = out.trim().split('\n');
    126-        const r = JSON.parse(lines[lines.length - 1]);
    127-        results.push({ index: i, role: item.role || 'reply', ...r });
    128-        if (r.ok && r.url) prevUrl = r.url;
    129-        else { console.log(JSON.stringify({ ok: false, step: 'thread-reply-' + i, error: r.error || 'reply ' + i + ' failed', thread_results: results })); return; }
    130-      } catch (e) {
    131-        console.log(JSON.stringify({ ok: false, step: 'thread-reply-' + i + '-exec', error: e.message, thread_results: results })); return;
    132-      }
    133-    }
    134-  }
    135-  // All succeeded
    136-  const main = results[0];
    --
    182-THREAD_RES=""
    183-if [ "$MAIN_OK" = "true" ] && [ -n "$THREAD_TEXT" ] && [ -n "$MAIN_URL" ]; then
    184-  echo "[run-publish] thread_url_text present, sleeping 8s..." >&2
    185-  sleep 8
    186-  THREAD_TEXT_B64=$(printf "%s" "$THREAD_TEXT" | base64)
    187-  ERR_TMP2=$(mktemp)
    188:  THREAD_RES=$(/usr/local/bin/node scripts/post-comment.js "$THREAD_TEXT_B64" "$MAIN_URL" 2>"$ERR_TMP2")
    189-  if [ -s "$ERR_TMP2" ]; then cat "$ERR_TMP2" >&2; fi
    190-  rm -f "$ERR_TMP2"
    191-  echo "[run-publish] thread reply: $THREAD_RES" >&2
    192-fi
    193-
    194-/usr/local/bin/node -e "
    195-let main;
    196-try {
    197-  const raw = process.env.MAIN_RES || '';

```

```javascript
  --- execSync / execFileSync の catch で stderr を捨てていないか ---
    /Users/ny/.openclaw/workspace/scripts/run-publish.sh-114-        console.log(JSON.stringify({ ok: false, step: 'thread-main-exec', error: e.message, thread_results: results }));
    /Users/ny/.openclaw/workspace/scripts/run-publish.sh-119-      if (!prevUrl) { console.log(JSON.stringify({ ok: false, step: 'thread-reply', error: 'no prev url for reply ' + i, thread_results: result
    /Users/ny/.openclaw/workspace/scripts/run-publish.sh-131-        console.log(JSON.stringify({ ok: false, step: 'thread-reply-' + i + '-exec', error: e.message, thread_results: results })); return;
    /Users/ny/.openclaw/workspace/scripts/run-publish.sh:203:catch (e) { main = {ok:false, step:'parse-main-result', error:'main result not valid JSON', raw:(process.env.MAIN_RES||'').slice(0, 200)}; }
    /Users/ny/.openclaw/workspace/scripts/auto-x-publisher.js-55-    return { ok: false, error: "slack-notify-lib-missing" };
    /Users/ny/.openclaw/workspace/scripts/auto-x-publisher.js-122-    return { refreshed: false, reason: "err: " + e.message };
```

---

## 次の一手

| §4 の出方 | 次 |
| --- | --- |
| **載っている** | `ops/data/autoload-jobs.txt` に足す（tab-guard に外されても戻る） |
| 載っていない | `bootstrap` の出力を読む。**足す前に直す**（空振り警報が鳴る） |

| §2・§3 の出方 | 意味 |
| --- | --- |
| `b_count` が 1 以上 | **出るはずの投稿が止まっている。** いま鳴ったのは正しい |
| どちらも 0 | いま壊れているものは無い。**静かなのが正常** |
| `b_count` が 10 以上 | **鳴りすぎ。** 期限切れの扱いを足す（TTL で失効した行を除く） |

**番人の費用: $0／回・$0／日（30 分ごと＝48 回）・$0／月。** LLM を呼ばない。
