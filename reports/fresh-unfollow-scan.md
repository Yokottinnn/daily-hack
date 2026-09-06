# いまの条件で外すべき相手を外す（2026-09-06 22:46 JST・費用 $0）

> **古いキューは使わない。** 期限到来 197 件はいちばん古いもので 30 日以上 前。
> その間に手で外された相手や、あとからフォロバした相手が混ざっている。
> **いまの `/following` と `/followers` をその場で読んで決める。**

判定は 4 つ全部を満たすものだけ。

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
- /Users/ny/.openclaw/workspace/[eval]
    at Module._resolveFilename (node:internal/modules/cjs/loader:1475:15)
    at wrapResolveFilename (node:internal/modules/cjs/loader:1048:27)
    at defaultResolveImplForCJSLoading (node:internal/modules/cjs/loader:1072:10)
    at resolveForCJSWithHooks (node:internal/modules/cjs/loader:1093:12)
    at Module._load (node:internal/modules/cjs/loader:1261:25)
    at wrapModuleLoad (node:internal/modules/cjs/loader:255:19)
    at Module.require (node:internal/modules/cjs/loader:1575:12)
    at require (node:internal/modules/helpers:191:16)
    at [eval]:2:22
    at runScriptInThisContext (node:internal/vm:219:10) {
  code: 'MODULE_NOT_FOUND',
  requireStack: [ '/Users/ny/.openclaw/workspace/[eval]' ]
}

Node.js v26.0.0
```

---

**5 件を超えて外していない。フォローも投稿もしていない。LLM も呼んでいない（$0）。**
