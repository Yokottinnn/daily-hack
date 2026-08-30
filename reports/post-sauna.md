# サウナ告知を X へ出す（2026-08-30 22:13 JST）

> 承認済み。**調べて、出すところまで 1 回でやる。**
> **二重投稿はしない。** 開始前に確認し、ロックを置く。

## 0. もう出ていないか

- 該当する投稿済みエントリ: **0 件**
- ロックを置いた

## 1. 画像を用意する

- 1-summary.jpg: 273571 B
- 2-maihama.jpg: 307907 B
- 3-takanawa.jpg: 187614 B
- 4-oimachi.jpg: 199574 B
- 用意できた枚数: **4/4**
- 1-summary.jpg は差し替え版（273571 B）

## 2. 出す口を調べる（**実物を読んでから撃つ**）

### auto-x-publisher.js
```javascript
5: * Usage: node auto-x-publisher.js <kind>
25:const QPATH = `${WS}/data/post_queue.json`;
41:const KIND = process.argv[2];
43:  console.error("usage: node auto-x-publisher.js <blog-promo|trend_post|trend_qt>");
174:  const list = q.queue;
235:  const e2 = q2.queue.find(x => x.id === e.id);
```
### queue-manager.js（enqueue の受け口）
```javascript
6: *   next-pending [--kind <k>]            → first entry with status=pending, optionally filtered by kind
8: *   list-awaiting [--kind <k>]            → entries with status=awaiting_approval
13: *   enqueue                               → reads JSON object from stdin, validates, appends to queue
15: * Entry kinds:
51:      const kind = parseFlag(args, "kind");
63:        (!kind || x.kind === kind || (!x.kind && kind === "post")));
73:      const kind = parseFlag(args, "kind");
74:      const all = q.queue.filter(x => x.status === "awaiting_approval" && (!kind || x.kind === kind || (!x.kind && kind === "post")));
106:      // 従来は kind を問わず一律 awaiting_approval にしていたため、承認不要のはずの
109:      e.status = NO_APPROVAL.includes(String(e.kind || "")) ? "pending" : "awaiting_approval";
138:    case "enqueue": {
145:          if (!obj.id || !obj.kind || !obj.text) {
146:            console.log(JSON.stringify({ ok: false, error: "id, kind, text required" }));
```

- 採る経路: **B**

## 3. 投稿

経路B: queue-manager.js で積んで auto-x-publisher.js を id 指定で叩く
```
{"ok":true,"id":"明日 8/31、門前仲町に「門仲SAUNAS LO」がオープンするわ。\n銭湯とマンションが併設で、サウナは男性3室・
```
```
usage: node auto-x-publisher.js <blog-promo|trend_post|trend_qt>
```

## 4. 出た件数を数える（**2 件以上なら事故**）

- 投稿済みエントリ: 前 0 件 → 後 **0 件**
- **出ていない。** ロックを外すので次の周回で再試行される
