# `comment-warmup` の投稿経路（2026-09-26 16:21 JST・$0）

**このレポートが作られた時刻: 2026-09-26 16:21:26 JST**

> **読むだけ。書き換えていない。ループも戻していない。**
> 症状は 2 つ。**先頭 2 文字の欠落**と**親が付かないこと。**

## 1. plist（`.disabled` でも中身は読める）

読んだファイル: `ai.openclaw.comment-warmup.plist.disabled`

```
  Dict {
      ProgramArguments = Array {
          /bin/bash
          /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh
      }
      StandardErrorPath = /Users/ny/.openclaw/workspace/logs/comment-warmup-err.log
      Label = ai.openclaw.comment-warmup
      StandardOutPath = /Users/ny/.openclaw/workspace/logs/comment-warmup.log
      StartCalendarInterval = Array {
          Dict {
              Hour = 16
              Minute = 0
          }
          Dict {
              Hour = 12
              Minute = 0
          }
          Dict {
              Hour = 22
              Minute = 0
          }
          Dict {
              Hour = 19
              Minute = 0
          }
      }
      EnvironmentVariables = Dict {
          MIN_LIKES = 2
          MAX_AGE_HOURS = 18
          MAX_PICKS_PER_FIRE = 6
          REPLY_FOLLOW_DAILY_CAP = 30
      }
  }
```

## 2. 入口のスクリプトは、どこへ投稿を投げているか

- **入口が見つからない。**

```
  asuka-gen.js.bak.20260712-comment-variety-off
  comment-orchestrator.sh
  comment-orchestrator.sh.bak-20260913-204446
  comment-orchestrator.sh.bak-20260913-210115
  comment-orchestrator.sh.bak.20260510-180212
  comment-orchestrator.sh.bak.20260511-172448
  comment-orchestrator.sh.bak.20260513-followE
  comment-orchestrator.sh.bak.20260518-auto-reply
  comment-orchestrator.sh.bak.20260606-eplan-revive
  comment-orchestrator.sh.bak.20260705-approval-required
  comment-orchestrator.sh.bak.20260705-user-clarify
  comment-orchestrator.sh.bak.20260906-205207
  comment-orchestrator.sh.new
  comment-orchestrator.sh.pre-ngfilter.20260827-133807
  comment-orchestrator.sh.pre-tonegate.20260828-155126
  comment-state.js
  post-comment.js
  post-comment.js.bak-20260923-210640
  post-comment.js.bak.1778638034983
  post-comment.js.bak.20260515-graphql
  post-comment.js.bak.20260531-pinned-jp
  post-comment.js.bak.20260609
  post-comment.js.bak.20260612-textsafety
  post-comment.js.bak.20260705-textarea-selector
  post-comment.js.bak.20260712-goto-fix
  post-comment.js.bak.20260713-fork-rewrite
  post-comment.js.bak.20260719-goto-domcontentloaded
  post-comment.js.bak.20260720-layer2
  post-comment.js.bak.20260725-textarea-fix
  post-comment.js.bak.20260809
  post-comment.js.bak.pinfix.1778638096810
  post-comment.js.bak18800
  run-comment.sh
```

## 3. `x136` のパッチは経路に入っているか（**先に自分を疑う**）

```
  post-comment.js       292 行  更新 2026-09-23 21:06:40
  imageArg の有無        3 箇所
  setInputFiles の有無   2 箇所

  --- バックアップ（x136 が取ったもの）---
  /Users/ny/.openclaw/workspace/scripts/post-comment.js.bak-20260923-210640
```

**パッチは入っている。** 本文を打つ前後を通しで見る（**ここが本命**）:

```javascript
  60	        ta = await page.waitForSelector(sel, { timeout: 6000 });
  74	            ta = await page.waitForSelector(sel, { timeout: 5000 });
  98	    // 2026-07-13 REWRITE: insertText は JS 直接注入で React onChange 発火せず → submit button disabled のまま
  99	    //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
  100	    await page.keyboard.type(text, { delay: 4 });
  107	    const imagePaths = (imageArg && imageArg !== "null")
  109	    if (imagePaths.length) {
  111	      console.error("[step] " + step + " n=" + imagePaths.length + " t=" + ((Date.now()-t0)|0) + "ms");
  112	      if (imagePaths.length > 4) { out({ ok: false, step, error: "X allows max 4 images, got " + imagePaths.length }); process.exit(1); }
  113	      const missing = imagePaths.filter((q) => !require("fs").existsSync(q));
  119	      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
  120	      // **付いたことを確かめてから送信する。** setInputFiles は投げるだけで待たない。
  122	      const attached = await page.waitForSelector(
  123	        '[data-testid="attachments"], [data-testid="media"] img, [data-testid="removeMedia"]',
```

**画像が無いとき（`imageArg` が無い／`"null"`）に添付処理を飛ばしているか:**

```javascript
  104-    // run-publish.sh が chain[i].image_path を第 3 引数で渡してくる（i>=1 の reply）。
  105-    // これが無かったため、スキーマに image_path? と書いてあっても
  106-    // **エラーも出さずに画像だけ消えていた**（x134 のガードが投稿前に止めた）。
  107:    const imagePaths = (imageArg && imageArg !== "null")
  108-      ? imageArg.split(",").map((q) => q.trim()).filter(Boolean) : [];
  109:    if (imagePaths.length) {
  110-      step = "attach-image";
  111:      console.error("[step] " + step + " n=" + imagePaths.length + " t=" + ((Date.now()-t0)|0) + "ms");
  112:      if (imagePaths.length > 4) { out({ ok: false, step, error: "X allows max 4 images, got " + imagePaths.length }); process.exit(1); }
  113:      const missing = imagePaths.filter((q) => !require("fs").existsSync(q));
  114-      if (missing.length) { out({ ok: false, step, error: "image not found: " + missing.join(",") }); process.exit(1); }
  115-      // post-via-playwright.js:44-47 と同じ取り方
  116-      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
  117-      if (!fileInput) fileInput = await page.$('input[type="file"]');
  118-      if (!fileInput) { out({ ok: false, step, error: "file input not found on reply composer" }); process.exit(1); }
  119:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
  120-      // **付いたことを確かめてから送信する。** setInputFiles は投げるだけで待たない。
  121-      // 確かめずに送ると**画像なしで出る**——防ぎたいのはまさにそれ
  122-      const attached = await page.waitForSelector(
  123-        '[data-testid="attachments"], [data-testid="media"] img, [data-testid="removeMedia"]',
  124-        { timeout: 25000 }
  125-      ).catch(() => null);
  126-      if (!attached) { out({ ok: false, step, error: "attachment did not appear - 画像なしでは出さない" }); process.exit(1); }
  127-      await page.waitForTimeout(1500);
  128-    }
  129-
  130-    step = "arm-response-listener";
  131-    console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
```

## 4. 打ち込みと返信先の作り（**経路にあるスクリプト全部**）

### `post-comment.js`

**フォーカスを載せてから打っているか**（`click` → `type` の順と待ち）:

```javascript
  44:    await page.waitForTimeout(6000);
  49:    // primary: tweetTextarea_0 (inline compose、 常時表示 bar)
  52:      'div[data-testid^="tweetTextarea_"][contenteditable="true"]',
  53:      'div[data-testid="tweetTextarea_0"]',
  60:        ta = await page.waitForSelector(sel, { timeout: 6000 });
  70:        await replyBtn.click().catch((e)=>{ console.error("[reply-click-err]", e.message.slice(0,60)); });
  71:        await page.waitForTimeout(4000);
  74:            ta = await page.waitForSelector(sel, { timeout: 5000 });
  96:    await ta.click();
  97:    await page.waitForTimeout(400);
  99:    //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
  100:    await page.keyboard.type(text, { delay: 4 });
  101:    await page.waitForTimeout(1500);
  122:      const attached = await page.waitForSelector(
  127:      await page.waitForTimeout(1500);
  154:      await ta.focus().catch(() => {});
  155:      await page.waitForTimeout(200);
  156:      await page.keyboard.press("Meta+Enter").catch(() => {});
  157:      await page.waitForTimeout(500);
  158:      await page.keyboard.press("Control+Enter").catch(() => {});
  181:      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
  184:    await page.waitForTimeout(2000);
  191:      await page.waitForTimeout(4000);
  238:      await verifyPage.waitForTimeout(4000);
```

### `post-via-playwright.js`

**フォーカスを載せてから打っているか**（`click` → `type` の順と待ち）:

```javascript
  55:    await page.waitForTimeout(5000);
  56:    const textareaSelector = 'div[data-testid^="tweetTextarea_"][contenteditable="true"]';
  57:    await page.waitForSelector(textareaSelector, { timeout: 30000 });
  61:    await ta.click();
  63:    await page.waitForTimeout(800);
  91:        await page.waitForTimeout(2000);
  100:      await page.waitForTimeout(1500);
  135:      await page.locator(textareaSelector).first().focus().catch(() => {});
  137:    await page.waitForTimeout(300);
  138:    await page.keyboard.press("Meta+Enter");
  157:      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
  160:    await page.waitForTimeout(2500);
  170:      await page.waitForTimeout(2500);
```


## 5. 壊れた 1 件の周辺（**同じ周回で何が起きていたか**）

```
  7637-[2026-09-25T12:04:27]   → chosen template_id: unknown
  7638-[2026-09-25T12:04:27] enqueue: {"ok":true,"id":"comment-20260925-1204-5"}
  7639-{"ok":true,"entry_id":"comment-20260925-1204-5","x_tweet_id":"2103319741570159043","url":"https://x.com/heng_ji31590/status/2103319741570159043","slack_report_ts":"silenced"}
  7640-[2026-09-25T12:04:46]   follow @<伏せ>: followed
  7641-[2026-09-25T12:04:46]   recorded in reply-followers.json (count now 10/30)
  7642-[2026-09-25T12:04:46] === orchestrator done: 6 drafts, 10 reply-connected follows today ===
  7643-[2026-09-25T16:00:05] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
  7644-[2026-09-25T16:03:07] picked 6 / max 6 (from 16 candidates)
  7645-[2026-09-25T16:03:07] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
  7646-[2026-09-25T16:03:07] today's reply-connected follows: 10 / 30
  7647-[2026-09-25T16:03:07] --- processing #1/6 for @<伏せ> ---
  7648-[2026-09-25T16:03:09] gen failed (#1): {"ok":false,"error":"生成側が skip: 投稿の内容が不明確。「おやつ代凸」「引用元の♻️で金額⤴︎」が何を指しているのか、PayPayでの具体的な出来事が読み取れな�
  7649-[2026-09-25T16:03:10] --- processing #2/6 for @<伏せ> ---
  7650-[2026-09-25T16:03:11]   → chosen template_id: unknown
  7651-[2026-09-25T16:03:12] enqueue: {"ok":true,"id":"comment-20260925-1603-1"}
  7652-{"ok":true,"entry_id":"comment-20260925-1603-1","x_tweet_id":"2103379824509427714","url":"https://x.com/heng_ji31590/status/2103379824509427714","slack_report_ts":"silenced"}
  7653-[2026-09-25T16:03:26]   follow @<伏せ>: skipped (already in reply-followers.json)
  7654-[2026-09-25T16:03:26] --- processing #3/6 for @<伏せ> ---
  7655-[2026-09-25T16:03:28]   → chosen template_id: unknown
  7656-[2026-09-25T16:03:28] enqueue: {"ok":true,"id":"comment-20260925-1603-2"}
  7657:{"ok":true,"entry_id":"comment-20260925-1603-2","x_tweet_id":"2103379894306750770","url":"https://x.com/heng_ji31590/status/2103379894306750770","slack_report_ts":"silenced"}
  7658-[2026-09-25T16:03:46]   follow @<伏せ>: already_following
  7659-[2026-09-25T16:03:46] --- processing #4/6 for @<伏せ> ---
  7660-[2026-09-25T16:03:48]   → chosen template_id: unknown
  7661-[2026-09-25T16:03:48] enqueue: {"ok":true,"id":"comment-20260925-1603-3"}
  7662-{"ok":true,"entry_id":"comment-20260925-1603-3","x_tweet_id":"2103379978041868488","url":"https://x.com/heng_ji31590/status/2103379978041868488","slack_report_ts":"silenced"}
  7663-[2026-09-25T16:04:06]   follow @<伏せ>: filtered
  7664-[2026-09-25T16:04:06] --- processing #5/6 for @<伏せ> ---
  7665-[2026-09-25T16:04:09]   → chosen template_id: unknown
  7666-[2026-09-25T16:04:09] enqueue: {"ok":true,"id":"comment-20260925-1604-4"}
  7667-{"ok":true,"entry_id":"comment-20260925-1604-4","x_tweet_id":"2103380064574624215","url":"https://x.com/heng_ji31590/status/2103380064574624215","slack_report_ts":"silenced"}
  7668-[2026-09-25T16:04:26]   follow @<伏せ>: filtered
  7669-[2026-09-25T16:04:27] --- processing #6/6 for @<伏せ> ---
  7670-[2026-09-25T16:04:29]   → chosen template_id: unknown
  7671-[2026-09-25T16:04:29] enqueue: {"ok":true,"id":"comment-20260925-1604-5"}
  7672-{"ok":true,"entry_id":"comment-20260925-1604-5","x_tweet_id":"2103380148703928347","url":"https://x.com/heng_ji31590/status/2103380148703928347","slack_report_ts":"silenced"}
  7673-[2026-09-25T16:04:46]   follow @<伏せ>: filtered
  7674-[2026-09-25T16:04:46] === orchestrator done: 6 drafts, 10 reply-connected follows today ===
  7675-[2026-09-25T19:00:05] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
  7676-[2026-09-25T19:03:07] picked 6 / max 6 (from 8 candidates)
  7677-[2026-09-25T19:03:07] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
```

同じ周回のエラー側（`-err.log` の末尾）:

```
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  post attempt 1 failed, retrying in 10s... {
    ok: false,
    error: 'Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/post-comment.js "6IKJ54up44KK44Gu5b6M44Kz44O844Op44Gn5LqL5YuZ44CB44GE44GE44Kz44Oz44Oc44Gt44CC44Gn44CB44CO5b2T44Gf44KK44Gu5pel44CP44Gj44Gm5L2V44GM5b2T44Gf44Gj44Gf44Gu77yf6IKJ44G
      '[step] connect t=0ms\n' +
      '[step] navigate-target t=721ms\n' +
      '[step] find-reply-textarea t=6865ms\n' +
      '[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6921ms\n' +
      '[step] type-text t=6921ms\n' +
      '[step] arm-response-listener t=9855ms\n' +
      '[step] submit t=9858ms\n' +
      '[step] wait-response-or-confirm t=18604ms\n' +
      '[step] wait-textarea-clear t=29862ms\n' +
      '[step] fallback-fetch-reply-id t=31879ms\n',
    stderr: '[step] connect t=0ms\n' +
      '[step] navigate-target t=721ms\n' +
      '[step] find-reply-textarea t=6865ms\n' +
      '[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6921ms\n' +
      '[step] type-text t=6921ms\n' +
      '[step] arm-response-listener t=9855ms\n' +
      '[step] submit t=9858ms\n' +
      '[step] wait-response-or-confirm t=18604ms\n' +
      '[step] wait-textarea-clear t=29862ms\n' +
      '[step] fallback-fetch-reply-id t=31879ms'
  }
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
  [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
```

---

## 読み方（**このタスクでは直さない**）

| 出方 | 何が起きているか |
| --- | --- |
| `click` の直後に待ちなしで `keyboard.type` | **フォーカスが載る前に打ち始めている。** 先頭欠落の定番 |
| 返信先の URL を組んでいない／空で渡している | **本体の投稿欄に打っている。** 親が付かない理由 |
| `imagePaths` が空でも添付処理に入る | **`x136` が犯人。** 本文の直後で例外かフォーカス奪取 |
| `post-comment.js` を通っていない | `x136` は無関係。**別の投稿口を読む** |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
