# 取得元が未記録のロゴを取り直す・その2（共通ポイントと流通）（t184・**$0**）

生成: **2026-09-23T23:33:09+0900**

**取得元が記録されていないロゴを、公式サイトから取り直す。**
**URL は推測せず、実ブラウザの検索で突き止める。**

- CDP **生きている** / `playwright-core`: `/Users/ny/.openclaw/workspace/node_modules/playwright-core`

/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/utils/isomorphic/assert.js:26
    throw new Error(message || "Assertion error");
          ^

Error: targetInfo: {
  "targetId": "60B19013CF282EF51739CB054426E2B8",
  "type": "shared_worker",
  "title": "",
  "url": "blob:https://www.ana.co.jp/1dd77b1c-5a74-4def-b96e-cf2e9be05cc9",
  "attached": true,
  "canAccessOpener": false
}
    at assert (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/utils/isomorphic/assert.js:26:11)
    at CRBrowser._onAttachedToTarget (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crBrowser.js:140:30)
    at CRSession.emit (node:events:509:20)
    at /Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crConnection.js:138:14

Node.js v26.0.0

---

**0 件 持ち帰った。** 経過 **3 秒**。

**採否はクラウド側でコンタクトシートを見て決める。**
**採ったものは `_manifest.json` に取得元 URL と取得日を残す**（最上位ルール 17）。
