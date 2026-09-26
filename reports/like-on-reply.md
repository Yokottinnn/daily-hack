# 返信するときに いいね も付ける（2026-09-26 23:30 JST・$0）

**このレポートが作られた時刻: 2026-09-26 23:30:26 JST**

> **ループは戻していない。** 投稿もしていない。

## 1. 既存の実装（`engage-via-playwright.js`）

**書き方を写す元。** セレクタと待ちに実績がある。

```javascript
  111-  await page.goto(`https://x.com/${handle}`, { waitUntil: "domcontentloaded", timeout: 25000 });
  112-  // First tweet article
  113-  const article = await page.waitForSelector('article[data-testid="tweet"]', { timeout: 10000 });
  114:  // Like button: data-testid="like" (not "unlike")
  115:  const likeBtn = await article.$('[data-testid="like"]');
  116-  if (!likeBtn) {
  117-    // Already liked or not found
  118:    const unlike = await article.$('[data-testid="unlike"]');
  119-    if (unlike) return { ok: true, status: "already_liked" };
  120-    return { ok: false, status: "like_button_not_found" };
  121-  }
  122-  await likeBtn.click();
  123-  await page.waitForTimeout(1000);
  124-  // Get URL of the tweet for logging
  125-  const tweetUrl = await article.$eval('a[href*="/status/"]', a => a.href).catch(() => null);
  126-  return { ok: true, status: "liked", post_url: tweetUrl };
  127-}
  128-
```

## 2. 当てる前

```
  行数    : 333
  更新     : 2026-09-26 22:57:10
  sha256  : 468976a3145153d83c42591ee1d09b30a2c26d6e33dcde0461a82feb8e472832
  x150 が入っているか: 6
```

## 3. バックアップ

```
  post-comment.js.bak-20260926-233026  (17072 bytes)
```

## 4. パッチ（**目印が無ければ 1 文字も書かずに、その場の中身を吐く**）

```
  OK 返信の直前に いいね を差した
  rc=0
```

## 5. `node --check`

```
  rc=0
```

## 6. 当てたあと

```
  行数    : 361
  sha256  : 0389ed75974b0aa1eca5571961e7f8240b5889a2e5d6a4afa4d750684795c69a
  差分    : +28 行
```

```diff
  --- /Users/ny/.openclaw/workspace/scripts/post-comment.js.bak-20260926-233026	2026-09-26 22:57:10
  +++ /Users/ny/.openclaw/workspace/scripts/post-comment.js	2026-09-26 23:30:27
  @@ -93,6 +93,34 @@
   
       step = "type-text";
       console.error("[step] " + step + " t=" + ((Date.now()-t0)|0) + "ms");
  +    // --- 2026-09-26 x154: 返信する相手の投稿に「いいね」も付ける ---
  +    // **おまけ。押せなくても返信は止めない。** 止めるのは x150 の 3 つのガードだけ。
  +    // REPLY_LIKE=off で無効にできる。すでに押してあるなら触らない（解除してしまう）
  +    if ((process.env.REPLY_LIKE || "on") !== "off") {
  +      try {
  +        const _x154art = await page.$('article[data-testid="tweet"]');
  +        if (!_x154art) {
  +          console.error("[x154] article が無い。いいねは飛ばす");
  +        } else if (await _x154art.$('[data-testid="unlike"]')) {
  +          console.error("[x154] すでに いいね済み。触らない");
  +        } else {
  +          const _x154btn = await _x154art.$('[data-testid="like"]');
  +          if (!_x154btn) {
  +            console.error("[x154] like ボタンが無い");
  +          } else {
  +            await _x154btn.click();
  +            // **押した結果を見る。** rc も「押せた」も証拠にならない（最上位ルール 13）
  +            // **page 側で待つ。** ElementHandle.waitForSelector は版で挙動が違う
  +            const _x154ok = await page.waitForSelector('article[data-testid="tweet"] [data-testid="unlike"]', { timeout: 6000 })
  +              .then(() => true).catch(() => false);
  +            console.error("[x154] like " + (_x154ok ? "付いた" : "**付いていない**"));
  +          }
  +        }
  +      } catch (e) {
  +        console.error("[x154] like で例外（返信は続ける）: " + String((e && e.message) || e).slice(0, 120));
  +      }
  +    }
  +
       // --- 2026-09-26 x150: 打つ前に「どこに打つのか」を確かめる ---
       // 2026-09-25 に、返信のつもりが単独投稿になり、しかも先頭 2 文字が落ちた
       // （「アタシも…」→「シも…」）。原因は 2 つとも ここに在った。
```

## 7. まだ確かめていないこと（**正直に書く**）

| | |
| --- | --- |
| 構文 | **通った** |
| 目印 | **当たった**（外れれば当てずに止まる作り） |
| **実際に いいねが付くか** | **確かめていない。** ループは止めたまま。X に 1 回も触っていない |
| セレクタ | `[data-testid="like"]` / `unlike`。**§1 の実物と突き合わせること** |

動かすと stderr（`comment-warmup-err.log`）に次のどれかが出る。

```
  [x154] like 付いた
  [x154] like **付いていない**      ← セレクタか待ちを見直す
  [x154] すでに いいね済み。触らない
  [x154] like ボタンが無い
  [x154] article が無い。いいねは飛ばす
```

戻すとき:

```bash
  cp -p "/Users/ny/.openclaw/workspace/scripts/post-comment.js.bak-20260926-233026" "/Users/ny/.openclaw/workspace/scripts/post-comment.js"        # いいねごと戻る
  # いいねだけ止めるなら plist に REPLY_LIKE=off を足す
```

## 8. 費用

**いいねは DOM 操作。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

> 返信ループ自体は停止中なので、いまの実額は **$0**。
> 戻せば **$0.081／日・約 $2.43／月**（2026-09-21 の実測）。**いいねを足しても増えない。**
