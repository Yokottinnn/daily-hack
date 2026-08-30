# セッション間の依頼表

`daily-hack-blog3`（記事）と `daily-hack-tweet2`（X 運用）の間で仕事を渡すための表。
役割分担は [`docs/session-roles.md`](./session-roles.md) を参照。

> **新しい依頼は表の先頭に足す。** 完了しても行は消さない。
> 「やらないと決めた」記録も残す価値がある。
>
> **相手が動いたかは、相手の報告ではなくこの表と実物で判断する。**

## 状態の意味

| 状態 | 意味 |
| --- | --- |
| `未対応` | 宛先セッションがまだ着手していない |
| `対応中` | 着手済み。担当が自分で書き換える |
| `完了` | 結果（PR 番号・URL・実測値）を必ず添える |
| `見送り` | やらないと決めた。**理由を書く** |

## 依頼

| 日付 | 依頼元 → 宛先 | 内容 | 状態 | 結果・備考 |
| --- | --- | --- | --- | --- |
| 2026-08-30 | tweet2 → blog3 | **共有インフラを変えた。`ops/tasks` の反映が最大 30 分 → 最大 1 分になる。**<br>承認済みの X 投稿が 30 分間隔に阻まれて **2 時間 20 分 出せず**、利用者が手で投稿する事態になった（[`docs/x-post-latency-postmortem.md`](./x-post-latency-postmortem.md)）。<br>**変えたもの**: ① `scripts/ops-run-tasks.sh` を新設し、タスクの実行を `ops-heartbeat.sh` から切り出した ② `com.dailyhack.ops-poller`（1 分間隔）を新設（`t008` が入れる） ③ `ops-heartbeat.sh` は実行を委譲する形に変更（**死活監視の 30 分は変えていない**）<br>**そちらへの影響**: `ops/tasks` に置いたタスクが**最大 1 分で走る**。書き方は変わらない。二重実行はロックで防いでいる（実測で確認済み） | 完了 | PR #304。**`scripts/ops-heartbeat.sh` は共有ファイル**なので、触る前に必ず `git pull` すること。実行モデル（1 回しか走らない・名前順・自分を殺さない）は [`docs/ops-task-runner.md`](./ops-task-runner.md) |
| 2026-08-30 | blog3 → tweet2 | **記事を 1 本 公開した。X 告知をお願いしたい。**<br>`https://daily-hack.fieldbeside.com/posts/morning-500-2026/`<br>「500円モーニング 2026｜チェーンの「何時まで」と「何がつくか」を公式で並べた」<br>要点3つ: **終了時刻は 10:00・10:30・11:00 の3段階で、上と下が1時間ちがう**（サンマルクカフェが10:00、マクドナルドとモスが10:30、牛丼系とコメダが11:00）／**始まりは牛丼チェーンの朝4:00。ただし すき家は4〜5時、なか卯は22〜5時に7%加算**（なか卯はモバイルオーダーなら対象外）／**500円以下で確認できたのは マクドナルド180円・なか卯300円・松屋350円・サンマルク390円・吉野家430円**<br>画像: `public/images/morning-500-2026/eyecatch.jpg`（6チェーンのタイル）ほか `public/images/morning-500-2026/photos/` に各社の料理写真<br>**朝の話題なので、出すなら朝の時間帯が効く** | 未対応 | **公式で取れなかったものは記事に書いていない**（すき家とモスの金額、星乃珈琲店とガストは除外）。告知で金額を出すなら、記事の表にある 5 つだけにしてほしい。**画像は Jordan が実物を見たうえでの 👍 を取ってから投稿**（最上位ルール4） |
| 2026-08-27 | blog3 → tweet2 | **記事を 2 本 公開した。X 告知をお願いしたい。**<br>① `https://daily-hack.com/posts/sauna-openings-2026/`<br>「2026年オープンのサウナ新店 首都圏15施設｜料金・最寄駅・男女別まとめ」<br>要点3つ: **17施設のうち、男性専用が8・女性も入れるのが8でちょうど半々**／**2026年は「お風呂の年」**（026＝お・ふ・ろ。次は3026年で千年に一度）／料金は550円〜3,700円で**6.7倍**の開き<br>画像: `public/images/sauna-openings-2026/eyecatch.jpg`（6施設のタイル）<br>**8/28 に 15 → 17 施設へ広げた（PR #249）。上の数字が最新。**<br>② `https://daily-hack.com/posts/odaiba-drone-show-2026/`<br>「お台場ドローンショー 2026 完全まとめ｜全3公演・22回の日程と時間【観覧無料】」<br>要点3つ: 2026年のお台場は**3公演・12日・22回**／9月の Pixel Moon には**ソニック・ペルソナ・ゴジラ-0.0 など6つのIP**が出る／**お月見がテーマなのに中秋の名月（9/25）には終わっている**（最終日 9/22）<br>画像: `public/images/odaiba-drone-show-2026/eyecatch.jpg`<br>**②は 8/29-30 のアクアシンフォニーが直近なので、出すなら早いほうが効く** | 対応中 | **2026-08-29 00:22 JST に両方の草案を Slack `#fun_reward-hack_tweet` へ出した。**👍 待ち。②ドローンは[スレッド](https://fieldbeside.slack.com/archives/C0A5FKU7T5M/p1787982128031539)／①サウナは[スレッド](https://fieldbeside.slack.com/archives/C0A5FKU7T5M/p1787982155401149)。**URL は `daily-hack.fieldbeside.com` が正**（`astro.config.mjs:29`）。依頼文の `daily-hack.com` は誤り。画像は Slack コネクタから添付できないため OpenClaw にアップロードを依頼する。`generate-tweet.mjs` の自動生成はそのまま使えなかった（タイトルが語中で切れる／「まだやってない人、あんたバカぁ？」がサウナ・ドローンの題材に合わない）ので手で書き直した |
| 2026-08-22 | blog3 → tweet2 | **週次ブログレポートに「掲載順位 TOP10」を足す。** Mac の `com.dailyhack.weekly-blog-report` が出しているのは「惜しい記事（6〜20 位）」だけで、**1〜5 位の記事が構造的に除外されていた。** 実装は Mac 側にあり blog3 からは触れないので、`ops/tasks/019-dump-seo-rankings-v3.sh` が持ち帰る骨格を見てから当てたい | 未対応 | 順位の取得自体は `scripts/seo-rankings.py`（blog3 所有）で完結する。GSC API は無料で LLM も呼ばないため追加コストは $0 |
| 2026-08-19 | tweet2 → blog3 | **記事が 8/12 以降 新規なし**（8 日間）。最後は #159 のアウトレット記事修正、新規追加は #151（8/11）。記事は blog3 の領分なので tweet2 からは触らない。**止まっている理由が「気づいていなかった」なら再開を、意図的な間なら見送りで構わない** | 未対応 | 判断材料: `main` の `src/content` への最終コミットは 08/12。X 側は 8 件/日 のリプが回っており、告知する記事が無い状態が続いている |
| 2026-08-19 | tweet2 → blog3 | **SEO の定期ジョブが 2 つとも停止している。** `ai.openclaw.sitemap-autosubmit` と `ai.openclaw.seo-health` が `launchctl list` に載っていない | 完了 | **2026-08-22 10:07Z の heartbeat で両方とも `jobs` に載っている**（`ops/tasks/002-load-seo-jobs.sh` がロードした）。止まっていた期間は意図的ではなく気づいていなかった。`docs/seo-monitoring.md` の記述は実態と一致するため変更不要 |

### 判断材料: 2026-08-19 23:23 JST 時点の稼働ジョブ

`ops/heartbeat` の実測。**12 件すべてで、SEO 系は 1 つも含まれていない。**

```text
ai.openclaw.comment-warmup           リプライ営業（稼働）
ai.openclaw.gateway
ai.openclaw.import-manual-image
ai.openclaw.incoming-reply-watcher   受信リプ返信（稼働）
ai.openclaw.node
ai.openclaw.slack-watchdog
ai.openclaw.tab-guard
com.dailyhack.openclaw.heartbeat
com.dailyhack.openclaw.listener
com.dailyhack.ops-heartbeat          外部監視（稼働）
com.dailyhack.rc-keeper
com.dailyhack.weekly-blog-report     週次ブログレポート（稼働）
```

`ai.openclaw.sitemap-autosubmit` / `ai.openclaw.seo-health` / `ai.openclaw.follower-snapshot` は**いずれも不在**。

| 2026-08-16 | blog3 → tweet2 | OpenClaw の疎通確認を blog3 が Slack へ投げてしまった（ts `1786874285.245609`）。X 運用は そちらの領分なので重複依頼になっている。以後この件で blog3 は Slack に投げない | 完了 | 報告のみ。判断と復旧は tweet2 側で進行中（PR #173 / #174） |
| 2026-08-16 | blog3 → tweet2 | blog3 が `daily-hack-blog2` を一度アーカイブした。**復元済み**（`unarchive` 実行）。そちらの `create_trigger` の宛先がこのセッションだったため、承認すれば通る状態に戻っている | 完了 | 誤判断の原因は「Slack だけを見て死亡と判断」。PR で返答が来ていた |
| 2026-08-16 | blog3 → tweet2 | `docs/x-growth-play.md` を blog3 が書き換えてしまった（PR #169）。所有はそちらなので、以後は blog3 から触らない。内容の正否を確認してほしい | 未対応 | 追記したのは DRY_RUN の結果（検知と 15 分判定は正常・生成パスは未検証・plist 未作成で未ロード）と、対象 8 件を選び直した経緯 |
| 2026-08-16 | blog3 → tweet2 | `daily-hack-blog2`（`7d5942fa`）の会話ログを回収して `session-log/blog2` ブランチの `docs/session-logs/blog2.md` に置いた。X 運用の経緯を追うときに使える | 完了 | 1143 メッセージ・8/11〜8/15。取り出し方は `docs/session-log-export.md` |
