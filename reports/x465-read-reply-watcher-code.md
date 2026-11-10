# incoming-reply-watcher の見る範囲と拾い方（2026-11-11 00:45:25 JST・読むだけ）
```js
  try {
    const m = text.match(/\{[\s\S]*\}/);
    if (!m) return null;
    const parsed = JSON.parse(m[0]);
    // v3 brand check
    if (/(私|あたし|わたし)/.test(parsed.reply)) return null;
    return parsed;
  } catch (e) { return null; }
}

async function main() {
  const queue = JSON.parse(fs.readFileSync(QUEUE_PATH, "utf8"));
  const cutoff = Date.now() - 24 * 3600 * 1000;
  const PINNED = "2054071132509311284";
  const recent = queue.queue.filter(e =>
    e.status === "posted" && e.x_tweet_id && e.x_tweet_id !== PINNED &&
    e.posted_at && new Date(e.posted_at).getTime() > cutoff
  );
  if (recent.length === 0) { log("no recent posts"); return; }
  log(`scanning ${recent.length} recent posts`);

  const state = loadState();
  const seen = new Set(state.seen_reply_ids);
  // Count today's auto-replies
  const today = new Date().toISOString().slice(0, 10);
  const todayAutoReplies = state.auto_replies.filter(a => a.posted_at && a.posted_at.startsWith(today)).length;
  log(`today's auto-replies: ${todayAutoReplies} / ${DAILY_AUTO_REPLY_CAP}`);

  const browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
  const ctx = browser.contexts()[0];
  const page = await ctx.newPage();
  const newReplies = [];

  for (const post of recent) {
    const url = `https://x.com/${X_USERNAME}/status/${post.x_tweet_id}`;
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 20000 });
      await page.waitForTimeout(2500);
      const replies = await page.$$eval('article', (articles, ownUsername) => {
        const out = [];
        for (let i = 1; i < articles.length; i++) {
          const a = articles[i];
          const link = a.querySelector('a[href*="/status/"]');
          const u = link?.getAttribute("href") || "";
          const m = u.match(/\/([^\/]+)\/status\/(\d+)/);
          if (!m) continue;
          if (m[1] === ownUsername) continue;
          const textEl = a.querySelector('[data-testid="tweetText"]');
          const text = textEl ? textEl.innerText.slice(0, 300) : "";
          const time = a.querySelector('time')?.getAttribute("datetime") || "";
          out.push({ author: m[1], reply_id: m[2], text, time, reply_url: `https://x.com/${m[1]}/status/${m[2]}` });
        }
        return out;
      }, X_USERNAME);
      for (const r of replies) {
        if (seen.has(r.reply_id)) continue;
        newReplies.push({ to_post_id: post.id, to_tweet_id: post.x_tweet_id, to_post_text: post.text || (post.thread_chain?.[0]?.text || ""), ...r });
        seen.add(r.reply_id);
      }
    } catch (e) {
      log(`  ${post.id}: ${e.message}`);
    }
    await page.waitForTimeout(800);
  }
  await page.close();
  await browser.close();

  if (newReplies.length === 0) { log("no new replies"); state.seen_reply_ids = [...seen].slice(-500); saveState(state); return; }
  log(`${newReplies.length} NEW replies, auto-reply attempting`);

  let postedCount = 0;
  const autoReplyResults = [];
  for (const r of newReplies) {
    if (todayAutoReplies + postedCount >= DAILY_AUTO_REPLY_CAP) {
      log(`  daily cap reached, skipping rest`);
      break;
```

## こちらの投稿のキューの中身
```
{"id":"blog-promo-20261101-points","kind":"thread","status":"posted","x_tweet_id":"2116727000358646078","posted_at":"2026-11-01T03:00:40.460Z","chain":["2116727000358646078","2116727081791013170"]}
キュー件数 2119
```
