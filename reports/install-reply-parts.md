# 返信の部品を Mac に入れる（2026-09-06 20:15 JST・費用 $0）

> **置くだけ。** ジョブは触らない（`comment-warmup` は未ロードのまま）。
> 置いたファイルは `comment-orchestrator.sh` が呼ばない限り 1 行も実行されない。
> **配線は次のタスクで、実物を読んだうえで行う。**
> 既存は `.bak.20260906-201513` に退避する。**元に戻せる状態を残す。**

## 0. 置く前の状態

```
  **無し** scripts/asuka-reply.cjs              
  **無し** scripts/reply-relevance-check.cjs    
  有り  scripts/tone-gate.cjs                      4611 B  更新 2026-08-29 00:51
  有り  scripts/reply-tone-check.cjs               3220 B  更新 2026-08-29 00:51
  有り  scripts/ng-filter-candidates.cjs           3177 B  更新 2026-08-27 22:38
  有り  scripts/reply-ng-check.cjs                 3006 B  更新 2026-08-27 22:38
  **無し** data/reply-style-prompt.json         
  **無し** data/reply-relevance-rules.json      
  有り  data/reply-ng-rules.json                   4160 B  更新 2026-08-28 00:40
  有り  data/reply-tone-rules.json                 3572 B  更新 2026-08-29 00:51
```

## 1. リポジトリを最新にする

```
  origin/main: 7f1f6a9 feat: 返信の配管を読む ＋ 部品を Mac に置く（$
```

## 2. 置く

```
  **新規**      asuka-reply.cjs                    11980 B
  **新規**      reply-relevance-check.cjs          18696 B
  同一・据置    tone-gate.cjs                      4611 B
  同一・据置    reply-tone-check.cjs               3220 B
  同一・据置    ng-filter-candidates.cjs           3177 B
  同一・据置    reply-ng-check.cjs                 3006 B
  **新規**      reply-style-prompt.json            10030 B
  **新規**      reply-relevance-rules.json         7882 B
  **置換**      reply-ng-rules.json                4160 → 3246 B（退避 .bak.20260906-201513）
  同一・据置    reply-tone-rules.json              3572 B
```

## 3. 置いたものが壊れていないか（**構文を通す**）

**置いただけで安心しない。** 読み込めないファイルは、呼ばれた瞬間に落ちる。

```
  構文OK  asuka-reply.cjs
  構文OK  reply-relevance-check.cjs
  構文OK  tone-gate.cjs
  構文OK  reply-tone-check.cjs
  構文OK  ng-filter-candidates.cjs
  構文OK  reply-ng-check.cjs
  JSON OK reply-style-prompt.json
  JSON OK reply-relevance-rules.json
  JSON OK reply-ng-rules.json
  JSON OK reply-tone-rules.json
```

## 4. `asuka-reply.cjs` が要るものは揃っているか

**require の相手が無ければ、呼ばれた瞬間に落ちる。**

```

  参照している data:
```

## 5. ジョブは触っていないことの確認

```
  comment-warmup: **未ロード（触っていない）**
```

---

**部品はすべて置けて、構文も通った。** 次は配線（`comment-orchestrator.sh`）。

**返信を生成していない。投稿していない。ジョブも触っていない（$0）。**
