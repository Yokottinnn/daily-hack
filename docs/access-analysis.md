# アクセス分析ページ（月次）

利用者向けの分析は **Artifact で出す**（最上位ルール 21）。md は記録用。

| | |
| --- | --- |
| ページ | **https://claude.ai/artifact/5xN8owjKotz3ypbK7ov4PS**（同じ URL を毎月 更新する） |
| 生成 | `python3 scripts/access-analysis/build.py --gsc <json> --pv <json> --notes <json> --out <html>` |
| 検索データ | `scripts/gsc-dump.py`（Mac で走る。GSC の SA が Mac にしか無い） |
| 読者データ | `ops/pv-archive` ブランチの `data/<YYYY-MM>.json`（GitHub Actions が毎日 積む） |
| 結論・打ち手 | `ops/data/access-analysis/notes-<YYYY-MM>.json`（**数字を見たセッションが書く**） |
| 費用 | GSC API は無料・LLM API 不使用。**Console 課金 $0/回・$0/日・$0/月**。ルーティンのセッションはサブスクリプション枠 |

## 毎月の手順（月初 4 日のルーティンがやる）

GSC は確定まで 2〜3 日かかるので、**翌月 4 日以降**に前月分を取る。

1. `ops/tasks/m-gsc-<YYYY-MM>.sh` を作る（中身は `bash "$DAILY_HACK_REPO/scripts/access-analysis/run-gsc-dump.sh" <YYYY-MM>` ではなく、
   **`git show origin/main:scripts/access-analysis/run-gsc-dump.sh | bash -s <YYYY-MM>`**。クローンが古くても main の版が走る）
2. PR → CI → マージ（最上位ルール 12）。`ops/heartbeat` の `reports/gsc-monthly-<YYYY-MM>.json` が出るまで見る
3. `ops/pv-archive` の `data/<YYYY-MM>.json` を取る
4. 数字を読んで `notes-<YYYY-MM>.json` を書く。**数字に無いことは書かない**（最上位ルール 11・20）
5. `build.py` で HTML を作り、**Artifact に `url` を指定して publish し直す**（先に `action: "read"`）
6. 引き継ぎ記録を残す

## 窓

| キー | 期間 |
| --- | --- |
| `pages_cur` | 対象月 |
| `pages_prev` | その前の月 |
| `pages_90d` / `pq_90d` / `queries_90d` / `dates_90d` | 対象月を含む直近 3 か月 |

**2026-09 版だけは例外**で、t205 の 28 日窓（9/3〜9/30 と 8/6〜9/2）で作っている。
