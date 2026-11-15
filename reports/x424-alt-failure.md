# ALT を付けると投稿が落ちる件（2026-11-05 19:48:30 JST・$0・投稿していない）

## ① post-via-playwright.js の ALT の部分と、例外を受ける部分
```js
103:      // 2026-10-11 x264: 画像の説明（ALT）。ALT_TEXTS_FILE（JSON 配列）があれば、i 枚目に alts[i] を入れる（空ならその画像は飛ばす）。
104-      // CC BY / CC BY-SA の撮影者名を ALT に書く運用（CLAUDE.md 最上位ルール 8）。**入れられなければ投稿しない**（throw → 投稿ボタンを押さない）。
105-      // 画面の作りは x263 で実物を読んだ: 添付ごとの [data-testid="altTextWrapper"] → 編集画面の textarea → [data-testid="endEditingButton"]
106:      if (process.env.ALT_TEXTS_FILE) {
107-        step = "alt-text";
108:        const alts = JSON.parse(fs.readFileSync(process.env.ALT_TEXTS_FILE, "utf8"));
109-        for (let i = 0; i < alts.length; i++) {
110-          if (!alts[i]) continue;
111-          // 2026-10-11 x265: 複数枚を添付すると altTextWrapper は 1 個にまとまる（x264 で実測）。
112-          // そのときは押して編集画面を開き「次へ」で i 枚目まで送る。**送った先が i 枚目かを画像の src で確かめる**。確かめられなければ投稿しない
113-          const thumbs = await page.$$eval('[data-testid="attachments"] img', (xs) => xs.map((x) => x.getAttribute("src") || ""));
114-          const wrappers = page.locator('[data-testid="attachments"] [data-testid="altTextWrapper"]');
115-          const n = await wrappers.count();
116-          if (n === 0) throw new Error("altTextWrapper が無い");
117-          await wrappers.nth(n > i ? i : 0).click();
118-          await page.waitForTimeout(2500);
119-          const curIndex = async () => {
120-            const srcs = await page.$$eval('[role="dialog"] img', (xs) => xs.filter((x) => x.offsetWidth > 120 && x.offsetHeight > 120).map((x) => x.getAttribute("src") || ""));
121-            for (const sv of srcs) { const k = thumbs.indexOf(sv); if (k >= 0) return k; }
122-            return -1;
123-          };
124-          let at = await curIndex();
125-          for (let guard = 0; at !== i && guard < 4; guard++) {
126-            const nx = page.locator('[role="dialog"]:has([data-testid="endEditingButton"]) button[aria-label="次へ"]').last();
127-            if (!(await nx.count())) break;
128-            await nx.click(); await page.waitForTimeout(1500);
129-            at = await curIndex();
130-          }
131-          if (at !== i) {
132-            const dbg = await page.$$eval('[role="dialog"] img', (xs) => xs.map((x) => (x.getAttribute("src") || "").slice(0, 60) + " " + x.offsetWidth + "x" + x.offsetHeight));
133-            throw new Error("編集画面で " + (i + 1) + " 枚目を特定できない（at=" + at + "） thumbs=" + JSON.stringify(thumbs.map((t) => t.slice(0, 60))) + " dialog_imgs=" + JSON.stringify(dbg));
134-          }
135-          let box = page.locator('[role="dialog"] textarea').first();
136-          if (!(await box.count())) {
137-            await page.locator('[role="dialog"] a[aria-label="画像の説明を編集"]').first().click().catch(() => {});
138-            await page.waitForTimeout(1500);
139-            box = page.locator('[role="dialog"] textarea').first();
140-          }
141-          if (!(await box.count())) throw new Error("ALT の入力欄が見つからない（" + (i + 1) + " 枚目）");
142-          await box.fill(alts[i]);
143-          await page.waitForTimeout(500);
144-          const got = await box.inputValue();
145-          if (got.replace(/\s/g, "") !== String(alts[i]).replace(/\s/g, "")) throw new Error("ALT が入りきらない（" + (i + 1) + " 枚目） got_len=" + got.length + " want_len=" + alts[i].length);
146-          const save = page.locator('[role="dialog"] [data-testid="endEditingButton"]').first();
147-          if (!(await save.count())) throw new Error("ALT の保存ボタンが無い");
148-          await save.click();
149-          await page.waitForTimeout(1500);
150-          console.error("[post-via-playwright] alt set for image " + (i + 1) + " (" + got.length + " chars)");
151-        }
152-      }
153-    }
154-
155-    // 2026-05-15 v3: arm GraphQL response listener BEFORE submit
156-    step = "arm-response-listener";
157-    const responsePromise = page.waitForResponse(
158-      (resp) => /\/(CreateTweet|CreateNoteTweet|create_tweet)/i.test(resp.url()) && resp.request().method() === "POST",
// --- catch の部分
206:      } catch (e) { /* ignore */ }
207-    }
208-
209-    step = "wait-textarea-clear";
210-    await page.waitForFunction(() => {
211-      const ta = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
212-      return !ta || ta.textContent.trim() === "";
--
263:    } catch (e) { /* watchdog spawn failure must not break main return */ }
264-    out({
265-      ok: true,
266-      tweet_id: capturedTweetId,
267-      url: `https://x.com/${X_PROFILE_USERNAME}/status/${capturedTweetId}`,
268-      image_attached: imageAttached,
269-      captured_via: capturedVia,
--
271:  } catch (err) {
272-    if (page) try { await page.close(); } catch {}
273-    if (browser) try { await browser.close(); } catch {}
274-    out({ ok: false, step, error: err.message });
275-    process.exit(1);
276-  }
277-}
```

## ② run-publish.sh の thread モードは失敗をどう受けているか
```
102-      const imagePathFirst = imagePath ? imagePath.split(',')[0].trim() : null;
103-      const cmd = imagePathFirst && fs.existsSync(imagePathFirst)
104-        ? \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\" \"\${imagePath}\"\`
105-        : \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\"\`;
106-      try {
107-        const out = execSync(cmd, { encoding: 'utf8' });
108-        const lines = out.trim().split('\n');
109-        const r = JSON.parse(lines[lines.length - 1]);
110-        results.push({ index: i, role: item.role || 'main', ...r });
111-        if (r.ok && r.url) prevUrl = r.url;
112-        else { console.log(JSON.stringify({ ok: false, step: 'thread-main', error: r.error || 'main post failed', thread_results: results })); return; }
113-      } catch (e) {
114:        console.log(JSON.stringify({ ok: false, step: 'thread-main-exec', error: e.message, child_stdout: String(e.stdout || '').slice(-700), child_stderr: String(e.stderr || '').slice(-700), thread_results: results }));
115-        return;
116-      }
117-    } else {
118-      // Reply to previous
```

## ③ 実物で試す（画像 2 枚・ALT 2 本・投稿しない）
```json
{
 "log": [
  "1枚目: altTextWrapper 1 個。押すのは 0 番",
  "1枚目: 開いた直後の at=0",
  "1枚目: textarea 1 個",
  "1枚目: 入れた 269 字 / 入れたい 269 字（一致）",
  "1枚目: 保存ボタン 1 個",
  "2枚目: altTextWrapper 1 個。押すのは 0 番",
  "2枚目: 開いた直後の at=0",
  "2枚目: 「次へ」 1 個 aria-disabled=true",
  "2枚目: 「次へ」が押せない: locator.click: Timeout 5000ms exceeded.",
  "2枚目: 「次へ」のあと at=0",
  "2枚目: 「次へ」 1 個 aria-disabled=true",
  "2枚目: 「次へ」が押せない: locator.click: Timeout 5000ms exceeded.",
  "2枚目: 「次へ」のあと at=0",
  "2枚目: 「次へ」 1 個 aria-disabled=true",
  "2枚目: 「次へ」が押せない: locator.click: Timeout 5000ms exceeded.",
  "2枚目: 「次へ」のあと at=0",
  "2枚目: 「次へ」 1 個 aria-disabled=true",
  "2枚目: 「次へ」が押せない: locator.click: Timeout 5000ms exceeded.",
  "2枚目: 「次へ」のあと at=0",
  "2枚目: 本番はここで落ちる（編集画面で 2 枚目を特定できない）。「次の画像」で試す",
  "2枚目: 「次の画像」 1 個",
  "2枚目: 「次の画像」のあと at=1",
  "2枚目: textarea 1 個",
  "2枚目: 入れた 503 字 / 入れたい 503 字（一致）",
  "2枚目: 保存ボタン 1 個",
  "閉じる: 「破棄」を押した"
 ],
 "alt_lens": [
  269,
  503
 ],
 "thumbs": [
  "1669f9e0c9b6",
  "ecae5bc47034"
 ],
 "wrappers_1": [
  "件の説明を追加"
 ],
 "dialogs_1_open": [
  {
   "di": 0,
   "nested": false,
   "buttons": [
    "戻る #app-bar-back",
    "前の画像［押せない］",
    "次の画像",
    "保存 #endEditingButton",
    "前［押せない］",
    "メディアをトリミング",
    "画像の説明を編集",
    "内容の警告",
    "次へ［押せない］",
    "代替テキストとは？"
   ],
   "imgs": [
    "1669f9e0c9b6 550x680 at 365,187"
   ],
   "inputs": [
    "altTextInput maxlength=1000 len=0"
   ]
  },
  {
   "di": 1,
   "nested": true,
   "buttons": [
    "戻る #app-bar-back",
    "前の画像［押せない］",
    "次の画像",
    "保存 #endEditingButton",
    "前［押せない］",
    "メディアをトリミング",
    "画像の説明を編集",
    "内容の警告",
    "次へ［押せない］",
    "代替テキストとは？"
   ],
   "imgs": [
    "1669f9e0c9b6 550x680 at 365,187"
   ],
   "inputs": [
    "altTextInput maxlength=1000 len=0"
   ]
  }
 ],
 "after_save_1": [
  {
   "di": 0,
   "nested": false,
   "buttons": [
    "閉じる #app-bar-close",
    "下書き #unsentButton",
    "ALT",
    "メディアを編集",
    "メディアを削除",
    "メディアを編集",
    "メディアを削除",
    "タグ付けする",
    "件の説明を追加 #altTextWrapper",
    "全員が返信できます",
    "前［押せない］",
    "メディアを追加",
    "GIF画像を追加 #gifSearchButton",
    "画像を生成 #grokImgGen",
    "投票を追加［押せない］ #createPollButton",
    "絵文字を追加",
    "ポストを予約 #scheduleOption",
    "位置情報を追加［押せない］ #geoButton",
    "コンテンツ開示 #contentDisclosureButton",
    "次へ［押せない］",
    "ポストを追加 #addButton",
    "ポストする #tweetButton"
   ],
   "imgs": [
    "w_normal.jpg 40x40 at 356,124",
    "1669f9e0c9b6 252x290 at 406,174",
    "ecae5bc47034 252x290 at 670,174"
   ],
   "inputs": []
  },
  {
   "di": 1,
   "nested": true,
   "buttons": [
    "閉じる #app-bar-close",
    "下書き #unsentButton",
    "ALT",
    "メディアを編集",
    "メディアを削除",
    "メディアを編集",
    "メディアを削除",
    "タグ付けする",
    "件の説明を追加 #altTextWrapper",
    "全員が返信できます",
    "前［押せない］",
    "メディアを追加",
    "GIF画像を追加 #gifSearchButton",
    "画像を生成 #grokImgGen",
    "投票を追加［押せない］ #createPollButton",
    "絵文字を追加",
    "ポストを予約 #scheduleOption",
    "位置情報を追加［押せない］ #geoButton",
    "コンテンツ開示 #contentDisclosureButton",
    "次へ［押せない］",
    "ポストを追加 #addButton",
    "ポストする #tweetButton"
   ],
   "imgs": [
    "w_normal.jpg 40x40 at 356,124",
    "1669f9e0c9b6 252x290 at 406,174",
    "ecae5bc47034 252x290 at 670,174"
   ],
   "inputs": []
  }
 ],
 "wrappers_2": [
  "1件の画像の説明"
 ],
 "dialogs_2_open": [
  {
   "di": 0,
   "nested": false,
   "buttons": [
    "戻る #app-bar-back",
    "前の画像［押せない］",
    "次の画像",
    "保存 #endEditingButton",
    "前［押せない］",
    "メディアをトリミング",
    "画像の説明を編集",
    "内容の警告",
    "次へ［押せない］",
    "代替テキストとは？"
   ],
   "imgs": [
    "1669f9e0c9b6 550x600 at 365,187"
   ],
   "inputs": [
    "altTextInput maxlength=1000 len=269"
   ]
  },
  {
   "di": 1,
   "nested": true,
   "buttons": [
    "戻る #app-bar-back",
    "前の画像［押せない］",
    "次の画像",
    "保存 #endEditingButton",
    "前［押せない］",
    "メディアをトリミング",
    "画像の説明を編集",
    "内容の警告",
    "次へ［押せない］",
    "代替テキストとは？"
   ],
   "imgs": [
    "1669f9e0c9b6 550x600 at 365,187"
   ],
   "inputs": [
    "altTextInput maxlength=1000 len=269"
   ]
  }
 ],
 "dialogs_2_after_next": [
  {
   "di": 0,
   "nested": false,
   "buttons": [
    "戻る #app-bar-back",
    "前の画像",
    "次の画像［押せない］",
    "保存 #endEditingButton",
    "前［押せない］",
    "メディアをトリミング",
    "画像の説明を編集",
    "内容の警告",
    "次へ［押せない］",
    "代替テキストとは？"
   ],
   "imgs": [
    "ecae5bc47034 550x680 at 365,187"
   ],
   "inputs": [
    "altTextInput maxlength=1000 len=0"
   ]
  },
  {
   "di": 1,
   "nested": true,
   "buttons": [
    "戻る #app-bar-back",
    "前の画像",
    "次の画像［押せない］",
    "保存 #endEditingButton",
    "前［押せない］",
    "メディアをトリミング",
    "画像の説明を編集",
    "内容の警告",
    "次へ［押せない］",
    "代替テキストとは？"
   ],
   "imgs": [
    "ecae5bc47034 550x680 at 365,187"
   ],
   "inputs": [
    "altTextInput maxlength=1000 len=0"
   ]
  }
 ],
 "after_save_2": [
  {
   "di": 0,
   "nested": false,
   "buttons": [
    "閉じる #app-bar-close",
    "下書き #unsentButton",
    "ALT",
    "メディアを編集",
    "メディアを削除",
    "ALT",
    "メディアを編集",
    "メディアを削除",
    "タグ付けする",
    "件の説明を追加 #altTextWrapper",
    "全員が返信できます",
    "前［押せない］",
    "メディアを追加",
    "GIF画像を追加 #gifSearchButton",
    "画像を生成 #grokImgGen",
    "投票を追加［押せない］ #createPollButton",
    "絵文字を追加",
    "ポストを予約 #scheduleOption",
    "位置情報を追加［押せない］ #geoButton",
    "コンテンツ開示 #contentDisclosureButton",
    "次へ［押せない］",
    "ポストを追加 #addButton",
    "ポストする #tweetButton"
   ],
   "imgs": [
    "w_normal.jpg 40x40 at 356,124",
    "1669f9e0c9b6 252x290 at 406,174",
    "ecae5bc47034 252x290 at 670,174"
   ],
   "inputs": []
  },
  {
   "di": 1,
   "nested": true,
   "buttons": [
    "閉じる #app-bar-close",
    "下書き #unsentButton",
    "ALT",
    "メディアを編集",
    "メディアを削除",
    "ALT",
    "メディアを編集",
    "メディアを削除",
    "タグ付けする",
    "件の説明を追加 #altTextWrapper",
    "全員が返信できます",
    "前［押せない］",
    "メディアを追加",
    "GIF画像を追加 #gifSearchButton",
    "画像を生成 #grokImgGen",
    "投票を追加［押せない］ #createPollButton",
    "絵文字を追加",
    "ポストを予約 #scheduleOption",
    "位置情報を追加［押せない］ #geoButton",
    "コンテンツ開示 #contentDisclosureButton",
    "次へ［押せない］",
    "ポストを追加 #addButton",
    "ポストする #tweetButton"
   ],
   "imgs": [
    "w_normal.jpg 40x40 at 356,124",
    "1669f9e0c9b6 252x290 at 406,174",
    "ecae5bc47034 252x290 at 670,174"
   ],
   "inputs": []
  }
 ],
 "closedUrl": "https://x.com/home"
}
```

画面: x424-1a-editor.png x424-2a-editor.png x424-2b-after-next.png x424-9-final.png 

**投稿ボタンは触っていない。下書きは破棄した。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
