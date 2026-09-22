# 的外れは誰が連れてきたか ＋ フィルタの実装（2026-09-22 23:48 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-22 23:48:43 JST**

> `x128` で直近 12 件 のうち **6 件 が的外れ**と分かった。
> **効く信号は `bio` ではなく `name`。** 既存のフィルタは bio しか見ていない。
>
> **直す前に、どのジョブが連れてきたかと、実装の全文を見る**（最上位ルール 15）。
> `x120` で決め打ちの grep をして「使っていない」と誤判定した。同じことをしない。

## 1. `source` の内訳（**誰が連れてきたか**）

```
  全 183 件

  source                              全体   直近30日
  --------------------------------------------------------
  badge-followback                      54        28
  cron-poikatsu-follow                 129         0

  --- 記録が持っているキー（最後の 1 件）---
    handle, followed_at, source, verified

  --- verified の内訳 ---
    true      54 件
    undefined 129 件
```

**`source` が 1 種類しか無ければ、直す場所も 1 つ。**
複数あれば、**全部に同じ条件を入れないと片側から漏れる。**

## 2. 入口フィルタの実装（**全文。行番号つき**）

**当て推量でパッチを書かないための材料。** 判定している箇所を丸ごと出す。

### competitor-follower-follow.js

```javascript
  // 総行数: 177
  // --- 判定・除外に関わる行（前後 4 行）---
  115-  // 🆕 2026-06-07: 日曜(0)・月曜(1) はFB率0%のためスキップ
  116-  const todayDate = new Date();
  117-  const todayDow = todayDate.getDay();
  118-  if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
  119:    log(`=== competitor-follower SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
  120-    process.exit(0);
  121-  }
  122-
  123-  const dayIndex = Math.floor(todayDate.getTime() / 86400000) % COMPETITORS.length;
  --
  138-  const targets = scrapedHandles.filter(h => !followed.has(h.toLowerCase())).slice(0, DAILY_CAP);
  139-  log(`new targets (after dedup): ${targets.length}`);
  140-
  141-  if (targets.length === 0) {
  142:    await slackPost(`<@${OWNER_USER_ID}> 🌐 Tier B (@${competitor}): 全 follower 既 follow か対象なし、skip`);
  143-    return;
  144-  }
  145-
  146-  const results = [];
  --
  148-    try {
  149-      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${h}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2*1024*1024 });
  150-      const r = JSON.parse(out.trim().split("\n").pop());
  151-      results.push({ handle: h, ok: r.ok, info: r });
  152:      log(`  @${h}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
  153-      if (r.ok) {
  154-        try {
  155-          const rf = fs.existsSync(REPLY_FOLLOWERS_PATH) ? JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8")) : {};
  156-          rf[h] = {
  --
  165-        } catch (e) { log(`    rf-write err: ${e.message}`); }
  166-      }
  167-    } catch (e) {
  168-      results.push({ handle: h, ok: false, error: e.message.slice(0, 200) });
  169:      log(`  @${h}: ❌ exec err`);
  170-    }
  171-    await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
  172-  }
  173-
```

### hashtag-follow.js

```javascript
  // 総行数: 177
  // --- 判定・除外に関わる行（前後 4 行）---
  84-(async () => {
  85-  // 🆕 2026-06-07: 日曜(0)・月曜(1) はFB率0%のためスキップ
  86-  const todayDow = new Date().getDay(); // JST近似 (UTC+9 offset考慮)
  87-  if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
  88:    log(`=== hashtag-follow SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
  89-    process.exit(0);
  90-  }
  91-
  92-  log(`=== hashtag-follow start (cap=${DAILY_CAP}) ===`);
  --
  130-  log(`today already follows: ${usedToday} (A:${alreadyTodayA}+B:${alreadyTodayB}) / DAILY_CAP=${DAILY_CAP} / remaining=${remaining}`);
  131-
  132-  if (remaining <= 0) {
  133-    log("cap reached, exit");
  134:    await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow: cap到達でskip (today=${usedToday}/${DAILY_CAP})`);
  135-    return;
  136-  }
  137-
  138-  const picks = targets.slice(0, remaining);
  --
  144-    try {
  145-      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2 * 1024 * 1024 });
  146-      const r = JSON.parse(out.trim().split("\n").pop());
  147-      results.push({ author: p.author, ok: r.ok, info: r });
  148:      log(`  @${p.author}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
  149-
  150-      // 5. record in reply-followers.json (live-check safety net for future unfollow)
  151-      if (r.ok) {
  152-        try {
  --
  165-        } catch (e) { log(`    rf-write err: ${e.message}`); }
  166-      }
  167-    } catch (e) {
  168-      results.push({ author: p.author, ok: false, error: e.message.slice(0, 200) });
  169:      log(`  @${p.author}: ❌ exec err: ${e.message.slice(0, 150)}`);
  170-    }
  171-    await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
  172-  }
  173-
```


## 3. 語彙はどこに書かれているか

**`off-niche` の判定語が外出しなら、JSON を足すだけで済む。**
ソースに直書きなら、スクリプトを触ることになる。

```
  ===== competitor-follower-follow.js =====
    22:const SLACK_TOKEN = JSON.parse(fs.readFileSync("/Users/ny/.openclaw/openclaw.json", "utf8")).channels.slack.botToken;

  ===== hashtag-follow.js =====
    26:const SLACK_TOKEN = JSON.parse(fs.readFileSync("/Users/ny/.openclaw/openclaw.json", "utf8")).channels.slack.botToken;

  --- data/ にそれらしい JSON があるか ---
    bookmark-learnings.json
    engagement_log.json
    following-snapshots
    grok-trending-state.json
    incoming-replies-handled.json
    incoming-reply-state.json
    post_queue.json.bak.20260513-eveningadd
    post_queue.json.bak.20260517-day12-revert-single
    reply-ng-rules.json
    reply-ng-rules.json.bak.20260906-201513
    reply-ng-rules.json.pre034.20260827-154041
    x-morning-500
```

## 4. 名前を見ているか（**ここが本題**）

`x128` の実物では、**的外れの根拠が全部 名前に出ていた。**

```
  【公式】LEGEND100
  リコ📱楽天モバイル従業員紹介キャンペーン
```

```javascript
  ===== competitor-follower-follow.js =====
  // name / displayName / 表示名 を触っている行

  ===== hashtag-follow.js =====
  // name / displayName / 表示名 を触っている行

```

**名前を一度も見ていなければ、そこが穴。** 次のタスクで足す。

## 5. 次に打つ手（**このタスクでは直さない**）

| 出方 | 次の一手 |
| --- | --- |
| 語彙が外出しの JSON | **JSON に足すだけ。** スクリプトを触らない |
| 語彙がソースに直書き | 名前の判定ごとスクリプトに足す |
| `source` が複数 | **全部に同じ条件を入れる。** 片側だけだと漏れる |
| 名前を見ていない | `name` の判定を新設する |

**名前で弾く条件（案）。bio には適用しない**

```
  弾く: 名前に 【公式】 / 公式アカウント / キャンペーン / 紹介コード / アフィリ
  弾く: 名前が 株式会社 / (株) / Inc. / Corp. を含む
  **弾かない**: bio の「公式」（個人の「公式LINE」「公式ライバー」で誤爆する）
```

## 6. 費用

**JSON とソースを読むだけ。LLM を呼ばない。**
**フォローの判定も DOM だけなので、条件を足しても課金は増えない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
