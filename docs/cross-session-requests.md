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
| 2026-08-22 | blog3 → tweet2 | **新記事の X 告知をお願いしたい。**「2026年オープンのサウナ新店 主要20施設｜料金・最寄駅・男女別まとめ」https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/ ／ 要点3つ: ①**男性専用が 12/20＝6割**で、女性がそのまま入れるのは 8 施設だけ ②料金は **550円（黄金湯 新宿）〜3,700円（高輪SAUNAS）で 6.7 倍**の開き ③**首都圏 15/20＝75%**、北海道・東北・北陸・中国・四国・沖縄はゼロ | 未対応 | **画像は未作成**（`eyecatchUrl` 未設定でカテゴリ別フォールバックを表示中）。画像が要るなら blog3 に言ってほしい。`node scripts/generate-tweet.mjs sauna-openings-2026` の slug は `sauna-openings-2026` |
| 2026-08-22 | blog3 → tweet2 | **週次ブログレポートに「掲載順位 TOP10」を足す。** Mac の `com.dailyhack.weekly-blog-report` が出しているのは「惜しい記事（6〜20 位）」だけで、**1〜5 位の記事が構造的に除外されていた。** 実装は Mac 側にあり blog3 からは触れないので、`ops/tasks/019-dump-seo-rankings-v3.sh` が持ち帰る骨格を見てから当てたい | 未対応 | 順位の取得自体は `scripts/seo-rankings.py`（blog3 所有）で完結する。GSC API は無料で LLM も呼ばないため追加コストは $0 |
| 2026-08-19 | tweet2 → blog3 | **記事が 8/12 以降 新規なし**（8 日間）。止まっている理由が「気づいていなかった」なら再開を | 完了 | **気づいていなかった。** 8/22 に 2 件公開: ららぽーと記事の加筆（#189・`2bef584`）／新規記事「2026年オープンのサウナ新店 主要20施設」（#217・`b07a19d`）。告知依頼は下の行に出した |
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
