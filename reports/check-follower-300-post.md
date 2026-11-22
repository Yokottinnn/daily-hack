# フォロワー 300 人のお礼は X に出たか（2026-10-03 21:07 JST・$0）

**このレポートが作られた時刻: 2026-10-03 21:07:49 JST**

> **投稿しない。再送しない。キューを書き換えない（$0／回・$0／日・$0／月）。**

## ① 自分のプロフィールの直近 8 本

```
  node --check rc=0 
  rc=0
```
- 2026-05-12 14:28  （固定）/heng_ji31590/status/2054071132509311284  動画:false GIF表示:false 画像:1  「📌 はじめましての方は、コレ読んでフォロー判断してね💢  あんたの「お金の選択肢」、損してる箇所を毎日指摘するわ。 ポイ活・節約・キャンペーン速報・クレカ比」
- 2026-10-03 21:04  /heng_ji31590/status/2106354716733235381  動画:true GIF表示:true 画像:1  「【フォロワー300人突破】🎉  ふん、別にあんたたちのためにやってきたわけじゃないけど。  5/15は19人。10/3で304人。 損したくない人、こんなにい」
- 2026-09-27 12:00  /heng_ji31590/status/2104043402358886416  動画:false GIF表示:false 画像:4  「PAY ID、招待コード入れるだけで500円分もらえるわよ。  招待コード：YY8RQV  招待コードを入力すると 《500円分のPAY IDポイント》がもらえ」
- 2026-09-27 16:55  /heng_ji31590/status/2104117765099663673  動画:false GIF表示:false 画像:0  「BASEで作られたショップ——あの個人商店みたいなネットショップが、ぜんぶこのアプリから買えるの。2,000万アカウント突破、App Storeの評価4.65。」
- 2026-09-23 21:10  /heng_ji31590/status/2102732457930064353  動画:false GIF表示:false 画像:0  「朝マックのマフィン180円が最安、って思ってない？  それマフィン1個だけよ。飲み物もハッシュポテトも別。セットにすると450円〜。  同じ「ごはん・みそ汁つき」
- 2026-09-23 21:43  /heng_ji31590/status/2102740733400912253  動画:false GIF表示:false 画像:1  「なか卯の目玉焼き朝食、300円。  ごはん・みそ汁・目玉焼きつきで一食が完結するの。小盛300円、並盛でも320円よ。松屋より30円安い。  朝4:00から11」
- 2026-09-21 18:23  /heng_ji31590/status/2101965436426564045  動画:false GIF表示:false 画像:4  「1店舗あたりの年商、オーケーが43.4億円でまいばすけっとが2.4億円。18倍の開きよ。  ・まいばすけっとは1,262店中879店が東京都 ・肉のハナマサは6」
- 2026-09-21 18:23  /heng_ji31590/status/2101965516718187002  動画:false GIF表示:false 画像:0  「「都心の安いスーパーどこ？」で出てくるのは、だいたい誰かの感想かチラシ。なぜ安いのかは誰も」

**判定: 出ている → https://x.com/heng_ji31590/status/2106354716733235381（動画: true）**

画面: `x215-post.png`

## ② なぜ出力が空だったか（ソースを書き出す）

```
  --- post-via-playwright.js（60〜150 行目）
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

  --- run-publish.sh の本投稿の呼び出しと parse-main-result
8:#   - 1個目 = main post (post-via-playwright)
82:const { execSync } = require('child_process');
104:        ? \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\" \"\${imagePath}\"\`
105:        : \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\"\`;
107:        const out = execSync(cmd, { encoding: 'utf8' });
124:        const out = execSync(cmd, { encoding: 'utf8' });
172:  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" "$IMAGE_PATH" 2>"$ERR_TMP")
174:  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" 2>"$ERR_TMP")
203:catch (e) { main = {ok:false, step:'parse-main-result', error:'main result not valid JSON', raw:(process.env.MAIN_RES||'').slice(0, 200)}; }
```

**投稿していない。再送していない。キューを書き換えていない（$0／回・$0／日・$0／月）。**
