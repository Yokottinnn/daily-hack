# 種アカウントの配列

**このレポートが作られた時刻: 2026-09-20 16:17:29 JST**

> x94 で確定: 一覧は **`competitor-follower-follow.js` に直書き**、
> 回し方は **`day-of-week mod len(competitors)`**（1 日 1 種・7 種で週 1 巡）。
>
> **1 つの種が全体の 1/7。** 返り率 4.2% の種を残すと、週 1 日ぶんがそこに消える。

**読むだけ。1 文字も変えない。**

## 1. ファイルの基本情報

```
  171 行 / 最終更新 2026-09-13 19:58
```

## 2. **配列の実物**（行番号つき・そのまま）

```javascript
  16| const WS = "/Users/ny/.openclaw/workspace";
  17| const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
  18| const FOLLOWED_PATH = `${WS}/data/followed.json`;
  19| const REPLY_FOLLOWERS_PATH = `${WS}/data/reply-followers.json`;
  20| const LOG_PATH = `${WS}/logs/competitor-follower-follow.log`;
  21| const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
  22| const SLACK_TOKEN = JSON.parse(fs.readFileSync("/Users/ny/.openclaw/openclaw.json", "utf8")).channels.slack.botToken;
  23| const SLACK_CHANNEL = "C0A5FKU7T5M";
  24| const OWNER_USER_ID = "U0A5V22PVTQ";
  25| 
  26| // User-selected 7 competitors (A + B + C 2026-05-18)
  27| const COMPETITORS = [
  28|   "himawari56757", "ukk_hx", "POIKATSU_OTAKE",
  29|   "tokufree3", "okamiler_pn",
  30|   "money_yossy", "haiji_doctor",
  31| ];
  32| 
  33| const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);
  34| const FOLLOW_GAP_MS = 30 * 1000;
  35| const SCRAPE_TARGET_COUNT = 60;
  36| const TODAY = new Date().toISOString().slice(0, 10);
  37| 
  38| function log(s) { try { fs.appendFileSync(LOG_PATH, `[${new Date().toISOString()}] ${s}\n`); } catch {} console.log(s); }
  39| 
  40| function slackPost(text) {
  41|   // 2026-07-25 migrated: silent_slack.json kind-based routing via slack-notify.js
  42|   try {
```

## 3. 回し方の実物（**day-rotation の箇所**）

```javascript
  6: * Daily rotation: day-of-week mod len(competitors) で 1 competitor 選定、 follower list 先頭から scrape
  111:  const todayDow = todayDate.getDay();
  117:  const dayIndex = Math.floor(todayDate.getTime() / 86400000) % COMPETITORS.length;
  118:  const competitor = COMPETITORS[dayIndex];
  119:  log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITORS.length-1}) cap=${DAILY_CAP} ===`);
```

**1 日 1 種なので、配列から外すだけで枠が良い種に回る。** 量は変わらない。

## 4. 除外の仕組みがあるか（配列を触らずに済むか）

```
  113:    log(`=== competitor-follower SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
  136:    await slackPost(`<@${OWNER_USER_ID}> 🌐 Tier B (@${competitor}): 全 follower 既 follow か対象なし、skip`);

  --- 環境変数で上書きできるか ---
  21:const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
  33:const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);
  112:  if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
```

**環境変数で種を渡せるなら、plist を書き換えるだけで済む。**
その場合、スクリプト本体を触らなくてよい（元に戻すのも簡単）。

## 5. 費用

**ソースを読むだけ。LLM を呼ばない。フォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**種を入れ替える場合も $0。** このジョブは DOM 操作のみで LLM を呼ばないため、
**フォロー数を変えても API 費用は動かない。**
返信ループの実測は 1 回 $0.003 ／ 1 日 $0.021 ／ 1 か月 約 $0.63。
