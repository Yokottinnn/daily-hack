# post-comment.js の text-mismatch（2026-10-04 20:06:30 JST・$0）

- 361 行・更新 09/26 23:30

## ① 比較の前後

```javascript
 138        return !!a && a.getAttribute && a.getAttribute("contenteditable") === "true";
 139      }, { timeout: 8000 }).catch(() => null);
 140      if (!_x150focus) {
 141        out({ ok: false, step: "no-focus", error: "入力欄にフォーカスが載らない（打たずに止まる）" });
 142        process.exit(1);
 143      }
 144      // 2026-07-13 REWRITE: insertText は JS 直接注入で React onChange 発火せず → submit button disabled のまま
 145      //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
 146      await page.keyboard.type(text, { delay: 4 });
 147      await page.waitForTimeout(1500);
 148  
 149      // 2026-09-23: **reply にも画像を付けられるようにした。**
 150      // run-publish.sh が chain[i].image_path を第 3 引数で渡してくる（i>=1 の reply）。
 151      // これが無かったため、スキーマに image_path? と書いてあっても
 152      // **エラーも出さずに画像だけ消えていた**（x134 のガードが投稿前に止めた）。
 153      const imagePaths = (imageArg && imageArg !== "null")
 154        ? imageArg.split(",").map((q) => q.trim()).filter(Boolean) : [];
 155      if (imagePaths.length) {
 156        step = "attach-image";
 157        console.error("[step] " + step + " n=" + imagePaths.length + " t=" + ((Date.now()-t0)|0) + "ms");
 158        if (imagePaths.length > 4) { out({ ok: false, step, error: "X allows max 4 images, got " + imagePaths.length }); process.exit(1); }
 159        const missing = imagePaths.filter((q) => !require("fs").existsSync(q));
 160        if (missing.length) { out({ ok: false, step, error: "image not found: " + missing.join(",") }); process.exit(1); }
 161        // post-via-playwright.js:44-47 と同じ取り方
 162        let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
 163        if (!fileInput) fileInput = await page.$('input[type="file"]');
 164        if (!fileInput) { out({ ok: false, step, error: "file input not found on reply composer" }); process.exit(1); }
 165        await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
 166        // **付いたことを確かめてから送信する。** setInputFiles は投げるだけで待たない。
 167        // 確かめずに送ると**画像なしで出る**——防ぎたいのはまさにそれ
 168        const attached = await page.waitForSelector(
 169          '[data-testid="attachments"], [data-testid="media"] img, [data-testid="removeMedia"]',
 170          { timeout: 25000 }
 171        ).catch(() => null);
 172        if (!attached) { out({ ok: false, step, error: "attachment did not appear - 画像なしでは出さない" }); process.exit(1); }
 173        await page.waitForTimeout(1500);
 174      }
 175  
 176      // --- 2026-09-26 x150: 打った文字列と欄の中身が一致するかを見る ---
 177      // **一致しなければ送らない。** 先頭が落ちたまま出たのが、ここで止まる。
 178      // 厳しすぎて取りこぼすときは **投稿が減る側に外れる**（出てしまう側ではない）。
 179      // そのとき want_head / got_head が出るので、推測せずに緩められる。
 180      {
 181        const _got = await page.evaluate(() => {
 182          const t = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
 183          return t ? (t.innerText || t.textContent || "") : "";
 184        });
 185        const _norm = (v) => String(v).replace(/\u200b/g, "").replace(/\s+$/g, "");
 186        if (_norm(_got) !== _norm(text)) {
 187          out({
 188            ok: false, step: "text-mismatch",
 189            error: "欄の中身が打った文と違う。送らない",
 190            want_len: [..._norm(text)].length,
 191            got_len: [..._norm(_got)].length,
 192            want_head: _norm(text).slice(0, 12),
 193            got_head: _norm(_got).slice(0, 12),
 194          });
 195          process.exit(1);
 196        }
```

## ② 打つところ

```javascript
144:    // 2026-07-13 REWRITE: insertText は JS 直接注入で React onChange 発火せず → submit button disabled のまま
145:    //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
146:    await page.keyboard.type(text, { delay: 4 });
183:        return t ? (t.innerText || t.textContent || "") : "";
185:      const _norm = (v) => String(v).replace(/\u200b/g, "").replace(/\s+$/g, "");
225:      await page.keyboard.press("Meta+Enter").catch(() => {});
227:      await page.keyboard.press("Control+Enter").catch(() => {});
251:      return !ta || ta.textContent.trim() === "";
268:      const needle = text.replace(/\s+/g, "").slice(0, 18);
276:            if (sc && /固定|Pinned/i.test(sc.textContent || "")) continue;
277:            const body = (article.innerText || "").replace(/\s+/g, "");
315:          if (/返信先|Replying to/i.test(el.textContent || "")) return true;
```

## ③ 印

```
96:x154: 返信する相手の投稿に「いい
97:x150 の 3 つのガードだけ。
101:x154art = await page.$('article[data-testid=
102:x154art) {
103:x154] article が無い。いいねは飛ば
104:x154art.$('[data-testid=
105:x154] すでに いいね済み。触らな�
107:x154btn = await _x154art.$('[data-testid=
108:x154btn) {
109:x154] like ボタンが無い
111:x154btn.click();
114:x154ok = await page.waitForSelector('article
116:x154] like 
116:x154ok ? 
120:x154] like で例外（返信は続ける）
124:x150: 打つ前に「どこに打つのか」
129:x150want = String(targetUrl || 
130:x150want && !page.url().includes(_x150want[1
136:x150focus = await page.waitForFunction(() =>
140:x150focus) {
152:x134 のガードが投稿前に止めた）
176:x150: 打った文字列と欄の中身が一
```

**投稿していない（$0／回・$0／日・$0／月）。**
