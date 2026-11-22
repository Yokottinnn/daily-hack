# 外す処理が打ち切られる理由（2026-10-31 11:27:54 JST・$0）

## 1. いま Chrome に開いているページ（種類と行き先のホストだけ）
```
ページ数 9 ／ 全部 25
iframe	m.media-amazon.com/<伏せ>
iframe	m.media-amazon.com/<伏せ>
iframe	m.media-amazon.com/<伏せ>
iframe	aax-fe.amazon-adsystem.com/s
iframe	aax-fe.amazon-adsystem.com/s
iframe	m.media-amazon.com/<伏せ>
iframe	m.media-amazon.com/<伏せ>
iframe	m.media-amazon.com/<伏せ>
page	x.com/<伏せ>
page	x.com/<伏せ>
page	x.com/<伏せ>
page	x.com/<伏せ>
page	x.com/<伏せ>
page	x.com/<伏せ>
service_worker	x.com/sw.js
service_worker	www.amazon.co.jp/service-worker.js
shared_worker	https:/
shared_worker	https:/
shared_worker	https:/
shared_worker	https:/
shared_worker	https:/
shared_worker	https:/
```

## 2. 間隔の台帳（直近 30 分）
```
tweet: 直近 30 分 0/12・間隔 60 秒
like: 直近 30 分 0/10・間隔 45 秒
follow: 直近 30 分 0/4・間隔 180 秒
unfollow: 直近 30 分 0/6・間隔 120 秒
```

## 3. unfollow-handle.js を 1 件だけ走らせる（DEBUG=pw:api・最大 130 秒）
```
同時に動いている:  5706          27:50 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js
同時に動いている: 11572          00:25 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/unfollow-handle.js moyana75
→ 終わった rc=2 経過 120 秒
--- 出力（72 行）の最後 70 行
2026-10-31T02:27:55.376Z pw:api   "commit" event fired
2026-10-31T02:27:55.425Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:55.425Z pw:api   "load" event fired
2026-10-31T02:27:55.464Z pw:api   "commit" event fired
2026-10-31T02:27:55.500Z pw:api   "commit" event fired
2026-10-31T02:27:55.526Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:55.526Z pw:api   "load" event fired
2026-10-31T02:27:55.540Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:55.540Z pw:api   "load" event fired
2026-10-31T02:27:55.542Z pw:api   "commit" event fired
2026-10-31T02:27:55.554Z pw:api   "commit" event fired
2026-10-31T02:27:55.554Z pw:api   "commit" event fired
2026-10-31T02:27:55.554Z pw:api   "commit" event fired
2026-10-31T02:27:55.555Z pw:api   "commit" event fired
2026-10-31T02:27:55.556Z pw:api   "commit" event fired
2026-10-31T02:27:55.708Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:55.708Z pw:api   "load" event fired
2026-10-31T02:27:55.723Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:55.723Z pw:api   "load" event fired
2026-10-31T02:27:55.730Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:55.730Z pw:api   "load" event fired
2026-10-31T02:27:55.738Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:55.738Z pw:api   "load" event fired
2026-10-31T02:27:55.767Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:55.767Z pw:api   "load" event fired
2026-10-31T02:27:55.768Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:55.768Z pw:api   "load" event fired
2026-10-31T02:27:55.849Z pw:api <= browserType.connectOverCDP succeeded
2026-10-31T02:27:55.849Z pw:api => browserContext.newPage started
2026-10-31T02:27:55.877Z pw:api   "networkidle" event fired
2026-10-31T02:27:55.958Z pw:api <= browserContext.newPage succeeded
2026-10-31T02:27:55.980Z pw:api => page.goto started
2026-10-31T02:27:55.980Z pw:api   "networkidle" event fired
2026-10-31T02:27:55.983Z pw:api navigating to "https://x.com/<伏せ>", waiting until "domcontentloaded"
2026-10-31T02:27:56.001Z pw:api   "networkidle" event fired
2026-10-31T02:27:56.008Z pw:api   "commit" event fired
2026-10-31T02:27:56.008Z pw:api   navigated to "https://x.com/<伏せ>"
2026-10-31T02:27:56.031Z pw:api   navigated to "about:blank"
2026-10-31T02:27:56.043Z pw:api   "networkidle" event fired
2026-10-31T02:27:56.055Z pw:api   "networkidle" event fired
2026-10-31T02:27:56.055Z pw:api   "networkidle" event fired
2026-10-31T02:27:56.055Z pw:api   "networkidle" event fired
2026-10-31T02:27:56.055Z pw:api   "networkidle" event fired
2026-10-31T02:27:56.056Z pw:api   "networkidle" event fired
2026-10-31T02:27:56.091Z pw:api   navigated to "https://x.com/<伏せ>"
2026-10-31T02:27:56.101Z pw:api   "domcontentloaded" event fired
2026-10-31T02:27:56.102Z pw:api <= page.goto succeeded
2026-10-31T02:27:56.102Z pw:api => page.waitForTimeout started
2026-10-31T02:27:56.103Z pw:api   navigated to "about:srcdoc"
2026-10-31T02:27:56.110Z pw:api   navigated to "about:blank"
2026-10-31T02:27:56.444Z pw:api   "load" event fired
2026-10-31T02:27:56.527Z pw:api   navigated to "about:blank"
2026-10-31T02:27:56.537Z pw:api   navigated to "about:blank"
2026-10-31T02:27:59.603Z pw:api <= page.waitForTimeout succeeded
2026-10-31T02:27:59.604Z pw:api => page.evaluate started
2026-10-31T02:27:59.619Z pw:api <= page.evaluate succeeded
{"ok":false,"status":"not_following","reason":"no unfollow button"}
2026-10-31T02:27:59.620Z pw:api => page.close started
2026-10-31T02:27:59.644Z pw:api <= page.close succeeded
2026-10-31T02:29:34.770Z pw:api   "commit" event fired
2026-10-31T02:29:34.776Z pw:api   navigated to "https://x.com/pref_yamagata"
2026-10-31T02:29:34.816Z pw:api   navigated to "about:blank"
2026-10-31T02:29:34.822Z pw:api   navigated to "about:srcdoc"
2026-10-31T02:29:34.832Z pw:api   navigated to "https://x.com/pref_yamagata"
2026-10-31T02:29:34.847Z pw:api   "domcontentloaded" event fired
2026-10-31T02:29:34.852Z pw:api   navigated to "about:blank"
2026-10-31T02:29:34.891Z pw:api   "load" event fired
2026-10-31T02:29:35.345Z pw:api   navigated to "about:blank"
2026-10-31T02:29:35.359Z pw:api   navigated to "about:blank"
{"ok":false,"step":"timeout","error":"2 分で打ち切った（x380）"}
```

## 4. X のページの画面（最大 25 秒）
```
page-1.png 撮れた
page-2.png 撮れた
page-3.png 撮れた
page-4.png 撮れた
X のページ 4 枚
page-1.png 1381963 bytes
page-2.png 1056819 bytes
page-3.png 1523970 bytes
page-4.png 648878 bytes
```

## 5. unfollow-handle.js の中身（先頭 100 行）
```
#!/usr/bin/env node
/* x380: 2 分で必ず終わる（止まったまま親を巻き込まない）。押す前に空くまで待つ（30 分 6 回・2 分おき） */ setTimeout(()=>{console.log(JSON.stringify({ok:false,step:"timeout",error:"2 分で打ち�
// unfollow-handle.js — Unfollow a single X handle via CDP.
// Usage: node unfollow-handle.js <handle>
// Output: JSON {ok, status: unfollowed/not_following/unconfirmed/error, reason?}
//
// 2026-09-13: **x17 で実際に外せた取り方にそろえた。**
//
// 直したのは 3 つだけ。判定も出力の JSON も変えていない。
//
//   ① work-window ではなく `contexts()[0]` を使う
//      x53 で、同じ相手のプロフィールに `…-unfollow` が在ることを確認済み。
//      それでも「no unfollow button」になっていた＝**取り方の差**。
//      専用ウィンドウが別コンテキスト（未ログイン）だと、ボタンは出ない。
//
//   ② `waitUntil: "commit"` → `"domcontentloaded"`
//      `commit` はナビゲーション確定の瞬間で、**DOM はまだ無い。**
//      4 秒 待っても、描画が間に合わなければ空振りする。
//
//   ③ `browser.close()` を呼ばない
//      CDP で繋いだブラウザに対して呼ぶと **Chrome ごと落ちうる。**
//      閉じるのは自分が開いたタブだけ。
//
// あわせて、`…-unfollow` が取れないときは**「フォロー中」の文字でも探す**。
// 描画の揺れで data-testid が間に合わないことがあるため。
const { chromium } = require("playwright-core");
const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";

const FOLLOWING_RE = /^(フォロー中|Following)$/;

async function main() {
  const handle = process.argv[2];
  if (!handle) {
    console.log(JSON.stringify({ ok: false, error: "missing handle" }));
    process.exit(1);
  }

  let browser, page;
  try {
    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
  } catch (e) {
    console.log(JSON.stringify({ ok: false, status: "error", reason: "cdp: " + e.message }));
    return;
  }
  const ctx = browser.contexts()[0];
  if (!ctx) {
    console.log(JSON.stringify({ ok: false, status: "error", reason: "no context" }));
    return;
  }

  try {
    page = await ctx.newPage();
    await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(3500);

    // ログインが切れていれば、ボタンが無いのは当然。**「未フォロー」と混同しない。**
    if (/login|i\/flow/.test(page.url())) {
      console.log(JSON.stringify({ ok: false, status: "error", reason: "logged out" }));
      return;
    }

    // ① data-testid ② 「フォロー中」の文字、の順に探す
    let clicked = await page.evaluate(() => {
      const bs = Array.from(document.querySelectorAll("button,[role=button]"));
      const byId = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || ""));
      if (byId) { byId.click(); return { how: "testid", label: (byId.innerText || "").trim() }; }
      const byText = bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
      if (byText) { byText.click(); return { how: "text", label: (byText.innerText || "").trim() }; }
      return null;
    });

    if (!clicked) {
      console.log(JSON.stringify({ ok: false, status: "not_following", reason: "no unfollow button" }));
      return;
    }

    await page.waitForTimeout(900);
    const confirm = await page
      .waitForSelector('[data-testid="confirmationSheetConfirm"]', { state: "visible", timeout: 4000 })
      .catch(() => null);
    if (confirm) {
      await confirm.click();
      await page.waitForTimeout(1500);
    }

    // **外れたか。** 「フォロー」に戻っていれば外れている
    const after = await page.evaluate(() => {
      const bs = Array.from(document.querySelectorAll("button,[role=button]"));
      const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
      return t ? { testid: t.getAttribute("data-testid") || "", text: (t.innerText || "").trim() } : null;
    });
    if (after && /-follow$/i.test(after.testid) && !/-unfollow$/i.test(after.testid)) {
      console.log(JSON.stringify({ ok: true, status: "unfollowed", how: clicked.how }));
    } else {
      console.log(JSON.stringify({
        ok: false, status: "unconfirmed",
        reason: "no follow button visible after unfollow",
        after: after || null, how: clicked.how,
      }));
    }
```
**LLM を呼んでいない（$0／回・$0／日・$0／月）。外す操作は 1 件だけ（本来の仕事）。**
