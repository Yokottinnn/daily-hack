# サウナ告知を X へ出す（t002 の失敗を直した版・2026-08-30 22:39 JST）

> t002 は **node -e の argv ずれ**と**publisher に id を渡した**ので出なかった。
> **読んでから形を合わせる。**

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. t002 が積んだ壊れたエントリを掃除する

- 壊れたエントリ: 1 件 削除

## 2. 契約を読む

### queue-manager.js の承認まわり
```javascript
50:    case "next-pending": {
67:    case "show": {
72:    case "list-awaiting": {
94:    case "list-by-status": {
100:    case "mark-drafted": {
108:      const NO_APPROVAL = ["comment", "reply"];
109:      e.status = NO_APPROVAL.includes(String(e.kind || "")) ? "pending" : "awaiting_approval";
116:    case "mark-skipped": {
126:    case "mark-posted": {
138:    case "enqueue": {
165:    case "mark-dm-sent": {
```

### auto-x-publisher.js の blog-promo と画像の受け口
```javascript
6: *   kind = blog-promo (== thread + blog-promo- prefix)
14: *  - blog-promo は image fresh DL (sha256 比較)
42:if (!["blog-promo", "trend_post", "trend_qt"].includes(KIND)) {
43:  console.error("usage: node auto-x-publisher.js <blog-promo|trend_post|trend_qt>");
129:  if (KIND === "blog-promo") {
131:    const postedToday = list.filter(e => e.status === "posted" && e.posted_at && e.posted_at.startsWith(todayDate) && e.kind === "thread" && (e.id
132:    if (postedToday.length > 0) return { skip: true, reason: "blog-promo already posted today" };
136:        e.kind === "thread" &&
137:        (e.id || "").startsWith("blog-promo-") &&
143:  if (KIND === "trend_post") {
144:    const postedToday = list.filter(e => e.status === "posted" && e.posted_at && e.posted_at.startsWith(todayDate) && e.kind === "trend_post");
149:        e.kind === "trend_post"
153:  if (KIND === "trend_qt") {
155:    const postedToday = list.filter(e => e.status === "posted" && e.posted_at && e.posted_at.startsWith(todayDate) && e.kind === "trend_qt");
160:        e.kind === "trend_qt"
192:  if (KIND === "trend_qt") {
213:  // blog-promo specific: refresh image
215:  if (KIND === "blog-promo") {
```

- 画像のフィールド名: **`images`**
- NO_APPROVAL: `NO_APPROVAL = ["comment", "reply"]`

## 3. 画像を用意する

- 1-summary.jpg: 273571 B
- 2-maihama.jpg: 307907 B
- 3-takanawa.jpg: 187614 B
- 4-oimachi.jpg: 199574 B

## 4. 積む（**argv は slice(1)。t002 のバグを直した**）

- id: `sauna-x-20260830-223943`（本文が入っていないことを確認）
```
{"ok":true,"id":"sauna-x-20260830-223943"}
```
- 積んだ直後の status: **pending**

## 5. 出す

```
{"ok":true,"action":"skip","reason":"no candidate","kind":"blog-promo"}
```

## 6. 件数（**2 件以上なら事故**）

- 前 0 件 → 後 **0 件**
- **出ていない。** ロックを外して次の周回で再試行
