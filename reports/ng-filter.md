# 返信 NG 判定の配置（2026-08-23T09:15:31Z）

## 1. 配置
- reply-ng-rules.json: 配置した（3246 B）
- reply-ng-check.cjs: 配置した（3006 B）

## 2. 実機での自己テスト

```
OK   売春の勧誘 → ng=true (hard)
OK   ポイ活の人（誤爆NG） → ng=false (never_ng)
OK   LINE誘導 → ng=true (link)
OK   絵文字3つ → ng=true (emoji)
OK   soft 2語 → ng=true (soft)
OK   soft だが節約垢 → ng=false (never_ng)
OK   普通の節約垢 → ng=false (never_ng)
OK   新規垢 → ng=true (new_account)
OK   無差別フォロー → ng=true (ratio)
OK   援交（節約語があっても弾く） → ng=true (hard)

全10ケース 期待どおり
```

## 3. ルールの規模
- hard（1語でNG）: 32 語
- soft（2語以上でNG）: 21 語
- NGドメイン: 16 件
- 絵文字（3個以上でNG）: 10 件
- 除外語（誤爆防止）: 19 語
- 作成 30 日未満は返信しない
- フォロー比 10 倍超は返信しない

## 4. 組み込み先（まだ差し込まない）

022 の調査結果を見てから決める。**推測で JS を書き換えない。**

返信を打つジョブの停止状態:
  ai.openclaw.comment-warmup                 停止
  ai.openclaw.incoming-reply-watcher         停止
  ai.openclaw.auto-thread-chainifier         停止
