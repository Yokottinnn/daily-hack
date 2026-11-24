# 返信の 2 投稿目が落ちた原因（2026-11-24 21:53 JST・読むだけ・$0）

## 1. 11/22 CAMP の落ちた行（エラーの全文・本文は伏せる）
```
{"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"MuOAnDPkurrjga7ntYTjgafmnIjjgpLlj5fjgZHmjIHjgaPjgabjgIHmnIDlvozjgavnmbrooajkvJrjgb7jgafjgYLjgovjga7jgILmjIHj
gaHnianjgajooYzjgY3mlrnjga/jgZPjgZPjgavjgb7jgajjgoHjgZ/jgo/jgIIKaHR0cHM6Ly9kYWlseS1oYWNrLmZpZWxkYmVzaWRlLmNvbS9wb3N0cy9zY3NrLWNhbXAta295b21pLXdvcmtzaG9wLTIwMjYv\" \"https://x.com/heng_ji31590/status/2124340481173975432\"
 \"null\"\n[x-action-pacer] tweet: 空いた\n[step] connect t=0ms\n[step] navigate-target t=2651ms\n[step] find-reply-textarea t=8918ms\n[textarea] found via primary sel: div[data-testid^=\"tweetTextarea_\"][contenteditable=\"tr
ue\"] t=8961ms\n[step] type-text t=8961ms\n[x154] like 付いた\n","child_stdout":"{\"ok\":false,\"step\":\"text-mismatch\",\"error\":\"欄の中身が打った文と違う。送らない\",\"want_len\":117,\"got_len\":0,\"want_head\":\"2〜3人の組で月を受け持\",\"got_head\":\"\"}\n","child_stderr":
"[x-action-pacer] tweet: 空いた\n[step] connect t=0ms\n[step] navigate-target t=2651ms\n[step] find-reply-textarea t=8918ms\n[textarea] found via primary sel: div[data-testid^=\"tweetTextarea_\"][contenteditable=\"true\"] t=89
61ms\n[step] type-text t=8961ms\n[x154] like 付いた\n","thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2124340481173975432","url":"https://x.com/heng_ji31590/status/2124340481173975432","image_attached":true,"
captured_via":"graphql_response"}]}
{"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"MuOAnDPkurrjga7ntYTjgafmnIjjgpLlj5fjgZHmjIHjgaPjgabjgIHmnIDlvozjgavnmbrooajkvJrjgb7jgafjgYLjgovjga7jgILmjIHj
gaHnianjgajooYzjgY3mlrnjga/jgZPjgZPjgavjgb7jgajjgoHjgZ/jgo/jgIIKaHR0cHM6Ly9kYWlseS1oYWNrLmZpZWxkYmVzaWRlLmNvbS9wb3N0cy9zY3NrLWNhbXAta295b21pLXdvcmtzaG9wLTIwMjYv\" \"https://x.com/heng_ji31590/status/2124340963200086271\"
 \"null\"\n[x-action-pacer] tweet: 空いた\n[step] connect t=0ms\n[step] navigate-target t=2338ms\n[step] find-reply-textarea t=8587ms\n[textarea] found via primary sel: div[data-testid^=\"tweetTextarea_\"][contenteditable=\"tr
ue\"] t=11526ms\n[step] type-text t=11527ms\n[x154] like 付いた\n","child_stdout":"{\"ok\":false,\"step\":\"type-text\",\"error\":\"elementHandle.click: Element is not attached to the DOM\\nCall log:\\n  - attempting click act
ion\\n    - waiting for element to be visible, enabled and stable\\n\"}\n","child_stderr":"[x-action-pacer] tweet: 空いた\n[step] connect t=0ms\n[step] navigate-target t=2338ms\n[step] find-reply-textarea t=8587ms\n[textarea] 
found via primary sel: div[data-testid^=\"tweetTextarea_\"][contenteditable=\"true\"] t=11526ms\n[step] type-text t=11527ms\n[x154] like 付いた\n","thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"21243409632000
86271","url":"https://x.com/heng_ji31590/status/2124340963200086271","image_attached":true,"captured_via":"graphql_response"}]}
```

## 2. 通った 11/23 イルミの同じ所
```
[step] type-text t=6764ms
[x154] like 付いた
[step] arm-response-listener t=9950ms
[step] submit t=9951ms
```

## 3. post-comment.js の、本文を確かめるところ（mismatch・got_len・attached・x154・like）
```
-rw-r--r--  1 ny  staff  19375 Oct 25 23:59 ~/.openclaw/workspace/scripts/post-comment.js
95:    step = "type-text";
97:    // --- 2026-09-26 x154: 返信する相手の投稿に「いいね」も付ける ---
102:        const _x154art = await page.$('article[data-testid="tweet"]');
103:        if (!_x154art) {
104:          console.error("[x154] article が無い。いいねは飛ばす");
105:        } else if (await _x154art.$('[data-testid="unlike"]')) {
106:          console.error("[x154] すでに いいね済み。触らない");
108:          const _x154btn = await _x154art.$('[data-testid="like"]');
109:          if (!_x154btn) {
110:            console.error("[x154] like ボタンが無い");
112:            await _x154btn.click();
115:            const _x154ok = await page.waitForSelector('article[data-testid="tweet"] [data-testid="unlike"]', { timeout: 6000 })
117:            console.error("[x154] like " + (_x154ok ? "付いた" : "**付いていない**"));
121:        console.error("[x154] like で例外（返信は続ける）: " + String((e && e.message) || e).slice(0, 120));
145:    // 2026-07-13 REWRITE: insertText は JS 直接注入で React onChange 発火せず → submit button disabled のまま
146:    //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
147:    await page.keyboard.type(text, { delay: 4 });
184:        return t ? (t.innerText || t.textContent || "") : "";
191:          ok: false, step: "text-mismatch",
194:          got_len: [..._norm(_got)].length,
254:      return !ta || ta.textContent.trim() === "";
279:            if (sc && /固定|Pinned/i.test(sc.textContent || "")) continue;
280:            const body = (article.innerText || "").replace(/\s+/g, "");
318:          if (/返信先|Replying to/i.test(el.textContent || "")) return true;
346:        detached: true, stdio: "ignore", env: process.env,
```

## 4. mismatch の前後
```
        console.error("[x154] like で例外（返信は続ける）: " + String((e && e.message) || e).slice(0, 120));
      }
    }

    // --- 2026-09-26 x150: 打つ前に「どこに打つのか」を確かめる ---
    // 2026-09-25 に、返信のつもりが単独投稿になり、しかも先頭 2 文字が落ちた
    // （「アタシも…」→「シも…」）。原因は 2 つとも ここに在った。
    //   ① ページが目的の status から離れていても、そのまま打っていた
    //   ② click の後 400ms 待つだけで、フォーカスが載る前に delay:4 で打ち始めていた
    const _x150want = String(targetUrl || "").match(/status\/(\d+)/);
    if (_x150want && !page.url().includes(_x150want[1])) {
      out({ ok: false, step: "wrong-page", error: "返信先のページに居ない: url=" + page.url().slice(0, 120) });
      process.exit(1);
    }
    await ta.click();
    // **400ms の固定待ちをやめる。** カーソルが本当に載るまで待つ
    const _x150focus = await page.waitForFunction(() => {
      const a = document.activeElement;
      return !!a && a.getAttribute && a.getAttribute("contenteditable") === "true";
    }, { timeout: 8000 }).catch(() => null);
    if (!_x150focus) {
      out({ ok: false, step: "no-focus", error: "入力欄にフォーカスが載らない（打たずに止まる）" });
      process.exit(1);
    }
    // 2026-07-13 REWRITE: insertText は JS 直接注入で React onChange 発火せず → submit button disabled のまま
    //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
    await page.keyboard.type(text, { delay: 4 });
    await page.waitForTimeout(1500);

    // 2026-09-23: **reply にも画像を付けられるようにした。**
    // run-publish.sh が chain[i].image_path を第 3 引数で渡してくる（i>=1 の reply）。
    // これが無かったため、スキーマに image_path? と書いてあっても
    // **エラーも出さずに画像だけ消えていた**（x134 のガードが投稿前に止めた）。
    const imagePaths = (imageArg && imageArg !== "null")
      ? imageArg.split(",").map((q) => q.trim()).filter(Boolean) : [];
    if (imagePaths.length) {
      step = "attach-image";
      console.error("[step] " + step + " n=" + imagePaths.length + " t=" + ((Date.now()-t0)|0) + "ms");
      if (imagePaths.length > 4) { out({ ok: false, step, error: "X allows max 4 images, got " + imagePaths.length }); process.exit(1); }
      const missing = imagePaths.filter((q) => !require("fs").existsSync(q));
      if (missing.length) { out({ ok: false, step, error: "image not found: " + missing.join(",") }); process.exit(1); }
      // post-via-playwright.js:44-47 と同じ取り方
      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
      if (!fileInput) fileInput = await page.$('input[type="file"]');
      if (!fileInput) { out({ ok: false, step, error: "file input not found on reply composer" }); process.exit(1); }
      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
      // **付いたことを確かめてから送信する。** setInputFiles は投げるだけで待たない。
      // 確かめずに送ると**画像なしで出る**——防ぎたいのはまさにそれ
      const attached = await page.waitForSelector(
        '[data-testid="attachments"], [data-testid="media"] img, [data-testid="removeMedia"]',
        { timeout: 25000 }
      ).catch(() => null);
      if (!attached) { out({ ok: false, step, error: "attachment did not appear - 画像なしでは出さない" }); process.exit(1); }
      await page.waitForTimeout(1500);
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
```

## 5. x154（いいね）を呼ぶところ
```
~/.openclaw/workspace/scripts/post-comment.js
~/.openclaw/workspace/scripts/post-comment.js.bak-x352
~/.openclaw/workspace/scripts/post-comment.js.bak-x247-20261004-200941
94-
95-    step = "type-text";
96-    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
97:    // --- 2026-09-26 x154: 返信する相手の投稿に「いいね」も付ける ---
98-    // **おまけ。押せなくても返信は止めない。** 止めるのは x150 の 3 つのガードだけ。
99-    // REPLY_LIKE=off で無効にできる。すでに押してあるなら触らない（解除してしまう）
100-    if ((process.env.REPLY_LIKE || "on") !== "off") {
101-      try {
102:        const _x154art = await page.$('article[data-testid="tweet"]');
103:        if (!_x154art) {
104:          console.error("[x154] article が無い。いいねは飛ばす");
105:        } else if (await _x154art.$('[data-testid="unlike"]')) {
106:          console.error("[x154] すでに いいね済み。触らない");
107-        } else {
108:          const _x154btn = await _x154art.$('[data-testid="like"]');
109:          if (!_x154btn) {
110:            console.error("[x154] like ボタンが無い");
111-          } else {
112:            await _x154btn.click();
113-            // **押した結果を見る。** rc も「押せた」も証拠にならない（最上位ルール 13）
114-            // **page 側で待つ。** ElementHandle.waitForSelector は版で挙動が違う
115:            const _x154ok = await page.waitForSelector('article[data-testid="tweet"] [data-testid="unlike"]', { timeout: 6000 })
116-              .then(() => true).catch(() => false);
117:            console.error("[x154] like " + (_x154ok ? "付いた" : "**付いていない**"));
118-          }
119-        }
120-      } catch (e) {
121:        console.error("[x154] like で例外（返信は続ける）: " + String((e && e.message) || e).slice(0, 120));
122-      }
123-    }
124-
125-    // --- 2026-09-26 x150: 打つ前に「どこに打つのか」を確かめる ---
126-    // 2026-09-25 に、返信のつもりが単独投稿になり、しかも先頭 2 文字が落ちた
127-    // （「アタシも…」→「シも…」）。原因は 2 つとも ここに在った。
128-    //   ① ページが目的の status から離れていても、そのまま打っていた
129-    //   ② click の後 400ms 待つだけで、フォーカスが載る前に delay:4 で打ち始めていた
130-    const _x150want = String(targetUrl || "").match(/status\/(\d+)/);
131-    if (_x150want && !page.url().includes(_x150want[1])) {
132-      out({ ok: false, step: "wrong-page", error: "返信先のページに居ない: url=" + page.url().slice(0, 120) });
133-      process.exit(1);
```

## 6. 2 投稿目の本文の頭（CAMP とイルミ・キューから）
```
x-blog-20261122-camp-koyomi len=117 先頭="2〜3人の組で月を受け持って、最後に発表会まであるの。持ち物" 改行=1 URL=true
x-blog-20261123-wangan-illumination len=119 先頭="入場料と点く時間は会場ごとに違うの。クリスマスマーケットは平" 改行=1 URL=true
x-blog-20261125-cruise-ranking len=136 先頭="湾岸の東京は14位の82回。全国では3,116回で、前年の約" 改行=3 URL=true
```

**読むだけ。LLM 不使用（$0）。**
