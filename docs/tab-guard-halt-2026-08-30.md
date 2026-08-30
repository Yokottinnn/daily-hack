# 2026-08-30 深夜、X の自動化が全停止した件

**結論から: 故障ではない。`tab-guard` が設計どおりに作動した。**

```
[2026-08-30T14:57:03.141Z] 🚨 Jordan のタブが 19 → 1 枚（一括破壊） → 自動化を全停止
```

**23:57:03 JST**（UTC 14:57:03）。利用者の Chrome のタブが **19 枚 → 1 枚**になり、
`tab-guard.js` が `ai.openclaw.*` を全部 unload した。

## 1. どう見えていたか

`ops/heartbeat` の稼働ジョブ数が急に減った。

| 時刻 (UTC) | 稼働ジョブ |
| --- | --- |
| 14:44 | **20 件** |
| 14:57 | ← ここで tab-guard が発火 |
| 15:14 | **6 件** |
| 15:44 | 7 件（+1 は新設した `ops-poller`） |

**14 件が一斉に消えた。**

## 2. なぜ「故障ではない」と分かったか

### 再起動ではない

```
uptime:  up 20 days
boottime: Mon Aug 10 18:38:54 2026
```

**20 日 動き続けている。** クラッシュでも再起動でもない。

### 落ち方に偏りがあった

| 対象 | 結果 |
| --- | --- |
| `ai.openclaw.*` | **ほぼ全滅** |
| `ai.openclaw.tab-guard` | **唯一 生き残った** |
| `com.dailyhack.*` | **無傷** |

`tab-guard.js` の `haltAutomation()` がまさにこの形をしている。

```js
execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do
  case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`)
```

**`ai.openclaw.*` を全部なめて、自分だけ除外する。** 観測と完全に一致した。

## 3. `tab-guard` は何をするものか

**利用者の Chrome のタブを守るための非常ブレーキ。** 30 秒間隔で見ている。

| 条件 | 内容 |
| --- | --- |
| A | **Chrome プロセスが消滅**（ウィンドウ全消え）＝ 最も許容できない事象 |
| B | タブが `MIN_TABS` を下回った |
| C | **一度に半分以上のタブが消えた** ← 今回はこれ |

発火すると 3 つのことをする。

1. **ロックファイルを書く**（`fs.writeFileSync(LOCK, "tab-guard")`）
2. `ai.openclaw.*` を unload（自分は除外）
3. 走っている js を `pkill`

> **CDP が重いだけの誤検知は避ける作りになっている。**
> `chromeAlive()` でプロセスの生存を別に見て、
> 「CDP 応答なし・プロセスは生存」なら判定しない。よく出来ている。

## 4. やったこと

利用者の判断は「**返信・フォローだけ先に戻す**」。

| ジョブ | 結果 |
| --- | --- |
| `ai.openclaw.comment-warmup` | ロード=1（`MAX_PICKS_PER_FIRE` は **2**＝正常値） |
| `ai.openclaw.competitor-follower-follow` | ロード=1 |
| `ai.openclaw.hashtag-follow` | ロード=1 |

**投稿系 11 件は意図的に戻していない。** 原因が未特定のうちに全部戻すと、
再開直後にまとめて出る事故が起きうる（2026-08-15 に実際に起きた）。

滞留は `awaiting_approval` が 16 件あるが、**`poll-approvals` は戻していない**ので
自動では出ない。TTL も効いている（`skipped_expired_ttl_7d` が 27 件）。

## 5. まだ分かっていないこと

### (1) **なぜタブが 19 → 1 になったのか**

**これが根本原因で、未解明。** 候補は次のとおりで、**どれも裏を取っていない。**

- 利用者が手で閉じた（23:57 は起きている時間帯）
- Chrome が再起動した（`ensure-chrome.sh` は cookie を永続化できず、再起動＝即ログアウト）
- 何かの自動化が閉じた

**当て推量で結論を書かない。** 23:57 JST 前後に何が動いていたかを調べること。

### (2) 停止ロックが残っているか

`haltAutomation()` はロックファイルを書く。**`t012` は unload を戻しただけで、
ロックには触っていない。** 残っていれば、ジョブが「ロード済み」でも働かない可能性がある。

> **「ロード済み」と「働いている」は別。**
> 2026-08-30 に 2 回これで外した（ポーラーが `last exit code = 127` だった件、
> `origin/main` と作業ツリーの取り違え）。**必ず実測で確かめる。**

`t015` が調べる。

## 6. 戻す前に確かめること

**タブが 1 枚のままロックを外しても、また発火するだけである。**

- [ ] タブが戻っているか（`/json/list` の `"type":"page"` の数）
- [ ] Chrome プロセスが生きているか
- [ ] 戻した 3 件が、戻したあと**実際にログを書いたか**
- [ ] **19 → 1 の原因**が分かったか（分からないなら、残り 11 件は戻さない）

## 7. 関連

- `ops/tasks` の実行モデル: [`ops-task-runner.md`](ops-task-runner.md)
- 投稿が遅れた件の分析: [`x-post-latency-postmortem.md`](x-post-latency-postmortem.md)
- 反復ジョブの実額: [`recurring-job-costs.md`](recurring-job-costs.md)
