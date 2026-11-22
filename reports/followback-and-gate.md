# フォロー返しと判定本体（2026-09-23 00:07 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-23 00:07:54 JST**

> `x129` で診断が変わった。**的外れ 6 件 は「狙った相手」ではなく**
> **「向こうからフォローされたので返した相手」**だった（`badge-followback`）。
>
> フィルタの本体も別の場所で、2 つのスクリプトは `FOLLOW_HANDLE` に丸投げしていた。
> **パスは決め打ちしない。** 定義行から実体を解決する。

## 1. `FOLLOW_HANDLE` の実体はどこか

```
  ===== competitor-follower-follow.js の定義行 =====
    17:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
    149:      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${h}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2*1024*1024 });
  ===== hashtag-follow.js の定義行 =====
    22:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
    145:      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2 * 1024 * 1024 });

  **定義から解決できなかった。** scripts/ で follow を含むものを挙げる:
    audit-wrong-unfollows.js
    auto_detect_and_unfollow_inactive.js
    badge-followback.js
    check-current-follower.js
    check-followback.js
    check-follower-v2.js
    check-unfollowed-status.js
    competitor-follower-follow.js
    daily-follow-summary.js
    fetch-following.js
    follow-handle.js
    follow-up-reply.js
    follow-via-playwright.js
    follow-watchdog.js
    follower-daily-report.js
    follower-growth-monitor.js
    follower-snapshot.js
    follower-target-monitor.js
    hashtag-follow.js
    probe-followback-truth.js
    refollow-may18-incident.js
    reply-followback-check.js
    reply-followers-cleanup.js
    revenge-unfollow.js
    unfollow-cleanup.js
    unfollow-handle.js
    unfollow-stats-monitor.js
    unfollow-via-playwright.js
    unfollow_inactive_batch.js
    update_followed_after_cleanup.js
```

## 2. 判定の本体（**理由を返している箇所の全文**）

`x128` のログに出ていた文言で引く。**これが実際に弾いている条件。**

```javascript
  **実体が分からないので出せない**
```

**`name`（表示名）を一度も見ていなければ、そこが穴。**

```
```

## 3. フォロー返しの実装（**的外れ 6 件 の出どころ**）

```javascript
  // /Users/ny/.openclaw/workspace/scripts/badge-followback.js（222 行）
  // --- 相手を選ぶ／弾く箇所 ---
  25-          end: () => {
  26-            if (cb) cb({
  27-              statusCode: 200,
  28-              on: (ev, fn) => {
  29:                if (ev === "data") fn(Buffer.from('{"ok":true,"skipped":"silent_kind:' + SILENCE_SCRIPT_KIND + '","ts":"silenced"}'));
  30-                if (ev === "end") fn();
  31-              },
  32-            });
  33-          },
  34-        };
  35-        return fake;
  --
  40-      const __sn_orig_fetch = fetch;
  41-      global.fetch = async function(url, opts) {
  42-        const u = typeof url === "string" ? url : (url && url.url);
  43-        if (u && String(u).includes("slack.com")) {
  44:          const body = '{"ok":true,"skipped":"silent_kind:' + SILENCE_SCRIPT_KIND + '"}';
  45-          return { ok: true, status: 200, json: async () => JSON.parse(body), text: async () => body };
  46-        }
  47-        return __sn_orig_fetch(url, opts);
  48-      };
  49-    }
  50-    console.error("[silence-enforce] this script kind=" + SILENCE_SCRIPT_KIND + " is silent, slack HTTP calls suppressed");
  --
  164-    await page.waitForTimeout(2500);
  165-    try { await page.waitForSelector('[data-testid="UserCell"]', { timeout: 10000 }); } catch {}
  166-
  167-    const map = await scrollExtractVerified(page);
  168:    const verifiedFollowers = [...map.entries()].filter(([, v]) => v).map(([h]) => h);
  169-
  170-    const state = loadState();
  171-    const processed = new Set(state.processed);
  172-    const followedData = loadFollowed();
  173-    const alreadyFollowing = new Set((followedData.followed || []).map((a) => a.handle));
  174:    const candidates = verifiedFollowers.filter((h) => !processed.has(h));
  175-
  176-    log(`scanned=${map.size} verified=${verifiedFollowers.length} new_candidates=${candidates.length} DRY_RUN=${DRY_RUN} BASELINE_ONLY=${BASELINE_ONLY}`);
  177-
  178-    if (DRY_RUN) {
  179-      out({ ok: true, dry_run: true, scanned: map.size, verified: verifiedFollowers.length, new_candidates: candidates.length, sample: candidates.slice(0, 40) });
  180-      await browser.close().catch(() => {}); return;
```

**フォロー返しが `FOLLOW_HANDLE` を通しているかどうかが分かれ目。**
通していれば **1 か所 直すだけで両方 効く。** 通していなければ 2 か所 要る。

## 4. 載っているか

```
  ai.openclaw.badge-followback               runs=3 exit=0
  ai.openclaw.competitor-follower-follow     runs=9 exit=0
  ai.openclaw.hashtag-follow                 runs=9 exit=0
```

**`cron-poikatsu-follow` は 30 日間 0 件。** 止まっているなら、そこは直さなくてよい。

## 5. 直し方（**このタスクでは直さない**）

| 出方 | 次の一手 |
| --- | --- |
| フォロー返しが `FOLLOW_HANDLE` を通す | **判定本体に名前の条件を足すだけ。** 1 か所 |
| 通さない | **フォロー返し側にも足す。** 2 か所。片方だけだと漏れる |
| 判定本体が `name` を見ていない | `name` を取る所から足す |

**足す条件（案）。bio には適用しない**

```
  弾く    : 名前に 【公式】 / 公式アカウント / キャンペーン / 紹介コード / アフィリ
  弾く    : 名前に 株式会社 / (株) / Inc. / Corp.
  弾かない: bio の「公式」（「公式LINE」「公式ライバー」の個人で誤爆する）
```

**フォロー返しを弾くのは、能動フォローを弾くより慎重に。**
向こうは既にこちらをフォローしている。**返さないと外される**ことがある。

## 6. 費用

**ソースと launchctl を読むだけ。LLM を呼ばない。**
**フォローの判定も DOM だけなので、条件を足しても課金は増えない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
