# 投稿画面の ALT の欄（2026-10-11 21:50:48 JST・$0・投稿していない）

## ① post-via-playwright.js の全文

```js
// 225 行
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
    await ta.click();
    await page.keyboard.insertText(text);
    await page.waitForTimeout(800);

    let imageAttached = false;
    if (hasImage) {
      step = "attach-image";
      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
      if (!fileInput) fileInput = await page.$('input[type="file"]');
      if (!fileInput) throw new Error("file input not found on compose page");
      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
      step = "wait-image-upload";

      // 2026-08-09 修正: 旧実装は role="progressbar" が 0 になるのを完了条件にしていたが、
      // これは X の「文字数カウンターの円形インジケータ」で常時 3 個存在する。
      // よって条件は永遠に成立せず、.catch() で握り潰されたままアップロード途中で送信され、
      // 画像が 1 枚も付かないまま投稿されていた (画像つき投稿がほぼ毎回これで失敗)。
      // 正しい完了サインは「添付プレビューの画像枚数」と「各画像の削除ボタン数」。
      const want = imagePaths.length;
      let attachedCount = 0;
      for (let i = 0; i < 45; i++) {
        attachedCount = await page.evaluate(() => {
          const box = document.querySelector('[data-testid="attachments"]');
          if (!box) return 0;
          const imgs = box.querySelectorAll("img").length;
          const removes = document.querySelectorAll('[aria-label*="削除"], [data-testid="removeMedia"]').length;
          // プレビューと削除ボタンが揃って初めて「その枚数はアップロード済み」と見なせる
          return Math.min(imgs, removes || imgs);
        });
        if (attachedCount >= want) break;
        await page.waitForTimeout(2000);
      }
      if (attachedCount < want) {
        await page.close(); await browser.close();
        out({ ok: false, step, error: "画像のアップロードが完了しないため投稿を中止しました",
              images_expected: want, images_attached: attachedCount });
        process.exit(1);
      }
      console.error(`[post-via-playwright] attached ${attachedCount}/${want} image(s)`);
      await page.waitForTimeout(1500);
      imageAttached = true;
    }

    // 2026-05-15 v3: arm GraphQL response listener BEFORE submit
    step = "arm-response-listener";
    const responsePromise = page.waitForResponse(
      (resp) => /\/(CreateTweet|CreateNoteTweet|create_tweet)/i.test(resp.url()) && resp.request().method() === "POST",
      { timeout: 30000 }
    ).catch(() => null);

    // 2026-08-07: 送信は Meta+Enter だが、X 側が投稿を受け付けない状態
    // (文字数超過・画像処理中など) だとボタンが aria-disabled のままで、キーを押しても
    // 何も起きない。従来はそれを検知せず後段の fallback が別ツイートの ID を拾って
    // 成功扱いにしていた。押す前に必ず投稿可能かを確認する。
    step = "verify-submittable";
    const submittable = await page.evaluate(() => {
      const btn = document.querySelector('[data-testid="tweetButton"]')
               || document.querySelector('[data-testid="tweetButtonInline"]');
      if (!btn) return { ok: false, reason: "post_button_not_found" };
      if (btn.getAttribute("aria-disabled") === "true") return { ok: false, reason: "post_button_disabled" };
      return { ok: true };
    });
    if (!submittable.ok) {
      await page.close(); await browser.close();
      out({ ok: false, step, error: "X refused to enable the post button — nothing was posted",
            reason: submittable.reason, weighted_length: weightedLength(text), image_attached: imageAttached });
      process.exit(1);
    }

    step = "submit-via-keyboard";
    // 2026-08-09: 画像を添付するとコンポーザーが再描画され、最初に取得した
    // ElementHandle が DOM から外れる ("Element is not attached to the DOM")。
    // 画像つき投稿が毎回ここで落ちていたので、送信直前に取り直す。
    await page.locator(textareaSelector).first().click({ timeout: 10000 }).catch(async () => {
      await page.locator(textareaSelector).first().focus().catch(() => {});
    });
    await page.waitForTimeout(300);
    await page.keyboard.press("Meta+Enter");

    step = "wait-response-or-confirm";
    const response = await responsePromise;
    let capturedTweetId = null;
    let capturedVia = null;
    if (response) {
      try {
        const json = await response.json();
        capturedTweetId = json?.data?.create_tweet?.tweet_results?.result?.rest_id
                       || json?.data?.notetweet_create?.tweet_results?.result?.rest_id
                       || json?.data?.tweet?.rest_id
                       || null;
        if (capturedTweetId) capturedVia = "graphql_response";
      } catch (e) { /* ignore */ }
    }

    step = "wait-textarea-clear";
    await page.waitForFunction(() => {
      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
      return !ta || ta.textContent.trim() === "";
    }, { timeout: 15000 }).catch(() => null);
    await page.waitForTimeout(2500);

    // Fallback: scrape /username with pinned skip
    // 2026-08-07 修正: 旧実装は「タイムライン先頭の非固定ツイート」を無条件に採用していた。
    // そのため投稿が失敗していても直近の無関係なツイート ID を掴んで ok:true を返し、
    // 呼び出し側 (run-publish.sh) がその URL を親として後続の返信をぶら下げ、
    // 他人のツイート配下へ誤爆した。本文の一致を必ず確認してから採用する。
    if (!capturedTweetId) {
      step = "fallback-scrape";
      await page.goto(TIMELINE_URL, { waitUntil: "domcontentloaded", timeout: 30000 });
      await page.waitForTimeout(2500);
      // 記号や空白の差で外さないよう、本文先頭を正規化した部分列で突き合わせる
      const needle = text.replace(/\s+/g, "").slice(0, 18);
      const tweetUrl = await page.$$eval(
        'article',
        (articles, args) => {
          const { username, needle } = args;
          for (const article of articles) {
            const socialContext = article.querySelector('[data-testid="socialContext"]');
            if (socialContext && /固定|Pinned/i.test(socialContext.textContent || "")) continue;
            const body = (article.innerText || "").replace(/\s+/g, "");
            if (needle && !body.includes(needle)) continue;   // 本文が一致しないものは採用しない
            const links = article.querySelectorAll('a[href*="/status/"]');
            for (const a of links) {
              const m = a.getAttribute("href").match(new RegExp(`/${username}/status/(\\d+)`, "i"));
              if (m) return m[1];
            }
          }
          return null;
        },
        { username: X_PROFILE_USERNAME, needle }
      );
      if (tweetUrl) { capturedTweetId = tweetUrl; capturedVia = "scrape_fallback_verified"; }
    }

    await page.close();
    await browser.close();

    if (!capturedTweetId) {
      out({ ok: false, step, error: "tweet posted but couldn't capture tweet ID (graphql + scrape both failed)", image_attached: imageAttached });
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
      tweet_id: capturedTweetId,
      url: `https://x.com/${X_PROFILE_USERNAME}/status/${capturedTweetId}`,
      image_attached: imageAttached,
      captured_via: capturedVia,
    });
  } catch (err) {
    if (page) try { await page.close(); } catch {}
    if (browser) try { await browser.close(); } catch {}
    out({ ok: false, step, error: err.message });
    process.exit(1);
  }
}

main();
```

## ②③ 画像を 1 枚 添付して、ALT の欄を開いた結果

```json
{
 "steps": [
  "確認ダイアログ: 保存"
 ],
 "fileInput": true,
 "attachments": [
  {
   "tag": "button",
   "testid": null,
   "aria": "メディアを編集",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "編集",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "メディアを削除",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "a",
   "testid": null,
   "aria": "タグ付けする",
   "name": null,
   "placeholder": null,
   "type": null,
   "text": "タグ付けする",
   "maxlength": null
  },
  {
   "tag": "a",
   "testid": "altTextWrapper",
   "aria": "件の説明を追加",
   "name": null,
   "placeholder": null,
   "type": null,
   "text": "件の説明を追加",
   "maxlength": null
  }
 ],
 "dialogAfterAttach": [
  {
   "tag": "button",
   "testid": "app-bar-close",
   "aria": "閉じる",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "unsentButton",
   "aria": null,
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "下書き",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "メディアを編集",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "編集",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "メディアを削除",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "a",
   "testid": null,
   "aria": "タグ付けする",
   "name": null,
   "placeholder": null,
   "type": null,
   "text": "タグ付けする",
   "maxlength": null
  },
  {
   "tag": "a",
   "testid": "altTextWrapper",
   "aria": "件の説明を追加",
   "name": null,
   "placeholder": null,
   "type": null,
   "text": "件の説明を追加",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "全員が返信できます",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "全員が返信できます",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "前",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "メディアを追加",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "input",
   "testid": "fileInput",
   "aria": null,
   "name": null,
   "placeholder": null,
   "type": "file",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "gifSearchButton",
   "aria": "GIF画像を追加",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "grokImgGen",
   "aria": "画像を生成",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "createPollButton",
   "aria": "投票を追加",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "絵文字を追加",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "scheduleOption",
   "aria": "ポストを予約",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "geoButton",
   "aria": "位置情報を追加",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "contentDisclosureButton",
   "aria": "コンテンツ開示",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "次へ",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "addButton",
   "aria": "ポストを追加",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "tweetButton",
   "aria": null,
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "ポストする",
   "maxlength": null
  }
 ],
 "clicked": "メディアを編集 編集",
 "dialogAfterClick": [
  {
   "tag": "button",
   "testid": "app-bar-back",
   "aria": "戻る",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": "endEditingButton",
   "aria": null,
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "保存",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "前",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "a",
   "testid": null,
   "aria": "メディアをトリミング",
   "name": null,
   "placeholder": null,
   "type": null,
   "text": "",
   "maxlength": null
  },
  {
   "tag": "a",
   "testid": null,
   "aria": "画像の説明を編集",
   "name": null,
   "placeholder": null,
   "type": null,
   "text": "ALT",
   "maxlength": null
  },
  {
   "tag": "a",
   "testid": null,
   "aria": "内容の警告",
   "name": null,
   "placeholder": null,
   "type": null,
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "次へ",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "縦横比: オリジナル",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "縦横比: ワイド",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  },
  {
   "tag": "button",
   "testid": null,
   "aria": "縦横比: 正方形",
   "name": null,
   "placeholder": null,
   "type": "button",
   "text": "",
   "maxlength": null
  }
 ],
 "textareas": [
  {
   "testid": "SearchBox_Search_Input",
   "name": null,
   "aria": "検索クエリ",
   "placeholder": "検索",
   "maxlength": null
  }
 ],
 "closedUrl": "https://x.com/compose/post"
}
```

画面: x263-1-attached.png x263-2-alt.png 

**投稿ボタンは触っていない。下書きは破棄した。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
