# アンフォローを直す（x17 で外せた取り方にそろえる）

**このレポートが作られた時刻: 2026-09-13 15:25:59 JST**

> x53 の判定: **B. フォロー中なのに外せていない。**
> ボタンは在る（`2040770556531011584-unfollow` ／「フォロー中」）。
> **セレクタは正しい。取り方が違う。**

## 0. 前提

```
  CDP: 健全
  unfollow-handle.js: 在る（50 行）
  まだ work-window を使っている
```

## 1. `lib/work-window.js` は何をしていたのか

**ここが別コンテキスト（未ログイン）なら、ボタンが出ないのは当然。**

```javascript
// 117 行 / 最終更新 2026-08-09 17:52
"use strict";
/**
 * work-window.js — 自動化専用ウィンドウを作り、そこだけで作業する。
 *
 * 2026-08-09: Jordan の作業ウィンドウ（Gmail / Drive / freee / A8 等 17枚）に
 * 勝手にタブを開き、bringToFront で画面まで奪う事故を繰り返した。
 *
 * 設計の要点:
 *   1. 保護ウィンドウ一覧 (data/protected-windows.json) を持ち、そこには絶対に触れない
 *   2. 自動化は必ず **新規ウィンドウ** を作る。newWindow:false は使わない
 *      （Chrome は "最後にアクティブなウィンドウ" にタブを作るため、Jordan の画面に生える）
 *   3. タブを掴む前後で windowId を検証し、保護ウィンドウなら即座に閉じて例外を投げる
 *   4. bringToFront は呼ばない（画面を奪わない）
 */
const fs = require("fs");

const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const PROTECTED = "/Users/ny/.openclaw/workspace/data/protected-windows.json";
const STATE = "/Users/ny/.openclaw/workspace/data/automation-window.json";

function protectedWindows() {
  try { return JSON.parse(fs.readFileSync(PROTECTED, "utf8")).protected || []; }
  catch { return []; }
}
function loadState() { try { return JSON.parse(fs.readFileSync(STATE, "utf8")); } catch { return {}; } }
function saveState(s) { try { fs.writeFileSync(STATE, JSON.stringify(s, null, 2)); } catch {} }

async function windowIdOf(session, targetId) {
  try { return (await session.send("Browser.getWindowForTarget", { targetId })).windowId; }
  catch { return null; }
}

/**
 * 自動化専用ウィンドウに新しいタブを開く。
 * @<伏せ> {string} task 作業名（"x-post" / "x-follow" / "blog" 等）
 */
async function openWorkTab(task, opts = {}) {
  if (!task || typeof task !== "string") {
    throw new Error("openWorkTab: task 名は必須");
  }
  const { chromium } = require("playwright-core");
  const browser = await chromium.connectOverCDP(opts.cdp || CDP, { timeout: opts.timeout || 20000 });
  const context = browser.contexts()[0];
  const session = await browser.newBrowserCDPSession();
  const guarded = protectedWindows();

  // 自動化ウィンドウが生きているか確認
  const state = loadState();
  let ourWindowId = state.windowId || null;
  if (ourWindowId != null) {
    // 保護ウィンドウを自動化用として記録してしまっていたら破棄（安全側）
    if (guarded.includes(ourWindowId)) ourWindowId = null;
    else {
      try { await session.send("Browser.getWindowBounds", { windowId: ourWindowId }); }
      catch { ourWindowId = null; }
    }
  }

  // 一意の目印。Jordan の空タブを誤って掴まないため。
  const marker = `openclaw-${task}-${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
```

## 2. `unfollow-handle.js` を差し替える

**直したのは 3 つだけ。判定も出力の JSON も変えていない。**

| 直したところ | 理由 |
| --- | --- |
| work-window → `contexts()[0]` | x53 はこの取り方で**ボタンを見つけた** |
| `commit` → `domcontentloaded` | `commit` は**DOM がまだ無い**瞬間 |
| `browser.close()` を呼ばない | CDP 接続に対して呼ぶと **Chrome ごと落ちうる** |

あわせて、`…-unfollow` が取れないときは**「フォロー中」の文字でも探す。**
ログインが切れているときは `error` にする（**「未フォロー」と混同しない**）。

```
  差し替える中身の node --check: OK（108 行）
  退避: unfollow-handle.js.bak-20260913-152559
  対象の node --check: OK
  --- 差し替えた後 ---
    10://   ① work-window ではなく `contexts()[0]` を使う
    15://   ② `waitUntil: "commit"` → `"domcontentloaded"`
    19://   ③ `browser.close()` を呼ばない
    39:    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
    44:  const ctx = browser.contexts()[0];
    52:    await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 30000 });
```

## 3. **1 件だけ**試して、直ったか確かめる

**大量に外さない。** 直ったかを確かめるだけ。上限は今のまま。

```
  対象: 期限がいちばん古い 1 件（ハンドルは伏せる）
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x58-fix-unfollow-handle.sh: line 74: 95147 Terminated: 15          "$@" > "$outf" 2>&1
  --- 結果 ---
    {"ok":false,"status":"not_following","reason":"no unfollow button"}

  **`"status":"unfollowed"` なら直った。**
  `"not_following"` のままなら、原因は取り方ではない。
  `"logged out"` なら認証。`"unconfirmed"` なら押せたが戻っていない。
```

## 4. 滞留している数（**直れば減り始める**）

```
  期限到来: 328 件（30 日以上 放置が 223 件）
  いちばん古い: 2026-05-16

  09-12 の x09 時点: 197 件 → 09-13 の x53 時点: 322 件
  **外せていないので積み上がっている。**
```

## 5. 費用

**LLM を一切 呼ばない。** DOM を操作するだけ。**外すのは 1 件だけ。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

定時の返信ループは **推定** 1 回 $0.003 ／ 1 日 約 $0.19 ／ 1 か月 約 $5.8
（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。
