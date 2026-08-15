# X 運用の外部監視

## なぜ必要か

2026-08-10、Chrome の自動更新（151）が Playwright の接続を壊し、**X 運用のジョブが全停止した。**
リプライ営業もフォロー施策も 5 日間ゼロだった。

問題は止まったこと自体より、**5 日間 誰も気づかなかったこと**にある。
異常を検知する `pipeline-heartbeat` が同じ Mac で動いていたため、Mac が倒れたときに
監視も一緒に倒れた。倒れたことを知らせる者がいなくなった。

同じ構造である限り、また 5 日間気づかない。そこで監視を Mac の外へ出す。

## 仕組み

**Mac は「生きている」と押すだけ。GitHub Actions が「来なくなったこと」を検知する。**

```text
Mac（30分ごと）                      GitHub Actions（2時間ごと）
  scripts/ops-heartbeat.sh             .github/workflows/ops-watchdog.yml
    launchctl list を集める        →     ops/heartbeat を取得
    ops/heartbeat に push                古さと欠落を判定
                                         異常なら Slack へ通知
```

Mac が丸ごと落ちても、**押されないこと自体が異常の証拠**になる。
監視する側が Mac の外にいるため、Mac と一緒に死なない（dead-man's-switch）。

## 判定条件

| 条件 | 閾値 | 意味 |
| --- | --- | --- |
| `stale` | heartbeat が **90 分**より古い | Mac が落ちている、または heartbeat ジョブが止まっている |
| `missing` | 期待するジョブが `launchctl list` に無い | Mac は生きているが特定のジョブだけ死んだ |

期待するジョブはワークフローの `EXPECTED_JOBS` で定義する。現在は次の 4 つ。

```text
ai.openclaw.comment-warmup          リプライ営業（10 reply/日）
ai.openclaw.incoming-reply-watcher  受信リプ返信（15分ごと）
ai.openclaw.gateway                 OpenClaw の入口
ai.openclaw.node                    本体
```

`poll-approvals` は**意図的に外している。** 滞留エントリの連鎖投稿を防ぐため停止させており、
再開したら `EXPECTED_JOBS` に足す。

## 押す側の設定（Mac）

`scripts/ops-heartbeat.sh` を 30 分ごとに実行する。

```bash
bash scripts/ops-heartbeat.sh
```

進行中の作業と衝突しないよう、**専用の worktree**（`~/.openclaw/ops-heartbeat-wt`）で動く。
リポジトリの作業ツリーには触らない。履歴が伸びないよう毎回 force push で 1 コミットに潰す。

環境変数で場所を変えられる。

| 変数 | 既定値 |
| --- | --- |
| `DAILY_HACK_REPO` | `/Users/ny/projects/anta-baka-x/blog` |
| `OPS_HEARTBEAT_WORKTREE` | `~/.openclaw/ops-heartbeat-wt` |
| `OPS_HEARTBEAT_BRANCH` | `ops/heartbeat` |

## 鳴らない状態を作らないために

- **`ops/heartbeat` ブランチが無い間、Slack には通知しない。** 登録前に鳴り続けるのを避けるため。
  代わりに Actions の Summary に「未設定」と出る。**未設定は監視ゼロと同じなので放置しない。**
- 異常検知時はワークフロー自体も `exit 1` で失敗させる。Slack を見落としても
  GitHub の失敗通知が残る。
- 通知は 2 時間ごとに繰り返す。うるさいのは意図的で、5 日間気づかなかった事故の再発を防ぐため。

## 監視が動いていることの確認

```bash
# 最新の heartbeat を見る
git fetch origin ops/heartbeat && git show origin/ops/heartbeat:heartbeat.json
```

ワークフローは手動でも起動できる（Actions タブの `ops-watchdog` → Run workflow）。
**閾値を跨いだときに実際に Slack が鳴るかは、一度手で確かめておくこと。**
鳴らない監視は無いのと同じで、それが今回の事故の本質だった。
