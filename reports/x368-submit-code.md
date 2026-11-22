# 送る部分のコード（2026-10-29 22:44:51 JST・$0）

## 画像投稿 150〜230 行
```
          console.error("[post-via-playwright] alt set for image " + (i + 1) + " (" + got.length + " chars)");
        }
      }
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
```

## 返信 175〜260 行
```
    }

    // --- 2026-09-26 x150: 打った文字列と欄の中身が一致するかを見る ---
    // **一致しなければ送らない。** 先頭が落ちたまま出たのが、ここで止まる。
    // 厳しすぎて取りこぼすときは **投稿が減る側に外れる**（出てしまう側ではない）。
    // そのとき want_head / got_head が出るので、推測せずに緩められる。
    {
      const _got = await page.evaluate(() => {
        const t = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
        return t ? (t.innerText || t.textContent || "") : "";
      });
      const _norm = (v) => String(v).replace(/\u200b/g, "").replace(/\s+$/g, "");
      // x247: X の入力欄は空行 1 つにつき改行を 1 つ多く返す（JAL [2/2] で 180 / 182・先頭は一致）。空白・改行は落として比べる
      const _x247sq = (v) => _norm(v).replace(/\s+/g, "");
      if (_x247sq(_got) !== _x247sq(text)) {
        out({
          ok: false, step: "text-mismatch",
          error: "欄の中身が打った文と違う。送らない",
          want_len: [..._norm(text)].length,
          got_len: [..._norm(_got)].length,
          want_head: _norm(text).slice(0, 12),
          got_head: _norm(_got).slice(0, 12),
        });
        process.exit(1);
      }
    }

    step = "arm-response-listener";
    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
    // 2026-05-15 v2: Listen for CreateTweet GraphQL response (most reliable tweet ID source)
    const responsePromise = page.waitForResponse(
      (resp) => /\/(CreateTweet|CreateNoteTweet|create_tweet)/i.test(resp.url()) && resp.request().method() === "POST",
      { timeout: 20000 }
    ).catch(() => null);

    step = "submit";
    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
    // 2026-07-13 REWRITE: button click 優先 (enabled 確認後)、 fallback で Meta+Enter
    const submitBtn = page.locator('[data-testid="tweetButtonInline"], [data-testid="tweetButton"]').first();
    let submitted = false;
    try {
      await submitBtn.waitFor({ timeout: 8000 });
      // Verify enabled — text がちゃんと React state に入ってれば aria-disabled=false
      const isDisabled = await submitBtn.evaluate(el => el.getAttribute("aria-disabled") === "true" || el.disabled).catch(() => false);
      if (!isDisabled) {
        await submitBtn.click({ timeout: 5000 });
        submitted = true;
      }
    } catch (_) {}
    // Fallback: keyboard shortcut (Meta+Enter or Ctrl+Enter)
    if (!submitted) {
      await ta.focus().catch(() => {});
      await page.waitForTimeout(200);
      await page.keyboard.press("Meta+Enter").catch(() => {});
      await page.waitForTimeout(500);
      await page.keyboard.press("Control+Enter").catch(() => {});
    }

    step = "wait-response-or-confirm";
    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
    const response = await responsePromise;
    let capturedTweetId = null;
    let capturedVia = null;
    if (response) {
      try {
        const json = await response.json();
        // X GraphQL has multiple shapes; cover the common ones
        capturedTweetId = json?.data?.create_tweet?.tweet_results?.result?.rest_id
                       || json?.data?.notetweet_create?.tweet_results?.result?.rest_id
                       || json?.data?.tweet?.rest_id
                       || null;
        if (capturedTweetId) capturedVia = "graphql_response";
      } catch (e) { /* ignore parse errors */ }
    }

    step = "wait-textarea-clear";
    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
    await page.waitForFunction(() => {
      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
      return !ta || ta.textContent.trim() === "";
    }, { timeout: 15000 }).catch(() => null);
    await page.waitForTimeout(2000);

    // If GraphQL capture failed, fall back to scraping /with_replies (smarter than v1)
    if (!capturedTweetId) {
      step = "fallback-fetch-reply-id";
```

## 最終更新
Oct 25 23:59 /Users/ny/.openclaw/workspace/scripts/post-comment.js
Oct 11 22:07 /Users/ny/.openclaw/workspace/scripts/post-via-playwright.js
