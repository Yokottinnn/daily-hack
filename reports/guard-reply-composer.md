# 返信を打つ前と送る前に確かめる（2026-09-26 22:57 JST・$0）

**このレポートが作られた時刻: 2026-09-26 22:57:10 JST**

> **ループは戻していない。** 直ったかどうかと、戻すかどうかは別の判断。

## 0. 当てる前

```
  行数    : 292
  更新     : 2026-09-23 21:06:40
  sha256  : 23423b68c7300095409415cca92c67af08f142c06252eae671e8c49248963d81
```

> `x149` の時点は **292 行 / 更新 2026-09-23 21:06:40**。

## 1. バックアップ

```
  post-comment.js.bak-20260926-225710  (14698 bytes)
```

## 2. パッチ（**目印が違えば 1 文字も書かずに、その場の中身を吐く**）

```
  OK ① 目的のページに居るかを見る / ② フォーカスが載るまで待つ / ③ 打った文と欄の中身を突き合わせ、違えば送らない
  rc=0
```

## 3. `node --check`（**通らなければ当てない**）

```
  rc=0
```

## 4. 当てたあと

```
  行数    : 333
  sha256  : 468976a3145153d83c42591ee1d09b30a2c26d6e33dcde0461a82feb8e472832
  差分    : +41 行
```

入った 3 箇所（**行番号と目印だけ**）:

```javascript
  96:    // --- 2026-09-26 x150: 打つ前に「どこに打つのか」を確かめる ---
  101:    const _x150want = String(targetUrl || "").match(/status\/(\d+)/);
  102:    if (_x150want && !page.url().includes(_x150want[1])) {
  103:      out({ ok: false, step: "wrong-page", error: "返信先のページに居ない: url=" + page.url().slice(0, 120) });
  108:    const _x150focus = await page.waitForFunction(() => {
  112:    if (!_x150focus) {
  113:      out({ ok: false, step: "no-focus", error: "入力欄にフォーカスが載らない（打たずに止まる）" });
  148:    // --- 2026-09-26 x150: 打った文字列と欄の中身が一致するかを見る ---
  160:          ok: false, step: "text-mismatch",
  221:    await page.waitForFunction(() => {
```

**`waitForTimeout(400)` が残っていないか**（残っていれば当たっていない）:

```
  waitForTimeout(400) : 0 箇所
```

## 5. 差分（**入れたところだけ**）

```diff
  --- /Users/ny/.openclaw/workspace/scripts/post-comment.js.bak-20260926-225710	2026-09-23 21:06:40
  +++ /Users/ny/.openclaw/workspace/scripts/post-comment.js	2026-09-26 22:57:10
  @@ -93,8 +93,26 @@
   
       step = "type-text";
       console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
  +    // --- 2026-09-26 x150: 打つ前に「どこに打つのか」を確かめる ---
  +    // 2026-09-25 に、返信のつもりが単独投稿になり、しかも先頭 2 文字が落ちた
  +    // （「アタシも…」→「シも…」）。原因は 2 つとも ここに在った。
  +    //   ① ページが目的の status から離れていても、そのまま打っていた
  +    //   ② click の後 400ms 待つだけで、フォーカスが載る前に delay:4 で打ち始めていた
  +    const _x150want = String(targetUrl || "").match(/status\/(\d+)/);
  +    if (_x150want && !page.url().includes(_x150want[1])) {
  +      out({ ok: false, step: "wrong-page", error: "返信先のページに居ない: url=" + page.url().slice(0, 120) });
  +      process.exit(1);
  +    }
       await ta.click();
  -    await page.waitForTimeout(400);
  +    // **400ms の固定待ちをやめる。** カーソルが本当に載るまで待つ
  +    const _x150focus = await page.waitForFunction(() => {
  +      const a = document.activeElement;
  +      return !!a && a.getAttribute && a.getAttribute("contenteditable") === "true";
  +    }, { timeout: 8000 }).catch(() => null);
  +    if (!_x150focus) {
  +      out({ ok: false, step: "no-focus", error: "入力欄にフォーカスが載らない（打たずに止まる）" });
  +      process.exit(1);
  +    }
       // 2026-07-13 REWRITE: insertText は JS 直接注入で React onChange 発火せず → submit button disabled のまま
       //   → 実 typing (keyboard.type delay:4) で React state 更新 → tweetButtonInline enabled
       await page.keyboard.type(text, { delay: 4 });
  @@ -127,6 +145,29 @@
         await page.waitForTimeout(1500);
       }
   
  +    // --- 2026-09-26 x150: 打った文字列と欄の中身が一致するかを見る ---
  +    // **一致しなければ送らない。** 先頭が落ちたまま出たのが、ここで止まる。
  +    // 厳しすぎて取りこぼすときは **投稿が減る側に外れる**（出てしまう側ではない）。
  +    // そのとき want_head / got_head が出るので、推測せずに緩められる。
  +    {
  +      const _got = await page.evaluate(() => {
  +        const t = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
  +        return t ? (t.innerText || t.textContent || "") : "";
  +      });
  +      const _norm = (v) => String(v).replace(/\u200b/g, "").replace(/\s+$/g, "");
  +      if (_norm(_got) !== _norm(text)) {
  +        out({
  +          ok: false, step: "text-mismatch",
  +          error: "欄の中身が打った文と違う。送らない",
  +          want_len: [..._norm(text)].length,
  +          got_len: [..._norm(_got)].length,
  +          want_head: _norm(text).slice(0, 12),
  +          got_head: _norm(_got).slice(0, 12),
  +        });
  +        process.exit(1);
  +      }
  +    }
  +
       step = "arm-response-listener";
       console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
       // 2026-05-15 v2: Listen for CreateTweet GraphQL response (most reliable tweet ID source)
```

## 6. まだ確かめていないこと（**正直に書く**）

| | |
| --- | --- |
| 構文 | **通った**（`node --check`） |
| 目印 | **3 箇所すべて当たった**（外れれば当てずに止まる作り） |
| **実際に返信が出るか** | **確かめていない。** ループは止めたまま。X に 1 回も触っていない |
| ③ が厳しすぎないか | **未検証。** 絵文字・末尾の扱いで取りこぼす可能性がある |

**戻す前に 1 回、手で 1 件だけ走らせて確かめるのが筋。**
取りこぼすなら `text-mismatch` が出るので、`want_head` / `got_head` で緩め方が分かる。

戻すとき:

```bash
  cp -p "/Users/ny/.openclaw/workspace/scripts/post-comment.js.bak-20260926-225710" "/Users/ny/.openclaw/workspace/scripts/post-comment.js"
```

## 7. 費用

**ファイルを書き換えて構文を検査しただけ。LLM を呼んでいない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

> ループは停止中なので、返信の課金は **$0 のまま**。
> 戻せば **$0.081／日・約 $2.43／月** に戻る（2026-09-21 の実測）。
