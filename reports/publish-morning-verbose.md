# エラーの全文を取ってから出す（2026-09-05 22:10 JST・費用 $0）

> `t049` は **CDP の口が 18810 で生きている**ところまで突き止めたが、
> 本投稿の実行で落ちた。**そのエラー本文を、私のマスクと `cut` が食い潰した。**
> このタスクは **`cut` で切らず、マスクを秘密だけに絞って**全文を残す。

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. 画像を取り直す

```
  1-summary.jpg    250062 → 250062 bytes
  2-matsuya.jpg    157075 → 157075 bytes
  3-komeda.jpg     171572 → 171572 bytes
  4-sukiya.jpg     212141 → 212141 bytes
```

## 2. X にログインできているか

`ensure-chrome.sh` の但し書き: **cookie がディスクに永続化できておらず、再起動＝即ログアウト。**

### `cdp-health.js`

```
{"ok":true,"healthy":true,"round_trip_ms":381,"product":"Chrome/140.0.7339.207","tabs":2}
(rc=0)
```

### いま開いているタブ

```
page  about:blank#openclaw-follow-1788598689097-713365
page  chrome://newtab/
iframe  chrome-untrusted://new-tab-page/one-google-bar?paramsencoded=
```

**`x.com/login` や `/i/flow/login` が出ていればログアウトしている。**

## 3. 直近のログ（**切らずに出す**）

### `ensure-chrome.log` — 最終更新 2026-08-15 13:41

```
[2026-08-09T07:28:23Z] ensure-chrome: Chrome up and CDP responsive
[2026-08-09T08:47:53Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:03:24Z] ensure-chrome: Chrome failed to become CDP-responsive within 45s
[2026-08-09T23:09:02Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:10:47Z] ensure-chrome: peer repair did not finish within 150s
[2026-08-09T23:16:31Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:20:59Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:22:21Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:28:18Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:30:37Z] ensure-chrome: peer repair did not finish within 150s
[2026-08-09T23:32:08Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:34:15Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:37:09Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:40:12Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:42:28Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
[2026-08-09T23:44:48Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
[2026-08-09T23:47:55Z] ensure-chrome: Chrome failed to become CDP-responsive within 45s
[2026-08-09T23:53:27Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
[2026-08-09T23:54:50Z] ensure-chrome: peer repair did not finish within 150s
[2026-08-09T23:55:56Z] ensure-chrome: Chrome up and CDP responsive
[2026-08-09T23:55:56Z] ensure-chrome: logged out after restart — running x-login.js
[2026-08-10T00:49:55Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
[2026-08-10T00:50:58Z] ensure-chrome: Chrome failed to become CDP-responsive within 45s
[2026-08-13T15:37:03Z] ensure-chrome: Chrome failed to become CDP-responsive within 45s
[2026-08-15T04:41:51Z] ensure-chrome: Chrome up and CDP responsive
```


## 4. `post-via-playwright.js` のエラー処理

```javascript
5: * Output: {ok, tweet_id?, url?, error?, step?, image_attached?, captured_via?}
22:  if (!arg) { out({ ok: false, error: "missing text arg (base64)" }); process.exit(1); }
25:    out({ ok: false, step: "text-safety", error: "decode/validation failed", reason: decoded.reason, details: decoded.details });
37:  if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }
42:    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
44:    if (contexts.length === 0) { out({ ok: false, step, error: "no contexts" }); process.exit(1); }
48:    page.on("dialog", d => { d.dismiss().catch(() => {}); });
51:    await page.goto(COMPOSE_URL, { waitUntil: "domcontentloaded", timeout: 30000 });
54:    // 2026-07-06: X UI render 遅延で 20s timeout 発生 → 5s pre-wait + 30s に緩和 (post-comment.js と同様)
55:    await page.waitForTimeout(5000);
57:    await page.waitForSelector(textareaSelector, { timeout: 30000 });
63:    await page.waitForTimeout(800);
70:      if (!fileInput) throw new Error("file input not found on compose page");
76:      // よって条件は永遠に成立せず、.catch() で握り潰されたままアップロード途中で送信され、
91:        await page.waitForTimeout(2000);
95:        out({ ok: false, step, error: "画像のアップロードが完了しないため投稿を中止しました",
99:      console.error(`[post-via-playwright] attached ${attachedCount}/${want} image(s)`);
100:      await page.waitForTimeout(1500);
106:    const responsePromise = page.waitForResponse(
108:      { timeout: 30000 }
109:    ).catch(() => null);
125:      out({ ok: false, step, error: "X refused to enable the post button — nothing was posted",
134:    await page.locator(textareaSelector).first().click({ timeout: 10000 }).catch(async () => {
135:      await page.locator(textareaSelector).first().focus().catch(() => {});
137:    await page.waitForTimeout(300);
152:      } catch (e) { /* ignore */ }
156:    await page.waitForFunction(() => {
159:    }, { timeout: 15000 }).catch(() => null);
160:    await page.waitForTimeout(2500);
169:      await page.goto(TIMELINE_URL, { waitUntil: "domcontentloaded", timeout: 30000 });
170:      await page.waitForTimeout(2500);
199:      out({ ok: false, step, error: "tweet posted but couldn't capture tweet ID (graphql + scrape both failed)", image_attached: imageAttached });
209:    } catch (e) { /* watchdog spawn failure must not break main return */ }
217:  } catch (err) {
218:    if (page) try { await page.close(); } catch {}
219:    if (browser) try { await browser.close(); } catch {}
220:    out({ ok: false, step, error: err.message });
```

## 5. もう一度 出す（**全文を残す**）

```
[run-publish] thread_chain mode
{"ok":false,"step":"thread-main-exec","error":"Command failed: /usr/local/bin/node scripts/post-via-playwright.js \"44Ov44Oz44Kz44Kk44Oz44Gn6aOf44G544KM44KL6LaF57W244Kz44K544OR5pyd6aOf44KS44G+44Go44KB44Gf44KP44KI44CCCgrjg7vjg57jgq/jg4njg4rjg6vjg4kgMTgw5YaGIOOCveODvOOCu+ODvOOCuOODnuODleOCo+ODswrjg7vjgarjgYvlja8gMzAw5YaGIOOBlOOBr+OCk+ODu+OBv+OBneaxgeOBpOOBjeOBruWumumjnwrjg7vmnb7lsYsgMzUw5YaGIOeOieWtkOOBi+OBkeOBlOOBr+OCk++8i+Wwj+mJojLjgaQK44O744Kz44Oh44OAIOODieODquODs+OCr+S7o+OBoOOBkeOBp+ODkeODs+OBqOeOieWtkAoK44GX44GL44KC54mb5Li844OB44Kn44O844Oz44Gv5pydNDowMOOBi+OCiemWi+OBhOOBpuOCi+OAggrlgKTmrrXjga/lhajpg6jjgZ3jga7jg4Hjgqfjg7zjg7Pjga7lhazlvI/jgafnorrjgYvjgoHjgZ/jgoTjgaTjgojjgII=\" \"/Users/ny/.openclaw/workspace/data/x-morning-500/1-summary.jpg,/Users/ny/.openclaw/workspace/data/x-morning-500/2-matsuya.jpg,/Users/ny/.openclaw/workspace/data/x-morning-500/3-komeda.jpg,/Users/ny/.openclaw/workspace/data/x-morning-500/4-sukiya.jpg\"","thread_results":[]}
(rc=0)
```

## 6. [1/2] と [2/2] は両方 出たか

- 投稿済みエントリ: **0 件**（開始前 0 件）

```json
{
 "id": "blog-promo-20260905-morning-500-2026",
 "status": "pending",
 "x_tweet_id": null,
 "images": 4,
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "tweet_id": null,
   "posted": false
  },
  {
   "n": 2,
   "role": "cta",
   "tweet_id": null,
   "posted": false
  }
 ],
 "error": null
}
```

**2 本とも `posted: true` でなければ、出ていないか片肺。黙って「出ました」と言わない。**

---

**LLM を呼んでいない（$0）。** **X 上の手動投稿はキューからは見えない。**
