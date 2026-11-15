# 返信を出す仕組みを読む（2026-10-25 22:20:53 JST・読むだけ・$0）

## ai.openclaw.comment-warmup の起動内容
```
	state = not running
	program = /bin/bash
	arguments = {
		/bin/bash
		/Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh
	runs = 7
	last exit code = 0
		state = active
		state = active
	properties = inferred program
```

## ai.openclaw.incoming-reply-watcher の起動内容
```
	state = not running
	program = /usr/local/bin/node
	arguments = {
		/usr/local/bin/node
		/Users/ny/.openclaw/workspace/scripts/incoming-reply-watcher.js
	runs = 102
	last exit code = 0
		state = active
		state = active
	properties = inferred program
```

## 返信を出していそうなスクリプト（scripts/ の中で返信・投稿を呼ぶ箇所）
```
auto-reply.js
compose-page-test.js
follow-up-reply.js
incoming-reply-responder.js
incoming-reply-watcher.js
post-comment.js
post-publish-watchdog.js
post-qt-manual.js
post-qt-v2.js
post-quote-tweet.js
post-via-playwright.js
qt-probe.js
quick-reply-watcher.js
respond-to-2-replies.js
retry-2-replies.js
test-image-upload.js
```

## post-comment.js（     363 行）: 投稿・結果・記録に関わる行
```
3: * post-comment.js v2 (2026-05-15: pinned-tweet ID bug 真の修正)
6: * Args: <text-base64> <reply-target-url> [<image-paths-csv>]
7: * Output: JSON {ok, reply_tweet_id?, url?, error?, step?, captured_via?}
14:function out(obj) { console.log(JSON.stringify(obj)); }
21:  if (!textArg || !targetUrl) { out({ ok: false, error: "args: <text-b64> <target-url>" }); process.exit(1); }
24:    out({ ok: false, step: "text-safety", error: "decode/validation failed", reason: decoded.reason, details: decoded.details });
44:    await page.waitForTimeout(6000);
71:        await page.waitForTimeout(4000);
84:      const dumpPath = "/tmp/post-comment-no-textarea-" + Date.now() + ".html";
87:        require("fs").writeFileSync(dumpPath, html);
90:      out({ ok: false, step, error: "no reply textarea", dump: dumpPath });
130:    if (_x150want && !page.url().includes(_x150want[1])) {
131:      out({ ok: false, step: "wrong-page", error: "返信先のページに居ない: url=" + page.url().slice(0, 120) });
141:      out({ ok: false, step: "no-focus", error: "入力欄にフォーカスが載らない（打たずに止まる）" });
147:    await page.waitForTimeout(1500);
158:      if (imagePaths.length > 4) { out({ ok: false, step, error: "X allows max 4 images, got " + imagePaths.length }); process.exit(1); }
160:      if (missing.length) { out({ ok: false, step, error: "image not found: " + missing.join(",") }); process.exit(1); }
164:      if (!fileInput) { out({ ok: false, step, error: "file input not found on reply composer" }); process.exit(1); }
172:      if (!attached) { out({ ok: false, step, error: "attachment did not appear - 画像なしでは出さない" }); process.exit(1); }
173:      await page.waitForTimeout(1500);
189:        out({
205:      (resp) => /\/(CreateTweet|CreateNoteTweet|create_tweet)/i.test(resp.url()) && resp.request().method() === "POST",
226:      await page.waitForTimeout(200);
228:      await page.waitForTimeout(500);
255:    await page.waitForTimeout(2000);
262:      await page.waitForTimeout(4000);
282:            const links = article.querySelectorAll('a[href*="/status/"]');
285:              const m = a.getAttribute("href").match(new RegExp(`/${username}/status/(\\d+)`, "i"));
288:            if (ownStatusIds.length > 0) return ownStatusIds[0]; // first own (= the reply we just posted)
300:    if (!capturedTweetId) { out({ ok: false, step, error: "couldn't capture reply tweet id (graphql + scrape both failed)" }); process.exit(1); }
308:      await verifyPage.goto(`https://x.com/${X_USERNAME}/status/${capturedTweetId}`, { waitUntil: "domcontentloaded", timeout: 15000 }).catch(()=>{});
309:      await verifyPage.waitForTimeout(4000);
321:          const links = document.querySelectorAll(`a[href*="/status/${parentId}"]`);
332:        const { execSync } = require("child_process");
333:        execSync(`ALLOW_DESTRUCTIVE=1 /usr/local/bin/node ${require("path").join(__dirname, "delete-tweet.js")} ${capturedTweetId} ${X_USERNAME}`, { timeout: 30000, stdio: "ignore" });
337:      out({ ok: false, step: "reply-linkage-lost", error: "posted but reply linkage lost, auto-deleted", tweet_id: capturedTweetId, target_url: targetUrl });
341:    // 2026-06-12: 投稿成功後 30s 内に文字化け watchdog を背景 spawn
343:      const { spawn } = require("child_process");
344:      const watchdog = spawn("/usr/local/bin/node", [require("path").join(__dirname, "post-publish-watchdog.js"), capturedTweetId], {
348:    } catch (e) { /* watchdog spawn failure must not break main return */ }
349:    out({
351:      reply_tweet_id: capturedTweetId,
352:      url: `https://x.com/${X_USERNAME}/status/${capturedTweetId}`,
358:    out({ ok: false, step, error: e.message });
```

## incoming-reply-watcher.js（     270 行）: 投稿・結果・記録に関わる行
```
4:// Flow: new reply 検知 → Haiku generate アタシ口調返信 → post-comment.js で投稿 → Slack通知
8:const { execSync } = require("child_process");
14:const POST_COMMENT_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/post-comment.js";
17:const SLACK_TOKEN = JSON.parse(fs.readFileSync("/Users/ny/.openclaw/openclaw.json", "utf8")).channels.slack.botToken;
23:function log(s) { try { fs.appendFileSync(LOG_PATH, `[${new Date().toISOString()}] ${s}\n`); } catch {}; console.log(s); }
36:  if (!fs.existsSync(STATE_PATH)) return { seen_reply_ids: [], auto_replies: [], replied_authors_24h: {} };
37:  const s = JSON.parse(fs.readFileSync(STATE_PATH, "utf8"));
44:  fs.writeFileSync(tmp, JSON.stringify(s, null, 2));
98:    const parsed = JSON.parse(m[0]);
106:  const queue = JSON.parse(fs.readFileSync(QUEUE_PATH, "utf8"));
110:    e.status === "posted" && e.x_tweet_id && e.x_tweet_id !== PINNED &&
111:    e.posted_at && new Date(e.posted_at).getTime() > cutoff
117:  const seen = new Set(state.seen_reply_ids);
120:  const todayAutoReplies = state.auto_replies.filter(a => a.posted_at && a.posted_at.startsWith(today)).length;
129:    const url = `https://x.com/${X_USERNAME}/status/${post.x_tweet_id}`;
131:      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 20000 });
132:      await page.waitForTimeout(2500);
137:          const link = a.querySelector('a[href*="/status/"]');
145:          out.push({ author: m[1], reply_id: m[2], text, time, reply_url: `https://x.com/${m[1]}/status/${m[2]}` });
150:        if (seen.has(r.reply_id)) continue;
151:        newReplies.push({ to_post_id: post.id, to_tweet_id: post.x_tweet_id, to_post_text: post.text || (post.thread_chain?.[0]?.text || ""), ...r });
152:        seen.add(r.reply_id);
157:    await page.waitForTimeout(800);
162:  if (newReplies.length === 0) { log("no new replies"); state.seen_reply_ids = [...seen].slice(-500); saveState(state); return; }
165:  let postedCount = 0;
168:    if (todayAutoReplies + postedCount >= DAILY_AUTO_REPLY_CAP) {
188:    // Post via post-comment.js (target = the incoming reply's URL)
191:      const out = execSync(`/usr/local/bin/node ${POST_COMMENT_SCRIPT} "${textB64}" "${r.reply_url}" 2>&1`, { encoding: "utf8", maxBuffer: 8*1024*1024 });
192:      const result = JSON.parse(out.trim().split("\n").pop());
194:        log(`    ✅ posted: ${result.url}`);
195:        postedCount++;
197:          incoming_reply_id: r.reply_id,
200:          auto_reply_url: result.url,
203:          posted_at: new Date().toISOString(),
206:        autoReplyResults.push({ ok: true, to: r.author, text: replyData.reply, url: result.url, pattern: replyData.pattern });
211:          const followOut = execSync(`/usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js ${r.author} 2>&1`, { encoding: "utf8", timeout: 30000, maxBuffer: 2*1024*1024 });
212:          const followRes = JSON.parse(followOut.trim().split("\n").pop());
218:              const rf = fs.existsSync(RF_PATH) ? JSON.parse(fs.readFileSync(RF_PATH, "utf8")) : {};
224:                  incoming_reply_id: r.reply_id,
226:                fs.writeFileSync(RF_PATH, JSON.stringify(rf, null, 2));
243:    await new Promise(r => setTimeout(r, 3000)); // pause between auto-replies
250:  state.seen_reply_ids = [...seen].slice(-500);
255:  if (postedCount > 0 || autoReplyResults.length > 0) {
256:    let msg = `<@${OWNER_USER_ID}> 💬 incoming-reply-watcher 自動返信完了 (${postedCount}/${autoReplyResults.length}件成功)\n\n`;
259:        msg += `✅ @${a.to} に [${a.pattern}] 返信: "${a.text}"\n  → ${a.url}\n\n`;
264:    msg += `\n📊 今日の auto-reply: ${todayAutoReplies + postedCount}/${DAILY_AUTO_REPLY_CAP} (cap)`;
```

## post-comment.js の最後 40 行（何を返しているか）
```
        return false;
      }, { parentId: parentTweetId }).catch(()=>false);
      await verifyPage.close().catch(()=>{});
    } catch (e) { /* verify page error → treat as unknown, skip delete */ linkageOK = true; }

    if (!linkageOK) {
      // 独立 tweet 化検出 → 即削除
      try {
        const { execSync } = require("child_process");
        execSync(`ALLOW_DESTRUCTIVE=1 /usr/local/bin/node ${require("path").join(__dirname, "delete-tweet.js")} ${capturedTweetId} ${X_USERNAME}`, { timeout: 30000, stdio: "ignore" });
      } catch (e) { /* delete fail, still report linkage-lost */ }
      await page.close().catch(()=>{});
      await browser.close().catch(()=>{});
      out({ ok: false, step: "reply-linkage-lost", error: "posted but reply linkage lost, auto-deleted", tweet_id: capturedTweetId, target_url: targetUrl });
      process.exit(1);
    }

    // 2026-06-12: 投稿成功後 30s 内に文字化け watchdog を背景 spawn
    try {
      const { spawn } = require("child_process");
      const watchdog = spawn("/usr/local/bin/node", [require("path").join(__dirname, "post-publish-watchdog.js"), capturedTweetId], {
        detached: true, stdio: "ignore", env: process.env,
      });
      watchdog.unref();
    } catch (e) { /* watchdog spawn failure must not break main return */ }
    out({
      ok: true,
      reply_tweet_id: capturedTweetId,
      url: `https://x.com/${X_USERNAME}/status/${capturedTweetId}`,
      captured_via: capturedVia,
    });
  } catch (e) {
    if (page) try { await page.close(); } catch {}
    if (browser) try { await browser.close(); } catch {}
    out({ ok: false, step, error: e.message });
    process.exit(1);
  }
}

main();
```

## comment-warmup.log の直近の「出した」行（20 行）
```
{"ok":true,"entry_id":"comment-20261025-1203-3","x_tweet_id":"2114191233442804222","url":"https://x.com/heng_ji31590/status/2114191233442804222","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1204-4","x_tweet_id":"2114191302254629166","url":"https://x.com/heng_ji31590/status/2114191302254629166","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1204-5","x_tweet_id":"2114191372127510970","url":"https://x.com/heng_ji31590/status/2114191372127510970","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1603-0","x_tweet_id":"2114251438427922823","url":"https://x.com/heng_ji31590/status/2114251438427922823","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1603-1","x_tweet_id":"2114251507923394717","url":"https://x.com/heng_ji31590/status/2114251507923394717","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1603-2","x_tweet_id":"2114251566106681571","url":"https://x.com/heng_ji31590/status/2114251566106681571","slack_report_ts":"silenced"}
[2026-10-25T16:03:57] gen failed (#4): {"ok":false,"error":"噛み合い検査で弾いた: 相場の予測「上がる」＝相手の投稿に無い見通しを足している","skip":true,"reason":"噛み合い検査�
{"ok":true,"entry_id":"comment-20261025-1604-4","x_tweet_id":"2114251654019305607","url":"https://x.com/heng_ji31590/status/2114251654019305607","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1604-5","x_tweet_id":"2114251730997350414","url":"https://x.com/heng_ji31590/status/2114251730997350414","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1903-0","x_tweet_id":"2114296725540352088","url":"https://x.com/heng_ji31590/status/2114296725540352088","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1903-2","x_tweet_id":"2114296814803485108","url":"https://x.com/heng_ji31590/status/2114296814803485108","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1903-3","x_tweet_id":"2114296895648788568","url":"https://x.com/heng_ji31590/status/2114296895648788568","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1904-4","x_tweet_id":"2114296976284299690","url":"https://x.com/heng_ji31590/status/2114296976284299690","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-1904-5","x_tweet_id":"2114297040633315629","url":"https://x.com/heng_ji31590/status/2114297040633315629","slack_report_ts":"silenced"}
{"ok":true,"entry_id":"comment-20261025-2203-0","x_tweet_id":"2114342046186258871","url":"https://x.com/heng_ji31590/status/2114342046186258871","slack_report_ts":"silenced"}
[2026-10-25T22:03:25] gen failed (#2): {"ok":false,"error":"生成側が skip: 公式アカウントのキャンペーン投稿。返信対象は一般ユーザーの体験・質問・情報共有に限定。広告・プ
{"ok":true,"entry_id":"comment-20261025-2203-2","x_tweet_id":"2114342117850181665","url":"https://x.com/heng_ji31590/status/2114342117850181665","slack_report_ts":"silenced"}
[2026-10-25T22:03:46] gen failed (#4): {"ok":false,"error":"生成側が skip: 金銭目的の搾取・詐欺的勧誘。返信すべき投稿ではない","skip":true,"reason":"生成側が skip: 金銭目的の搾取�
[2026-10-25T22:03:48] gen failed (#5): {"ok":false,"error":"生成側が skip: 企業の公式キャンペーン投稿。返信すると宣伝協力になるため、個人の投稿ではなく広告への返信は控え
{"ok":true,"entry_id":"comment-20261025-2203-5","x_tweet_id":"2114342216370196892","url":"https://x.com/heng_ji31590/status/2114342216370196892","slack_report_ts":"silenced"}
```

## comment-orchestrator.log の直近の「出した」行（20 行）
```
[2026-10-23T16:03:18] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手が募集投稿（性的サービス関連）。返信すると当アカウントが助長・仲介と見なされるリスク。ハッ
[2026-10-23T16:03:20] gen failed (#2): {"ok":false,"error":"生成側が skip: 投稿の具体的な内容が不明確。「データセクション & VLCセキュリティ」と「社名変わった」が何を指すの
[2026-10-23T19:05:06] gen failed (#3): {"ok":false,"error":"生成側が skip: 電話番号認証案件の取引勧誘。金銭・個人情報が絡む案件相互協力の投稿であり、返信すると当アカウン
[2026-10-23T19:05:51] gen failed (#5): {"ok":false,"error":"生成側が skip: 相手はサンドラッグのアプリ宣伝投稿。クーポン情報は相手が提示済みで、こちらから足す具体的な情報
[2026-10-23T22:04:08] gen failed (#2): {"ok":false,"error":"生成側が skip: 投稿に具体的な内容がなく、ハッシュタグのみ。何に対して返信すべきか不明。","skip":true,"reason":"生成側
[2026-10-23T22:04:42] gen failed (#5): {"ok":false,"error":"噛み合い検査で弾いた: 相場の予測「反発」＝相手の投稿に無い見通しを足している","skip":true,"reason":"噛み合い検査で�
[2026-10-24T05:04:24] gen failed (#1): {"ok":false,"error":"生成側が skip: 公式からのお詫び・復旧通知。個人の投稿ではなく、企業アナウンスなので返信対象外","skip":true,"reason":"
[2026-10-24T05:05:19] gen failed (#3): {"ok":false,"error":"生成側が skip: 楽天の公式キャンペーン投稿。企業アカウントへの返信は想定外。また相手の個人的な経験・判断・数字
[2026-10-24T05:07:07] gen failed (#6): {"ok":false,"error":"生成側が skip: 投稿が「ふぁっ🫨」と#新NISAだけで、具体的な内容がないため、相手の状況に触れようがない。無理に返
[2026-10-24T16:06:41] gen failed (#5): {"ok":false,"error":"生成側が skip: 投稿は店舗・イベント告知で、相手の個人的な行動や経験がない。返信する具体的な中身がない","skip":tru
[2026-10-24T19:03:45] gen failed (#3): {"ok":false,"error":"生成側が skip: 商品紹介・販売リンク付きの投稿。返信すべき個人的な体験や判断がなく、こちらから金額や購入推奨を
[2026-10-24T22:03:27] gen failed (#2): {"ok":false,"error":"生成側が skip: 楽天の公式キャンペーン投稿。企業アカウントへの返信は個人の意見交換ではなく、広告への反応になる
[2026-10-24T22:03:28] gen failed (#3): {"ok":false,"error":"生成側が skip: 相手が性的搾取・依存状態を自虐的に投稿しており、返信は茶化しにも同意にもなり得ない。ハッカー子
[2026-10-24T22:03:30] gen failed (#4): {"ok":false,"error":"生成側が skip: 金銭の貸し借り要求。返信すべき投稿ではない","skip":true,"reason":"生成側が skip: 金銭の貸し借り要求。返�
[2026-10-24T22:03:49] gen failed (#6): {"ok":false,"error":"生成側が skip: 投稿に具体的な内容がない。「いろいろありすぎ〜〜」だけでは、何があったのか、何に対して返信すべ
[2026-10-25T05:03:48] gen failed (#3): {"ok":false,"error":"生成側が skip: 性的サービス・金銭搾取を求める投稿。返信すべき内容ではない","skip":true,"reason":"生成側が skip: 性的サ�
[2026-10-25T16:03:57] gen failed (#4): {"ok":false,"error":"噛み合い検査で弾いた: 相場の予測「上がる」＝相手の投稿に無い見通しを足している","skip":true,"reason":"噛み合い検査�
[2026-10-25T22:03:25] gen failed (#2): {"ok":false,"error":"生成側が skip: 公式アカウントのキャンペーン投稿。返信対象は一般ユーザーの体験・質問・情報共有に限定。広告・プ
[2026-10-25T22:03:46] gen failed (#4): {"ok":false,"error":"生成側が skip: 金銭目的の搾取・詐欺的勧誘。返信すべき投稿ではない","skip":true,"reason":"生成側が skip: 金銭目的の搾取�
[2026-10-25T22:03:48] gen failed (#5): {"ok":false,"error":"生成側が skip: 企業の公式キャンペーン投稿。返信すると宣伝協力になるため、個人の投稿ではなく広告への返信は控え
```
**読んだだけ。返信・クリックはしていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
