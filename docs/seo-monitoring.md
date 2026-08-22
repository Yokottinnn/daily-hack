# SEO 監視の構成

最終更新: 2026-08-22

## なぜこれがあるのか（障害の記録）

**サイトマップが 2026-06-05 以降 Google に取得されず、163 URL が「Google が存在を知らない」まま約2ヶ月放置された。**

検知できなかった理由は2つ:

1. `.github/workflows/weekly-pv-report.yml` の Slack 通知ステップが
   `if: ${{ env.SLACK_WEBHOOK_URL != '' }}` という条件付きだったが、
   **`SLACK_WEBHOOK_URL` という Secret は一度も設定されていなかった**。
   → 作られた日から全実行で `skipped`。エラーにならずジョブは緑のままなので、
   「通知が来ない」ことに気づく手段がゼロだった。
2. 監視内容が Cloudflare の PV だけで、サイトマップ鮮度も Search Console も対象外。
   **仮に Slack が飛んでいても今回の障害は検知できなかった。**

> ⚠️ **`weekly-pv-report.yml` の Slack ステップは現在も残っているが死んでいる。**
> 削除には gh トークンの `workflow` スコープが必要で、2026-08-08 時点で付与されていないため
> 未対応。**このワークフローから Slack 通知は飛ばない。**Slack 通知は下記の launchd
> ジョブに一本化されている。修正版の YAML は作成済み。

## 現在の構成（二重の防御）

| | ジョブ | 頻度 | 役割 |
|---|---|---|---|
| **予防** | `ai.openclaw.sitemap-autosubmit` | 1日2回 07:40 / 19:40 JST | サイトマップの変化＝新記事を検知して GSC へ自動再送信 |
| **検知** | `ai.openclaw.seo-health` | 週1 月曜 08:10 JST | 万一予防が止まってもサイトマップ7日超で 🚨 |

どちらも `home-mac` の launchd で動く。GitHub Actions にしていない理由:

- `.github/workflows/` の変更に `workflow` スコープが必要で、現状それが無い
- デプロイ元が CI / OpenClaw / 手動 のどれでも等しくカバーできる
- Slack トークンと GSC SA キーが home-mac に既にあり Secret 複製が不要

### 実体

| ファイル | 説明 |
|---|---|
| `scripts/sitemap-autosubmit.py` | 予防側。sitemap の SHA256 が変われば GSC に PUT。無変化なら無音 |
| `scripts/seo-health-monitor.py` | 検知側。サイトマップ鮮度・GSC 指標・インデックス状況をレポート |
| `~/Library/LaunchAgents/ai.openclaw.sitemap-autosubmit.plist` | 予防側の launchd 定義 |
| `~/Library/LaunchAgents/ai.openclaw.seo-health.plist` | 検知側の launchd 定義 |
| `~/.config/daily-hack/gsc-bot-key.json` | GSC のサービスアカウント鍵 |
| `~/openclaw/config/.env` の `OPENCLAW_BOT_TOKEN` | Slack 投稿用 |
| `~/.config/daily-hack/*-state.json` | 前回比較用のスナップショット |

通知先 Slack チャンネル: `C0A5FKU7T5M`

## 検知項目と閾値（seo-health-monitor）

| 検知 | 閾値 |
|---|---|
| 🚨 サイトマップ最終取得 | 7日超（`STALE_DAYS`） |
| 🚨 登録URL数と実URL数の乖離 | 5%超（`URL_GAP_PCT`） |
| 🚨 表示回数の急減 | 前週比40%超減 |
| ⚠️ 未インデックス率の悪化 | 前回比10pt超 |

## 「沈黙して腐らない」ための設計

前回の失敗の本質は **「壊れても何も起きない」** ことだった。同じ轍を踏まないための担保:

| 失敗パターン | 対策 |
|---|---|
| 資格情報が無く静かに skip（**前回の原因**） | `skip` ではなく `exit 1` で落とす |
| 想定外の例外で沈黙 | `notify_failure()` で Slack に鳴らす |
| ハングして永久に鳴らない | インデックス走査に300秒の時間予算。超過時も必ず通知 |
| 毎回同じ記事だけ見て後半を見落とす | 順繰り走査（`scan_offset` を永続化） |
| 走査本数の差による誤警報 | 絶対数でなく未登録率で比較 |

## 動作確認のしかた

```bash
PY=/opt/homebrew/bin/python3.11   # gcloud/system python は 3.9 で google-auth が無い

# 予防側（送信せず差分だけ見る）
$PY scripts/sitemap-autosubmit.py --dry-run
$PY scripts/sitemap-autosubmit.py --force      # 変化が無くても強制送信

# 検知側（Slack に送らない／インデックス全走査を省略して高速）
$PY scripts/seo-health-monitor.py --dry-run --no-index

# 警報が実際に発火するかのテスト（閾値を反転させる）
sed 's/^STALE_DAYS = 7/STALE_DAYS = -1/' scripts/seo-health-monitor.py > /tmp/t.py
$PY /tmp/t.py --dry-run --no-index

# launchd 経由の実行確認
launchctl kickstart -k gui/$(id -u)/ai.openclaw.seo-health
launchctl print gui/$(id -u)/ai.openclaw.seo-health | grep -E 'state|runs|last exit'
tail -20 ~/.openclaw/workspace/logs/seo-health.log
```

> 監視を変更したら **必ず警報経路まで実走させて確認すること。**
> 「作った」だけで検証しないと、また静かに壊れた監視が増えるだけになる。

## 掲載順位は毎回 必ず報告する（2026-08-22 追加）

**アクセス数を報告するときは、掲載順位を必ず一緒に出す。** PV だけ出して順位を出さない
報告は、以後 不足とみなす。

### なぜルールにしたか

週次レポートが順位について出していたのは
**「惜しい記事（表示 5 回以上・6〜20 位）」だけ**だった。この条件は
**1〜5 位に付いている記事を構造的に除外する。**

```text
6 位 ≤ 平均順位 ≤ 20 位   ← 上位に付けた記事はここに入らない
```

結果、**いちばん順位の高い記事が一度も報告に出てこなかった。**
「順位が高い記事を知りたい」と言われて初めて欠落に気づいた、というのが実際の経緯である。
低い方だけを見る設計は、改善対象は見つかるが**勝っている場所が分からない。**

### 出す項目

| 項目 | なぜ要るか |
| --- | --- |
| **順位が高い記事 TOP10** | 勝っている場所。伸ばす対象と内部リンクの集約先を決める |
| 順位帯ごとの記事数（1〜3 / 4〜10 / 11〜20 / 21 位以下） | 全体がどちらへ動いたか。1 記事の上下に振り回されない |
| 惜しい記事（6〜20 位・表示 5 回以上） | 従来どおり。改善で最も効く帯 |
| サイト全体の平均掲載順位（表示で加重） | 単純平均は表示 1 回の記事に引っ張られる |
| 順位が高いクエリ TOP15 | サイト全体の当たり語 |
| **記事ごとの当たり語** | **記事の平均順位は語ごとの順位を混ぜた値。「どの語で勝っているか」は記事単位の数字からは分からない** |

### 実体

| ファイル | 役割 |
| --- | --- |
| `scripts/seo-rankings.py` | GSC を**順位の高い順**で出す。`--out` で Markdown を書く |
| `scripts/top-articles.py` | GSC 既定順（クリック降順）。**順位を見る用途には向かない** |
| `ops/tasks/019-dump-seo-rankings-v3.sh` | Mac で実行して `reports/seo-rankings.md` に置く |

```bash
# Mac で手元から見る
/opt/homebrew/bin/python3.11 scripts/seo-rankings.py --days 28
```

**クラウドセッションから GSC は叩けない。** SA の impersonation（`gcloud auth
print-access-token`）が Mac にしか無いため、順位を取るには上記の `ops/tasks/` 経路か
Mac 上での実行が要る。**取りに行かない限り誰も見ていない状態になる**ので、
アクセス数の話が出たら順位も同時に取りに行く。

### `ops/tasks` からリポジトリのスクリプトを呼ぶときは origin/main から取り出す

**2026-08-22、最初の版（`010-dump-seo-rankings.sh`）はここで落ちた。**

```text
スクリプトが無い: /Users/ny/projects/anta-baka-x/blog/scripts/seo-rankings.py
```

`ops-heartbeat.sh` は `git fetch origin main` するだけで、**Mac の作業ツリーには反映しない。**
そのため作業ツリーのパスを見に行くと、`main` にマージ済みのファイルでも「無い」になる。

```bash
# 誤: 作業ツリーを見る（pull されていないと落ちる）
"$PY" "$REPO/scripts/seo-rankings.py"

# 正: heartbeat 自身がタスクを取り出すのと同じやり方
git -C "$REPO" show origin/main:scripts/seo-rankings.py > "$TMP" && "$PY" "$TMP"
```

**失敗したタスクは `done/` に印が残り、二度と実行されない。** 直すときは同じ番号を
上書きするのではなく、**新しい番号でファイルを作る**（`010` → `015`）。

### 本当の原因は `gcloud` が Python 3.9 を拾っていたこと

**016 の診断で確定した（2026-08-22T13:07Z）。** PATH は原因ではなかった。

```text
ERROR: gcloud failed to load. You are running gcloud with Python 3.9,
which is no longer supported by gcloud.
```

`gcloud` 本体は `/opt/homebrew/bin/gcloud` で見つかっていた。落ちていたのは
**gcloud が自前で拾う Python がシステムの 3.9 だったから。**

```bash
export CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11   # 3.10〜3.14 なら何でもよい
```

`seo-rankings.py` は自分を動かしている interpreter（3.10 以上のとき）を
`CLOUDSDK_PYTHON` として `gcloud` に渡す。タスク側でも同じ値を export して二重にかけている。

**「PATH が最小限だから gcloud が無い」という最初の見立ては外れていた。**
診断を残す仕組みを入れていなければ、間違った修正を重ねていた。

### launchd 経由は PATH が最小限になる。`gcloud` は見つからない前提で書く

**2026-08-22、2 つめの版（`015`）はここで落ちた。**

```text
取得に失敗（/opt/homebrew/bin/python3.11）: ... raise CalledProcessError(retcode, process.args, subproc
```

`launchd` から起動されたプロセスの `PATH` は `/usr/bin:/bin:/usr/sbin:/sbin` しかない。
**Homebrew も Cloud SDK も入っていないため `gcloud` が見つからない。**
手元のターミナルでは通るので、ローカルで試しても再現しない。

- `seo-rankings.py` は `GCLOUD_BIN` → `which` → 既知のパスの順で `gcloud` を探す
- 見つからないときは「gcloud が見つからない。PATH=…」と**読める形で**落ちる
- `gcloud` が失敗したときは `stderr` をそのまま出す。`check=True` の
  `CalledProcessError` は**何が起きたかを一切伝えない**

### 失敗の中身は `heartbeat.json` では読めない

`ops-heartbeat.sh` は各タスクの出力を `tail -5 | cut -c1-300` に切り詰める。
**Python のトレースバックは 300 字では意味を成さない。**

失敗しうるタスクは、`$OPS_REPORT_DIR` に診断を書くこと。ここは切り詰められず、
`reports/` として push される。**ただし公開リポジトリに載るので、トークンは必ず伏せる。**

### 記事の平均順位を「その記事の順位」と読まない

GSC の記事単位の平均順位は、**その記事が出たすべてのクエリの順位を表示回数で加重平均した値**。
1 位で出ている語と 40 位で出ている語が混ざって 7.6 位になる。

**上位表示されている語を知りたいときは、必ず記事ごとの当たり語の表を見る。**
記事の平均順位だけでは、伸ばす語も直す語も決められない。

表示回数の少ない語は GSC が匿名化して返さないため、表示の少ない記事では語が
1 つも出ないことがある。**「語が出ない＝上位表示されていない」ではない。**

### 直近 3 日を含めない

GSC は確定まで 2〜3 日かかる。直近日を含めると順位が実際より低く出る。
`seo-rankings.py` は既定で 3 日前を終端にしている。

### コスト

GSC API・Cloudflare GraphQL・GitHub Actions・Slack Webhook は**いずれも LLM を呼ばない。**

| 単位 | 額 |
| --- | --- |
| 1 回あたり | $0 |
| 1 日あたり | $0 |
| 1 か月あたり | $0 |

## 既知の未解決

- **IndexNow が 403**（`UserForbiddedToAccessSite`）。キーファイルは 200 で配信されているのに
  弾かれる。Cloudflare が検証 Bot をブロックしている可能性。Bing / Yandex への通知が効いていない
  （Yandex のみ 202 で受理される）。Google には影響しない。
- `scripts/seo-submit.mjs` はどのワークフローからも呼ばれていない。
- Cloudflare 無料プランの Analytics は **8日分しか保持しない**ため、PV の月次比較はできない。
  長期トレンドが要るなら別途蓄積が必要。
