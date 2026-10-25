# X のアクションの間隔と上限（シャドウバン対策）

2026-10-26 に利用者の指示で作った（CLAUDE.md 最上位ルール 23）。

> 大至急このツイートを確認してシャドウバンされないようにして
> 1日の中でも必ず間隔をおいて各種アクションをするようにして
> これは明確にルールとスキルに記録して、絶対に守られる体制とシステムを作って

参考: @SakuyaAkiV「シャドウバンの原因5選（交流ポスト編）」（2026-10-24・`status/2113868414569857208`）。
リプライ＋ポスト＋リポスト 25 回/30 分、いいね 20 回/30 分、フォロー 8 回/30 分、ハッシュタグ 2 個まで、メンションのしすぎ。

## 上限（全ジョブの合算）

| 種類（台帳のキー） | X のリクエスト | 30 分あたり | 間隔 |
| --- | --- | --- | --- |
| `tweet` | `CreateTweet` / `CreateNoteTweet` / `CreateRetweet` | 12 | 60 秒 |
| `like` | `FavoriteTweet` | 10 | 45 秒 |
| `follow` | `1.1/friendships/create.json` | 4 | 180 秒 |
| `unfollow` | `1.1/friendships/destroy.json` | 6 | 120 秒 |

値は `ops/lib/x-action-pacer.cjs` の `LIMITS`。**変えるときはここと CLAUDE.md の表も直す。**

## 仕組み（2 段）

```text
ジョブ（node）
  ├─ 押す前: x-action-pacer.cjs until <種類> 150 … 空くまで待つ（記録しない）。空かなければ押さずに終わる
  └─ 押した: X へのリクエスト
        └─ 関所 x-action-guard.cjs（NODE_OPTIONS=--require で全ジョブに入る）
              ├─ 空いている → 台帳に記録して通す
              └─ 上限・間隔に当たる → その場で止める（abort）。待たない
```

- **関所が本体。** スクリプトが待つのを忘れても、リクエストの段で止まる。だから「絶対に守られる」
- **関所は待たない。** 待つとスクリプトの時間切れと重なり、「出たのに失敗扱い」→ 再送、が起きうる
- 台帳: `~/.openclaw/workspace/data/x-action-ledger.json`。ジョブをまたいで 1 つ。書くときは mkdir のロック
- **数えるのは押した回数**（成功・失敗を問わない）。数え漏れより数えすぎに倒す
- 関所のファイルが壊れていても、ジョブは今までどおり動く（素通し）。台帳のロックが取れないときは**止める**側

## 入れた場所（x352）

- `~/.openclaw/workspace/lib/x-action-pacer.cjs` / `x-action-guard.cjs`
- `ai.openclaw.*` と `com.dailyhack.*`（`ops-heartbeat` 以外）の plist の `EnvironmentVariables:NODE_OPTIONS`
- `scripts/post-comment.js`（返信）・`scripts/follow-handle.js`（フォロー）の先頭に「空くまで待つ」

## 見る

```bash
node ~/.openclaw/workspace/lib/x-action-pacer.cjs status   # 直近 30 分の数
grep 'x-action-guard' ~/.openclaw/workspace/logs/*.log      # 止めた記録（各ジョブのログの stderr）
```

## 新しいジョブを作るとき

- plist に `NODE_OPTIONS=--require /Users/ny/.openclaw/workspace/lib/x-action-guard.cjs` を入れる
- 押す前に `x-action-pacer.cjs until <種類> <秒>` を呼ぶ（または `require` して `waitFree`）
- 1 回の起動でまとめて押す設計にしない。**件数を増やすなら起動の回数を増やして散らす**
