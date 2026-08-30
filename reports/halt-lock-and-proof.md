# 停止ロックと、戻した 3 件が本当に働いているか（2026-08-31 02:14:55 JST）

> `23:57:03 JST` に **タブが 19 → 1 枚**になり、tab-guard が全自動化を停止した。
> **設計どおりの安全装置。** 故障ではない。

> **「ロード済み」と「働いている」は別。** 今日 2 回 これで外している。

## 1. 停止ロックは残っているか

### tab-guard.js が使うロックの定義
```javascript
27:const LOCK = "/tmp/x-login-in-progress";
```

- 上の候補にロックは**見つからなかった**（定義を読み違えている可能性もある）

## 2. Chrome は今どうなっているか

- Chrome プロセス: **生きている**
- 監視ポート: `18810`
- **いま開いているタブ: 1 枚**（発火時は 19 → 1）

⚠️ **まだ 1 枚以下、または CDP に届かない。**
この状態でロックを外しても、**tab-guard がまた発火するだけ**である。

## 3. 戻した 3 件は、戻したあと実際に働いたか

> `t012` が戻したのは **2026-08-31 の 01:0x JST 頃**。
> **それ以降にログが書かれていれば、働いている。**

| ジョブ | ロード | ログの最終更新 |
| --- | --- | --- |
| `comment-warmup` | 1 | 08-30 22:05 |
| `competitor-follower-follow` | 1 | 08-09 18:30 |
| `hashtag-follow` | 1 | 08-09 20:00 |

### 直近に更新された openclaw のログ（上位 12）
```
Aug 31 02:14 ops-poller.err.log
Aug 31 01:47 ops-heartbeat.log
Aug 31 01:47 ops-heartbeat-err.log
Aug 31 01:44 ops-poller.out.log
Aug 30 23:57 tab-guard.log
Aug 30 23:57 node.err.log
Aug 30 23:57 gateway.log
Aug 30 23:55 incoming-reply-watcher.log
Aug 30 23:45 import-manual-image.log
Aug 30 23:12 slack-watchdog.log
Aug 30 23:11 gateway.err.log
Aug 30 22:30 auto-detect-and-unfollow-inactive.log
```

## 4. 次の判断

**何も変更していない。ロックも消していない。**

- タブが戻っていて、Chrome も生きている → **ロックを外して本格再開してよい**
- **タブがまだ 1 枚**／Chrome が居ない → **外さない。** また同じことが起きる。
  先に Chrome を開き直す（＝人がやるほうが早い領域）
- ロックが見つからない → 定義の読み違い。2 章の `USER_PORT` と 1 章の grep を見直す

**根本の疑問は「なぜタブが 19 → 1 になったか」であり、まだ分かっていない。**
23:57 JST 前後に何が動いていたかを、次に調べること。
