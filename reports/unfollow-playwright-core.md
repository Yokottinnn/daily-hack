# いまの条件で外すべき相手を外す v4（2026-09-09 23:11 JST・費用 $0）

> **4 回 連続で落ちていたのは、私がパッケージ名を間違えていたから。**
> `playwright` はこのワークスペースに存在せず、実体は **`playwright-core`**。
> 稼働中の `post-via-playwright.js` / `unfollow-handle.js` / `post-comment.js` は
> **3 本とも `require("playwright-core")`** だった。
> 「cwd が違う」「node のバージョンが違う」という診断は**どちらも外れ**。

判定は 4 つ全部を満たすものだけ（**古いキューは使わない**）。

1. いま自分がフォローしている
2. その相手が自分をフォローしていない
3. ホワイトリストに入っていない
4. フォローしてから **3 日以上** 経っている

**1 回に外すのは 5 件まで。**

## 実行

```
  CDP に繋がらない: browserType.connectOverCDP: connect ECONNREFUSED 127.0.0.1:18810
Call log:
  - <ws preparing> retrieving websocket url f
(rc=0)
```

---

**5 件を超えて外していない。フォローも投稿もしていない。LLM も呼んでいない（$0）。**
