# 投稿画面の空試し（2026-10-29 22:42:11 JST・押さない・$0）

## post-via-playwright.js の押すところ
```
61:    await ta.click();
117:          await wrappers.nth(n > i ? i : 0).click();
128:            await nx.click(); await page.waitForTimeout(1500);
137:            await page.locator('[role="dialog"] a[aria-label="画像の説明を編集"]').first().click().catch(() => {});
148:          await save.click();
157:    const responsePromise = page.waitForResponse(
158:      (resp) => /\/(CreateTweet|CreateNoteTweet|create_tweet)/i.test(resp.url()) && resp.request().method() === "POST",
168:      const btn = document.querySelector('[data-testid="tweetButton"]')
169:               || document.querySelector('[data-testid="tweetButtonInline"]');
185:    await page.locator(textareaSelector).first().click({ timeout: 10000 }).catch(async () => {
189:    await page.keyboard.press("Meta+Enter");
219:      step = "fallback-scrape";
```

## 空試し（文字と画像 1 枚を入れて、押さずに閉じる）
```
{
 "textarea": true,
 "fileInput": true,
 "attached": 1,
 "buttons": [
  {
   "testid": "tweetButton",
   "text": "ポストする",
   "disabled": false
  },
  {
   "testid": null,
   "text": "新しいポストを表示",
   "disabled": false
  },
  {
   "testid": "tweetButtonInline",
   "text": "ポストする",
   "disabled": true
  }
 ],
 "alerts": []
}
```
画像: reports/x367/1-composed.png
**押していない・閉じただけ（$0）。**
