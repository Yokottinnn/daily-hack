# 2 つの詰まりを実物で切り分ける

**このレポートが作られた時刻: 2026-09-08 00:18:56 JST**

> **推測を書かない。** 実際の出力だけを載せる。
> 何も変更していない。LLM も呼んでいない（$0）。

## ① 返信: どの段で候補が 0 になるのか

### 1-a. `comment-orchestrator.sh` の候補取得まわり

```bash
3:# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
9:MAX_PICKS=${MAX_PICKS_PER_FIRE:-2}
22:log "=== comment orchestrator start (max_picks=$MAX_PICKS, reply_follow_cap=$REPLY_FOLLOW_DAILY_CAP) ==="
34:# 2026-08-07: 以前は 2>&1 で stderr を混ぜたまま JSON.parse していたため、trend-detect が
37:DETECT_OUT=$(/usr/local/bin/node scripts/trend-detect.js 2>>"$LOG")
46:CANDIDATES=$(echo "$CANDIDATES" | /usr/local/bin/node scripts/ng-filter-candidates.cjs 2>>"$LOG")
49:  log "no candidates"
53:PICKS_FILE=/tmp/orch-picks.$$.json
62:    if (picked.length >= $MAX_PICKS) break;
69:  fs.writeFileSync('$PICKS_FILE', JSON.stringify(picked));
72:N_PICKED=$(/usr/local/bin/node -e "console.log(require('$PICKS_FILE').length)")
73:log "picked $N_PICKED / max $MAX_PICKS (from $N candidates)"
74:if [ "$N_PICKED" = "0" ]; then
76:  rm -f $PICKS_FILE
103:for i in $(seq 0 $((N_PICKED - 1))); do
104:  PICK=$(/usr/local/bin/node -e "console.log(JSON.stringify(require('$PICKS_FILE')[$i]))")
105:  AUTHOR=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).author)})")
106:  TARGET_URL=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).tweet_url)})")
108:  log "--- processing #$((i+1))/$N_PICKED for @$AUTHOR ---"
110:  GEN_INPUT=$(/usr/local/bin/node -e "console.log(JSON.stringify({trend: $PICK, kind: 'comment'}))")
172:rm -f $PICKS_FILE
173:log "=== orchestrator done: $N_PICKED drafts, $REPLY_FOLLOW_COUNT reply-connected follows today ==="
```

### 1-b. `trend-detect.js` を単体で走らせて、生の件数を見る

**これは検知だけ。投稿もしないし LLM も呼ばない。**

```
  **120 秒で切った（ハングしている）**
{"ok":true,"count":1,"candidates":[{"tweet_url":"https://x.com/iceiria1/status/2096893966063149439","text":"android 楽天リワード\nゼロから社長！ 1周50回から80回に変更\n#ポイ活 #楽天ポイント","author":"iceiria1","like_count":5,"reply_count":2,"retweet_count":0,"posted_at":"2026-09-07T09:30:54.000Z","source":"hashtag:楽天ポイント","score":11,"age_hours":5.8}]}
(rc=137)
```

### 1-c. 検知の出力ファイルは何件 入っているか

```
```

### 1-d. `comment-warmup.log` の今日と昨日の `no candidates` の出方

**いつから 0 件 続きなのか。**

```
  日付ごとの no candidates 回数（直近 10 日）:
    2026-08-27  起動 4   回 / no candidates 0
0 回
    2026-08-28  起動 4   回 / no candidates 0
0 回
    2026-08-29  起動 4   回 / no candidates 0
0 回
    2026-08-30  起動 4   回 / no candidates 0
0 回
    2026-08-31  起動 4   回 / no candidates 0
0 回
    2026-09-01  起動 4   回 / no candidates 0
0 回
    2026-09-02  起動 1   回 / no candidates 0
0 回
    2026-09-06  起動 2   回 / no candidates 0
0 回
    2026-09-07  起動 1   回 / no candidates 0
0 回
    2026-09-08  起動 0
0 回 / no candidates 0
0 回

  直近 30 行:
    [2026-09-06T21:26:20] gen failed (#2): {"ok":false,"error":"生成側が skip: 相手の投稿は商品販売告知。ハッカー子のキャラは節約・家計管理・投資の話題向け。ティッシュペーパーの販売情報には、キャラとして自然に乗る話題がない","skip":true,"reason":"生成側が skip: 相手の投稿は商品販売告知。ハッカー子のキャラは節約・家計管理・投資の話題向け。ティッシュペーパーの販売情報には、キャラとして自然に乗る話題がない"}
    [2026-09-06T21:26:20] === orchestrator done: 2 drafts, 16 reply-connected follows today ===
    [2026-09-06T22:00:02] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
    [2026-09-06T22:03:03] picked 2 / max 2 (from 5 candidates)
    [2026-09-06T22:03:03] recent template ids (newest first): T07,T11,T21,T22,T16c
    [2026-09-06T22:03:03] today's reply-connected follows: 16 / 30
    [2026-09-06T22:03:03] --- processing #1/2 for @<伏せ> ---
    [2026-09-06T22:03:06] gen failed (#1): {"ok":false,"error":"噛み合い検査で弾いた: 同じ語の繰り返し「材50M」＝日本語が壊れている","skip":true,"reason":"噛み合い検査で弾いた: 同じ語の繰り返し「材50M」＝日本語が壊れている"}
    [2026-09-06T22:03:06] --- processing #2/2 for @<伏せ> ---
    [2026-09-06T22:03:08]   → chosen template_id: unknown
    [2026-09-06T22:03:08] enqueue: {"ok":true,"id":"comment-20260906-2203-1"}
    {"ok":true,"entry_id":"comment-20260906-2203-1","x_tweet_id":"2096585028201533689","url":"https://x.com/heng_ji31590/status/2096585028201533689","slack_report_ts":"silenced"}
    [2026-09-06T22:03:23]   follow @<伏せ>: filtered
    [2026-09-06T22:03:23] === orchestrator done: 2 drafts, 16 reply-connected follows today ===
    [2026-09-07T23:59:20] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
    [2026-09-08T00:03:14] picked 4 / max 4 (from 23 candidates)
    [2026-09-08T00:03:14] recent template ids (newest first): unknown,T07,T11,T21,T22
    [2026-09-08T00:03:14] today's reply-connected follows: 0 / 30
    [2026-09-08T00:03:14] --- processing #1/4 for @<伏せ> ---
    [2026-09-08T00:03:16] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手は投資判断の決め手について意見を求めているが、アタシが「正解」を示すと責任が生じる。金銭判断への助言は避けるべき。また、相手の投稿には具体的な失敗例・成功例・数字がなく、こちらから情報を足す根拠がない。無理に返信すれば型になる","skip":true,"reason":"生成側が skip: 相手は投資判断の決め手について意見を求めているが、アタシが「正解」を示すと責任が生じる。金銭判断への助言は避けるべき。また、相手の投稿には具体的な失敗例・成功例・数字がなく、こちらから情報を足す根拠がない。無理に返信すれば型になる"}
    [2026-09-08T00:03:17] --- processing #2/4 for @<伏せ> ---
    [2026-09-08T00:03:19]   → chosen template_id: unknown
    [2026-09-08T00:03:19] enqueue: {"ok":true,"id":"comment-20260908-0003-1"}
    {"ok":true,"entry_id":"comment-20260908-0003-1","x_tweet_id":"2096977707943039188","url":"https://x.com/heng_ji31590/status/2096977707943039188","slack_report_ts":"silenced"}
    [2026-09-08T00:03:45]   follow @<伏せ>: filtered
    [2026-09-08T00:03:45] --- processing #3/4 for @<伏せ> ---
    [2026-09-08T00:03:46] gen failed (#3): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: r10.to","skip":true,"reason":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: r10.to"}
    [2026-09-08T00:03:46] --- processing #4/4 for @<伏せ> ---
    [2026-09-08T00:03:47] gen failed (#4): {"ok":false,"error":"生成側が skip: 投稿が hashtag のみで具体的な内容がない。返信する対象がない","skip":true,"reason":"生成側が skip: 投稿が hashtag のみで具体的な内容がない。返信する対象がない"}
    [2026-09-08T00:03:47] === orchestrator done: 4 drafts, 0 reply-connected follows today ===
```

### 1-e. 検知の取得元（何を見に行っているか）

```javascript
5: *   B. Hashtag search: see HASHTAGS list
6: *   C. Competitor accounts: see COMPETITORS list
10: *   - PER_ITEM_TIMEOUT_MS (default 12s) — hashtag/account 個別 scrape の hard cap
11: *   - trend-cache.json に latest_success 保存 → hang / error 時 stale で return
18:const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
19:const CACHE_PATH = "/Users/ny/.openclaw/workspace/data/trend-cache.json";
47:  if (!fs.existsSync(CACHE_PATH)) return { seen_urls: [], latest_success: null };
49:  if (!c.seen_urls) c.seen_urls = [];
122:      const social = a.querySelector('[data-testid="socialContext"]')?.textContent || "";
124:      const ev = a.querySelector('time');
126:      const text = a.querySelector('[data-testid="tweetText"]')?.innerText || "";
127:      const link = a.querySelector('a[href*="/status/"]')?.getAttribute("href") || "";
132:      const likeAria = a.querySelector('[data-testid="like"], [data-testid="unlike"]')?.getAttribute("aria-label") || "";
133:      const replyAria = a.querySelector('[data-testid="reply"]')?.getAttribute("aria-label") || "";
134:      const retweetAria = a.querySelector('[data-testid="retweet"], [data-testid="unretweet"]')?.getAttribute("aria-label") || "";
142:        tweet_url: `https://x.com/${author}/status/${tweetId}`,
155:async function scrapeHashtag(page, hashtag) {
156:  const url = `https://x.com/search?q=${encodeURIComponent("#" + hashtag)}&f=live`;
157:  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 10000 });
158:  return scrapeTimelinePage(page, `hashtag:${hashtag}`);
162:  const url = `https://x.com/${handle}`;
163:  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 10000 });
175:  const seen = new Set(cache.seen_urls);
179:    if (all.length >= EARLY_EXIT_COUNT) { console.error(`early exit: hashtag loop, all=${all.length}`); break; }
181:      const items = await withTimeout(scrapeHashtag(page, tag), PER_ITEM_TIMEOUT_MS, `hashtag:${tag}`);
189:      console.error(`hashtag ${tag} failed:`, e.message);
213:    if (seen.has(x.tweet_url) || seenNow.has(x.tweet_url)) continue;
214:    seenNow.add(x.tweet_url);
218:  for (const u of seenNow) cache.seen_urls.push(u);
219:  if (cache.seen_urls.length > 500) cache.seen_urls = cache.seen_urls.slice(-500);
```

## ② アンフォロー: playwright はどこにあるのか

**「node のバージョン違い」は外れだった。** 実物で探す。

### 2-a. node は何本 あるか

```
  /usr/local/bin/node              v24.14.0
  /opt/homebrew/bin/node           v26.0.0
  /opt/homebrew/bin/node           v26.0.0
  command -v node → /opt/homebrew/bin/node
  NODE_PATH       → (未設定)
```

### 2-b. playwright の実体を探す

```
  無い   /Users/ny/.openclaw/workspace/node_modules/playwright
  無い   /Users/ny/.openclaw/workspace/scripts/node_modules/playwright
  無い   /Users/ny/node_modules/playwright
  無い   /usr/local/lib/node_modules/playwright
  **有る** /opt/homebrew/lib/node_modules/playwright
  **有る** /Users/ny/.openclaw/workspace/node_modules/playwright-core
  無い   /Users/ny/.openclaw/workspace/node_modules/puppeteer
  無い   /Users/ny/.openclaw/workspace/node_modules/puppeteer-core

  --- find（深さ 4 まで・playwright / puppeteer のディレクトリ） ---
  /Users/ny/.openclaw/workspace/node_modules/playwright-core
  /opt/homebrew/lib/node_modules/playwright
  /opt/homebrew/lib/node_modules/playwright/node_modules/playwright-core
```

### 2-c. **稼働中のスクリプトは何を require しているか**

`post-via-playwright.js` は実際に投稿を成功させている。**その 1 行目が答え。**

```javascript
  // ===== post-via-playwright.js =====
  7:const { chromium } = require("playwright-core");
  8:const fs = require("fs");
  18:const { decodeBase64Safe, weightedLength } = require("./lib/text-safety");
  42:    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
  204:      const { spawn } = require("child_process");
  205:      const watchdog = spawn("/usr/local/bin/node", [require("path").join(__dirname, "post-publish-watchdog.js"), capturedTweetId], {
  // ===== unfollow-handle.js =====
  5:const { chromium } = require("playwright-core");
  15:  const { openWorkTab } = require("./lib/work-window.js");
  // ===== post-comment.js =====
  9:const { chromium } = require("playwright-core");
  17:const { decodeBase64Safe } = require("./lib/text-safety");
  34:    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 60000 });
  87:        require("fs").writeFileSync(dumpPath, html);
  234:        const { execSync } = require("child_process");
  235:        execSync(`ALLOW_DESTRUCTIVE=1 /usr/local/bin/node ${require("path").join(__dirname, "delete-tweet.js")} ${capturedTweetId} ${X_USERNAME}`, { timeout: 30000, stdio: "ignore" });
  245:      const { spawn } = require("child_process");
  246:      const watchdog = spawn("/usr/local/bin/node", [require("path").join(__dirname, "post-publish-watchdog.js"), capturedTweetId], {
```

### 2-d. 実際に require できるか（3 通り 試す）

```
  cwd=/Users/ny/.openclaw/workspace                  → NG MODULE_NOT_FOUND
  cwd=/Users/ny/.openclaw/workspace/scripts          → NG MODULE_NOT_FOUND
  cwd=/Users/ny                                      → NG MODULE_NOT_FOUND
  NODE_PATH を workspace に向けた場合           → NG MODULE_NOT_FOUND
  playwright-core で試す                            → OK /Users/ny/.openclaw/workspace/node_modules/playwright-core/index.js
```

### 2-e. 稼働ジョブの plist が環境変数を渡していないか

```
    "ProgramArguments" => [
    "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.err"
    "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.out"
```

---

**何も変更していない。投稿・返信・アンフォロー・フォローのいずれもしていない（$0）。**
