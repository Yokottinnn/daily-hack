# いまの条件で外すべき相手を外す v2（2026-09-06 23:18 JST・費用 $0）

> `x10` は `playwright` が `MODULE_NOT_FOUND` で落ちた。
> `cd $W` は効いていたが、**`playwright` は `$W/node_modules` に無い。**
> 既存の `post-via-playwright.js` は `scripts/` にあり、そこから解決されている。
> **一時スクリプトを `scripts/` に置いて実行する。**

判定は 4 つ全部を満たすものだけ（**古いキューは使わない**）。

1. いま自分がフォローしている
2. その相手が自分をフォローしていない
3. ホワイトリストに入っていない
4. フォローしてから **3 日以上** 経っている

**1 回に外すのは 5 件まで。**

## 実行

```
node:internal/modules/cjs/loader:1478
  throw err;
  ^

Error: Cannot find module 'playwright'
Require stack:
- /Users/ny/.openclaw/workspace/scripts/.x12-fresh-unfollow.js
    at Module._resolveFilename (node:internal/modules/cjs/loader:1475:15)
    at wrapResolveFilename (node:internal/modules/cjs/loader:1048:27)
    at defaultResolveImplForCJSLoading (node:internal/modules/cjs/loader:1072:10)
    at resolveForCJSWithHooks (node:internal/modules/cjs/loader:1093:12)
    at Module._load (node:internal/modules/cjs/loader:1261:25)
    at wrapModuleLoad (node:internal/modules/cjs/loader:255:19)
    at Module.require (node:internal/modules/cjs/loader:1575:12)
    at require (node:internal/modules/helpers:191:16)
    at Object.<anonymous> (/Users/ny/.openclaw/workspace/scripts/.x12-fresh-unfollow.js:1:22)
    at Module._compile (node:internal/modules/cjs/loader:1829:14) {
  code: 'MODULE_NOT_FOUND',
  requireStack: [ '/Users/ny/.openclaw/workspace/scripts/.x12-fresh-unfollow.js' ]
}

Node.js v26.0.0
(rc=1)
```

---

**5 件を超えて外していない。フォローも投稿もしていない。LLM も呼んでいない（$0）。**
