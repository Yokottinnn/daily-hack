# 鍵を読めるところまで（t144・**API は呼ばない・$0**）

生成: **2026-09-21T02:14:32+0900**

## 1) 順番に辿る（**長さだけ出す。値は出さない**）

- 環境変数: 空
- `launchctl getenv`: **rc は 0 でも値は空**（← t142 はここを取り違えた）
- `com.bubblesnow.remote.plist`: 取り出せない
- `com.bubblesnow.remote.daily-hack.plist`: 取り出せない
- `com.bubblesnow.remote.daily-hack-blog.plist`: 取り出せない
- ⚠️ **どこからも読めない。** 新しい鍵を置いてもらう必要がある

## 2) 本番と同じ状態で選ばせる（origin/main を展開）

```text
対象: mens-hairremoval-comparison-2026（19593 文字 / 最終確認 未）
--dry-run のため API は呼ばない。ここで終わり。
```

**`ops/data/unindexed.txt` の先頭が出ていれば正しい**（未インデックスの記事から回す）。

## 3) 残り

- 1) が ✅ なら、**05:30 に 1 本 走って PR が出る**
- 1 回 **約 $0.07**（推定・Sonnet 5）／ 1 日 **約 $0.07** ／ 1 か月 **約 $2.1**
