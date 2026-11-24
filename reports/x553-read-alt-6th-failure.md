# ALT の 6 枚目で落ちた原因（2026-11-24 22:40 JST・読むだけ・$0）

## 1. エラーの全文（1 回目）
```
{"ok":false,"step":"thread-main-exec","error":"Command failed: /usr/local/bin/node scripts/post-via-playwright.js <本文> \"/Users/ny/.openclaw/workspace/data/x-tokyo-christmas-market-hikaku-2026/1-officia
l.jpg,/Users/ny/.openclaw/workspace/data/x-tokyo-christmas-market-hikaku-2026/2-compare.jpg,/Users/ny/.openclaw/workspace/data/x-tokyo-christmas-market-hikaku-2026/3-mugs.jpg,/Users/ny/.openclaw/works
pace/data/x-tokyo-christmas-market-hikaku-2026/4-free.jpg,/Users/ny/.openclaw/workspace/data/x-tokyo-christmas-market-hikaku-2026/5-shiba.jpg,/Users/ny/.openclaw/workspace/data/x-tokyo-christmas-marke
t-hikaku-2026/6-roppongi.jpg,/Users/ny/.openclaw/workspace/data/x-tokyo-christmas-market-hikaku-2026/7-azabudai.jpg,/Users/ny/.openclaw/workspace/data/x-tokyo-christmas-market-hikaku-2026/8-skytree.jp
g,/Users/ny/.openclaw/workspace/data/x-tokyo-christmas-market-hikaku-2026/9-ueno.jpg,/Users/ny/.openclaw/workspace/data/x-tokyo-christmas-market-hikaku-2026/10-marunouchi.jpg\"\n[post-via-playwright] 
attached 10/10 image(s)\n[post-via-playwright] alt set for image 1 (126 chars)\n[post-via-playwright] alt set for image 2 (313 chars)\n[post-via-playwright] alt set for image 3 (126 chars)\n[post-via-
playwright] alt set for image 4 (138 chars)\n[post-via-playwright] alt set for image 5 (151 chars)\n","child_stdout":"（at=4） thumbs=[\\\"blob:https://x.com/404da6b0-abd8-49dd-8488-898ec0e3ffbe\\\",\\\"b
lob:https://x.com/0666d51a-46ca-460e-b8e1-59e9f1f85950\\\",\\\"blob:https://x.com/7daec3e3-5900-4834-85e9-2ccbf97778a9\\\",\\\"blob:https://x.com/698a9358-67d4-49bc-912b-aacf3a79313f\\\",\\\"blob:http
s://x.com/97046c34-b699-48fd-a9f7-1808e95d3fca\\\",\\\"blob:https://x.com/776d63db-6b18-4ec0-9339-6ab1a95f643b\\\",\\\"blob:https://x.com/2d89a2da-ddb2-4b6a-8e21-57b135fad2bc\\\",\\\"blob:https://x.co
m/624c515f-8b3f-42d5-a4bb-78d580e971f9\\\",\\\"blob:https://x.com/869cc0c4-5e33-4ed1-84e8-2a3a06395437\\\",\\\"blob:https://x.com/530b1deb-7482-458b-aff6-9a1625c26d64\\\"] dialog_imgs=[\\\"blob:https:
//x.com/97046c34-b699-48fd-a9f7-1808e95d3fca 550x434\\\"]\"}\n","child_stderr":"[post-via-playwright] attached 10/10 image(s)\n[post-via-playwright] alt set for image 1 (126 chars)\n[post-via-playwrig
ht] alt set for image 2 (313 chars)\n[post-via-playwright] alt set for image 3 (126 chars)\n[post-via-playwright] alt set for image 4 (138 chars)\n[post-via-playwright] alt set for image 5 (151 chars)
\n","thread_results":[]}
```

## 2. ALT を入れるところ（前後）
```
-rw-r--r--  1 ny  staff  15978 Nov 22 13:16 ~/.openclaw/workspace/scripts/post-via-playwright.js
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

      // 2026-10-11 x264: 画像の説明（ALT）。ALT_TEXTS_FILE（JSON 配列）があれば、i 枚目に alts[i] を入れる（空ならその画像は飛ばす）。
      // CC BY / CC BY-SA の撮影者名を ALT に書く運用（CLAUDE.md 最上位ルール 8）。**入れられなければ投稿しない**（throw → 投稿ボタンを押さない）。
      // 画面の作りは x263 で実物を読んだ: 添付ごとの [data-testid="altTextWrapper"] → 編集画面の textarea → [data-testid="endEditingButton"]
      if (process.env.ALT_TEXTS_FILE) {
        step = "alt-text";
        const alts = JSON.parse(fs.readFileSync(process.env.ALT_TEXTS_FILE, "utf8"));
        for (let i = 0; i < alts.length; i++) {
          if (!alts[i]) continue;
          // 2026-10-11 x265: 複数枚を添付すると altTextWrapper は 1 個にまとまる（x264 で実測）。
          // そのときは押して編集画面を開き「次の画像」で i 枚目まで送る（2026-11-05 x425: 「次へ」は編集画面ではいつも押せず、2 枚目以降で必ず落ちていた・x424�
          const thumbs = await page.$$eval('[data-testid="attachments"] img', (xs) => xs.map((x) => x.getAttribute("src") || ""));
          const wrappers = page.locator('[data-testid="attachments"] [data-testid="altTextWrapper"]');
          const n = await wrappers.count();
          if (n === 0) throw new Error("altTextWrapper が無い");
          await wrappers.nth(n > i ? i : 0).click();
          await page.waitForTimeout(2500);
          const curIndex = async () => {
            const srcs = await page.$$eval('[role="dialog"] img', (xs) => xs.filter((x) => x.offsetWidth > 120 && x.offsetHeight > 120).map((x) => x.getAttribute("src") || ""));
            for (const sv of srcs) { const k = thumbs.indexOf(sv); if (k >= 0) return k; }
            return -1;
          };
          let at = await curIndex();
          for (let guard = 0; at !== i && guard < 4; guard++) {
            const nx = page.locator('[role="dialog"]:has([data-testid="endEditingButton"]) [aria-label="次の画像"]:not([aria-disabled="true"])').last();
            if (!(await nx.count())) break;
            await nx.click(); await page.waitForTimeout(1500);
            at = await curIndex();
          }
          if (at !== i) {
            const dbg = await page.$$eval('[role="dialog"] img', (xs) => xs.map((x) => (x.getAttribute("src") || "").slice(0, 60) + " " + x.offsetWidth + "x" + x.offsetHeight));
            throw new Error("編集画面で " + (i + 1) + " 枚目を特定できない（at=" + at + "） thumbs=" + JSON.stringify(thumbs.map((t) => t.slice(0, 60))) + " dialog_imgs=" + JSON.stringify(dbg));
          }
          let box = page.locator('[role="dialog"] textarea').first();
          if (!(await box.count())) {
            await page.locator('[role="dialog"] a[aria-label="画像の説明を編集"]').first().click().catch(() => {});
            await page.waitForTimeout(1500);
            box = page.locator('[role="dialog"] textarea').first();
          }
          if (!(await box.count())) throw new Error("ALT の入力欄が見つからない（" + (i + 1) + " 枚目）");
          await box.fill(alts[i]);
          await page.waitForTimeout(500);
          const got = await box.inputValue();
          if (got.replace(/\s/g, "") !== String(alts[i]).replace(/\s/g, "")) throw new Error("ALT が入りきらない（" + (i + 1) + " 枚目） got_len=" + got.length + " want_len=" + alts[i].length);
          const save = page.locator('[role="dialog"] [data-testid="endEditingButton"]').first();
          if (!(await save.count())) throw new Error("ALT の保存ボタンが無い");
          await save.click();
          await page.waitForTimeout(1500);
          console.error("[post-via-playwright] alt set for image " + (i + 1) + " (" + got.length + " chars)");
        }
      }
    }

    // 2026-05-15 v3: arm GraphQL response listener BEFORE submit
```

## 3. 6 枚・10 枚でテストしたとき（x538・x539）の ALT
```
```

**読むだけ。LLM 不使用（$0）。**
