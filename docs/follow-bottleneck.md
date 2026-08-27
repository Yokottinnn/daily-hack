# フォローが伸びない原因（2026-08-28 実測）

出典: `ops/heartbeat` ブランチの `reports/follow-bottleneck.md`（`ops/tasks/033` の結果）。
**推測ではなく実機のログとコードで確かめたもの。**

## 訂正 — 「cap を上げても意味がない」は誤りだった

2026-08-27 に「実績 0/5 なので cap を 10 にしても 0/10 になるだけ」と報告したが、**これは誤り。**
`competitor-follower-follow.js:132` を読むと、`DAILY_CAP` は成功件数の上限ではなく
**試行する候補の件数**を決めている。

```javascript
const targets = scrapedHandles.filter(h => !followed.has(h.toLowerCase())).slice(0, DAILY_CAP);
log(`new targets (after dedup): ${targets.length}`);   // → 常に 5（= cap）
```

だから `0/5` は「5 件 試して 0 件 成功」であって「候補が 0」ではない。
**cap を 10 にすれば 10 件 試すので、成功も概ね倍になる。** PR #236 は効く。

## 本当の詰まりは通過率の低さ

直近 200 行の内訳（`competitor-follower-follow`）。

| 弾いた理由 | 件数 | 割合 |
| --- | ---: | ---: |
| follower count out of range（100〜10000 の外） | 34 | **48%** |
| inactive（最終投稿が古い） | 11 | 15% |
| no follow button（鍵/ブロック/削除） | 6 | 8% |
| low-density bio | 6 | 8% |
| follower >> following（フォロバ率低） | 9 | 13% |
| Phase 2: no relevant topic in bio | 4 | 6% |
| random-looking handle | 1 | 1% |

**半分がフォロワー数のレンジで落ちている。** 100〜10000 の外というのは、
実測では 30000 / 69000 / 35000 / 91000 のような**大きいアカウント**。
ポイ活・節約ジャンルは 1 万人超のアカウントが珍しくないので、
このレンジは**ジャンルの実態と合っていない可能性**がある（判定は未実施）。

## 供給側も細い

| 事実 | 根拠 |
| --- | --- |
| 競合の巡回先は **6 件だけ**（`day-rotation index=0/6`） | ログの start 行 |
| 1 回に取れるフォロワーは **47〜65 件** | `scraped 47 followers from ...` |
| **日曜と月曜は走らない**（`Sun/Mon skip policy`） | `competitor-follower-follow.js:113` / `hashtag-follow.js:88` |
| `hashtag-follow` の **2 回目の発火は常に候補 0** | 08:00 の回が毎日 `trend candidates: 0` |

日月を休むのは 7 日中 2 日、**機会の 28%**。
`hashtag-follow` の 2 回目が常に空なのは、01:15 の回がその日のトレンドを消費しきるため。

## 過去の CDP 障害は解消済み

`connectOverCDP: Timeout` / `ECONNREFUSED 127.0.0.1:18800` は
**2026-07-30〜08-07 の記録**で、現在は出ていない（ポートが 18810 に移った件は解消済み）。
**いまの 0 件は接続障害が原因ではない。**

## 効く順に並べると

1. **cap を上げる**（#236 / 試行数が直接増える。API 費用 $0）
2. **フォロワー数レンジを見直す**（48% がここで落ちている。`follow-handle.js`）
3. **競合の巡回先を 6 件から増やす**（供給そのものを太くする）
4. **日月の休止を外す**（機会が 28% 増える。ただしスパム判定リスクとの兼ね合い）
5. `hashtag-follow` の 2 回目の空振りを直す

**1〜5 はどれも LLM を使わないので Anthropic への課金は増えない（$0/回・$0/日・$0/月）。**
増えるのは X 側のスパム判定リスクだけなので、**一度に全部はやらない。**
