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

## 週次レポート（2026-09-06 に作り直した）

**壊れていた。** 2026-08-31 に Slack へ出たレポートには
`${ALL_VISITS}` が展開されないまま載っていて、**Cloudflare の PV が数字に
なっていなかった。** それでもエラーは出ず、レポートは毎週きれいに届き続けていた。

`scripts/weekly-blog-report.py` が後継。**節ごとに独立して失敗し、
取れなかった節には理由を書く。** 取れなかったものがあれば終了コード 1 で落ちる。

| 節 | 出どころ |
| --- | --- |
| サマリー（PV・訪問・検索クリック・平均順位、いずれも前回比） | CF RUM ＋ GSC |
| 流入経路（検索／SNS／直接／その他＋リファラ TOP10） | CF RUM |
| 人気ページ TOP15 | CF RUM |
| 検索順位 TOP10（順位の高い順） | GSC |
| 順位帯ごとの記事数 | GSC |
| 惜しい記事（6〜20 位） | GSC |
| 順位が動いた記事（前回比） | GSC ＋ 状態ファイル |
| 当たり語 TOP20 | GSC |
| デバイス・国 | CF RUM |

### 旧レポートが壊れていた理由（2026-09-06 に t054 で実体を読んで確定）

旧 `~/scripts/weekly-blog-report.py` は、**Cloudflare の数字を GitHub Actions 経由で
取っていた。** CF のトークンが GHA の Secret にしか無かったため。

```python
subprocess.run(["gh", "workflow", "run", "weekly-pv-report.yml", ...])
time.sleep(22)
rid = ... gh run list --limit 1 ...      # 22 秒で新しい run が出ている保証は無い
log = ... gh run view $rid --log ...     # ここから STDOUT_TOTALS を文字列で拾う
```

**この橋が壊れて `${ALL_VISITS}` という文字列をそのまま拾っていた。**
新しいレポートは Cloudflare の API を直接叩くので橋が要らない。
**代わりに Mac 側へ API トークンを 1 つ置く必要がある**
（`~/.config/daily-hack/cf-token`。権限は Account Analytics: Read）。

**流入経路が取れるのは Cloudflare Web Analytics のビーコンが入っているから**
（`BaseLayout.astro:106`）。`rumPageloadEventsAdaptiveGroups` を siteTag で引く。
サイトタグはビーコンの token と同じ値で、ページを開けば読める公開値。

前回比のための状態は `~/.config/daily-hack/weekly-report-state.json`。

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

## インデックス状況の実測（2026-09-12・t071）

**「sitemap に載っている」と「インデックスされている」は別。** 前者はビルド後の HTML で
確認できるが、後者は GSC の URL 検査 API でしか分からない。当て推量で答えない。

```bash
# ops/tasks/t071-index-status.sh がやっていること
POST https://searchconsole.googleapis.com/v1/urlInspection/index:inspect
     {"inspectionUrl": "<記事URL>", "siteUrl": "https://daily-hack.fieldbeside.com/"}
# scope: https://www.googleapis.com/auth/webmasters.readonly
```

### 結果（5 URL すべて PASS）

| ページ | verdict | 登録状態 | 最終クロール |
| --- | --- | --- | --- |
| 都心の格安スーパー 2026 | PASS | Submitted and indexed | 2026-09-08 22:47Z |
| IKEA豊洲 完全ガイド | PASS | Submitted and indexed | 2026-09-07 04:43Z |
| ららぽーとガイド | PASS | Submitted and indexed | 2026-09-07 14:50Z |
| 湾岸スーパー徹底比較 | PASS | Submitted and indexed | 2026-09-07 15:07Z |
| トップ | PASS | Submitted and indexed | 2026-09-07 20:33Z |

`robotsTxtState: ALLOWED` / `indexingState: INDEXING_ALLOWED` /
`pageFetchState: SUCCESSFUL` / `googleCanonical == userCanonical`。
**重複扱いにされているものは 1 つも無い。**

### ここで分かった落とし穴

- **`crawledAs: MOBILE`。** 判定はモバイル版で行われる。PC だけ見て崩れに気づかないのは危ない
- **`referringUrls` が 1 本しか返らない。** 実際には内部リンクが 67 ページあるのに、
  GSC が出すのは代表 1 本だけ。**これを被リンク数と読み違えない**
- **最終クロールは編集より前のことがある。** 上の記事は 09-08 22:47Z のクロールだが、
  09-12 にも本文を直している。**いま index にあるのは 09-08 時点の版**

### 「インデックスされているか」を調べる順番

1. ビルド後の HTML: `canonical` / `meta robots` / 構造化データ / OGP
2. `dist/sitemap-0.xml` に `<loc>` があるか、`dist/robots.txt` が拒否していないか
3. `grep -rl "/posts/<slug>/" dist --include='*.html' | wc -l` で孤立していないか
4. **ここまで全部 正しくても、実際の登録は 1〜3 では分からない。** t071 と同じ API を叩く

## インデックス未登録への対処（2026-09-14・t075〜t079）

### 発端

大磯プリンス記事の PV と検索流入を調べたら、**90 日の PV が 0・全期間のクリックが 1**。
原因は順位ではなく、**そもそもインデックスに入っていないこと**だった。

```text
verdict: NEUTRAL
coverageState: クロール済み - インデックス未登録
lastCrawlTime: 2026-06-22   ← 約 3 か月 前で止まっている
referringUrls: /author/ の 1 本だけ
```

**全 74 本を URL 検査 API で調べた**ところ（t076 で 34 本ぶん）、
**28 本が登録済み、6 本が未登録**。1 本だけの問題ではなかった。

### 「クロール済み - インデックス未登録」と「検出 - インデックス未登録」は違う

| 状態 | 意味 | 効く手 |
| --- | --- | --- |
| **クロール済み - インデックス未登録** | 見には来たが、載せる価値が無いと判断された | 中身を厚くする・内部リンクを増やす・更新する |
| **検出 - インデックス未登録** | まだ見にも来ていない | サイトマップと内部リンク |
| 送信して登録されました | 正常 | — |

### URL 検査 API では「インデックス登録をリクエスト」できない

**これは調べる API であって、送る API ではない。** 送る手段は 2 つしかない。

| 手段 | 使えるか |
| --- | --- |
| Search Console 画面の「インデックス登録をリクエスト」 | **使える。1 プロパティあたり 1 日 10〜12 本が目安**（非公開・押すとグレーアウト） |
| Indexing API | **使わない。** 公式に対象が JobPosting と BroadcastEvent に限られている |

#### 手順（画面から）

1. [Search Console](https://search.google.com/search-console) を開き、プロパティ
   `https://daily-hack.fieldbeside.com/` を選ぶ
2. 上部の検索窓に**記事の URL をそのまま貼って Enter**（URL 検査）
3. 「URL が Google に登録されていません」と出たら **「インデックス登録をリクエスト」**
4. 「リクエストは登録待ちです」が出れば受理。**押し直しても早くならない**
5. **1 日 10〜12 本が上限。** 未登録の記事が多いときは、流入の見込みが高い順に押す

**押した日と URL を記録する。** 押しただけでは入らないので、
数日後に t076 系のタスクでもう一度 `coverageState` を見る。

### 全 74 本の実測（2026-09-15 01:27 時点・t076 / t078 / t079）

| 状態 | 本数 |
| --- | --- |
| 送信して登録されました | **64** |
| **クロール済み - インデックス未登録** | **9** |
| URL が Google に認識されていません | 1（`walk-poikatsu-2026`。前日公開なので想定内） |
| 別ページの重複扱い | 0 |

**未登録の 9 本には はっきりした偏りがある。**

| 記事 | 最終クロール |
| --- | --- |
| `/posts/oiso-prince-spgr-guide-2026/` | 2026-06-22 |
| `/posts/credit-card-no-annual-fee-comparison-2026/` | 2026-06-27 |
| `/posts/mens-hairremoval-comparison-2026/` | 2026-06-29 |
| `/posts/pointsite-comparison-2026/` | 2026-07-03 |
| `/posts/ana-pocket-vs-jal-wellness-2026/` | 2026-07-07 |
| `/posts/cardloan-comparison-2026/` | 2026-07-07 |
| `/posts/furusato-tax-food-picks-2026/` | 2026-08-02 |
| `/posts/car-insurance-comparison-2026/` | 2026-08-18 |
| `/posts/point-service-complete-guide-2026/` | 2026-08-18 |

**9 本中 8 本が「比較」記事**で、しかもクレカ・カードローン・自動車保険・医療脱毛・
ポイントサイト・ふるさと納税——**大手が金をかけている領域**に集中している。
「クロール済み - インデックス未登録」は**見たうえで載せないと判断された**状態なので、
これは「同じことを書いている先行ページが山ほどある」という評価だと読むのが素直。

**逆に、そこを外した記事は全部 入っている。** ららぽーとの売上ランキング、
湾岸のタワマン地図、湾岸スーパー18店舗——**このブログにしか無い数字を持つ記事**は
登録されていて、実際に流入もそこに集中している（t068）。

題材選びの基準は `blog-article` スキル §2-B にある。**「数字の賞味期限」に加えて、
「その数字を他が持っていないか」も見る。**

### サイトマップに `lastmod` が無かった（2026-09-14 に修正）

**`lastmod` の無いサイトマップは「何も変わっていない」と言っているのと同じ。**
`@astrojs/sitemap` は既定では出さないため、74 本すべてに日付が付いていなかった。

`astro.config.mjs` の `sitemap({ serialize })` で、各記事の
**`updatedDate` があればそれを、無ければ `publishDate`** を入れるようにした。

```bash
# 確認: 記事 URL の数と lastmod の数が一致すること（一覧ページには付かない）
python3 -c "
import re
x=open('dist/sitemap-0.xml').read()
m=re.findall(r'<url><loc>([^<]*)</loc>(?:<lastmod>([^<]*)</lastmod>)?</url>',x)
p=[(u,l) for u,l in m if '/posts/' in u and not re.search(r'/posts/\d*/$',u)]
print(len(p),'本中',sum(1 for _,l in p if l),'本に lastmod')"
```

**記事を直したら `updatedDate` を更新する。** そこが再クロールの合図になる。

## なぜ 4 か月 気づけなかったか（2026-09-14 の反省）

利用者の問い:「なぜそんな初歩的なミスが発生するの？」

調べたら**同じ形の失敗が 4 つ**あった。技術的な難しさはどこにも無い。

| # | 何が起きていたか | 証拠 |
| --- | --- | --- |
| 1 | **品質チェッカーが CI に入っていない** | `grep -rn "check-article-ux" .github/ .husky/` が 0 件。CI は `npm run build` と `astro check` だけ |
| 2 | **`lastmod` が無く、再送信の変化検知が空振り** | `sitemap-autosubmit.py` は sitemap-0.xml を SHA256 で比べる。URL を足し引きしない限りファイルは変わらない |
| 3 | **警報が「前回比 +10pt 悪化」でしか鳴らない** | `seo-health-monitor.py` は未登録率を測っていたが、12% で安定していたので一度も条件を満たさない |
| 4 | **週次レポートは表示 5 回以上の記事しか並べない** | 未登録記事は表示 ≒ 0 なので、**構造上その一覧に出てこない** |

### 共通しているもの

- **変化を見て、水準を見ていない**（2・3）。「悪くなったか」は測るが「今 悪いか」は測らない
- **新しいものにしか当たらない**（1）。ルールを作った時点で、過去に遡る発想が無かった。
  `check-article-ux.py` は 2026-08-09、`blog-article` スキルは 2026-08-23 に出来たが、
  それ以前の記事へ当てたのは**2026-09-14 が初めて**。当てたら 74 本中 63 本に指摘が出た
- **出力を読み返していない**（4）。`weekly-blog-report.py` の `${ALL_VISITS}` 未展開は
  2026-08-31 に見つけて 9/6 に書き直したのに、**2026-09-14 のレポートにまだ出ている。**
  Mac が古いほうを走らせている。「直した」で終わり、次の実物を見ていなかった

3 番目は `CLAUDE.md` 最上位ルール 13（`rc=0` は証拠にならない）そのもの。
**自分で書いたルールを、自分の監視に適用していなかった。**

### 入れた歯止め

- `check-article-ux.py` に `--baseline` を足し、**CI（`test-build.yml`）で走らせる。**
  積み残し 63 記事 / 186 件は `docs/article-ux-baseline.json` に記録し、
  **新しく増えた指摘だけ**で落とす。新記事は指摘ゼロ、既存記事は悪化させられない
- サイトマップに `lastmod` を出す（→ 変化検知が効くようになる）

### 追跡の結果、4 番の真因はもっと手前にあった（t080〜t086）

**Mac のクローンは 2026-08-30 に作業ブランチ `ops/t006-sauna-thread-v3` へ切り替えたまま、
2 週間 放置されていた。** 「186 コミット遅れ」はその結果であって原因ではない。

```text
ブランチ  ops/t006-sauna-thread-v3   ← main ではない
HEAD      ade78a1 2026-08-30 22:54:06
```

**リポジトリのファイルに依存する ops タスクは、2 週間ぶん全部この影響を受けていた。**
t067（`weekly-blog-report.py` が無い）も t082（コピー元が無い）もこれが原因。

そして週次レポートの plist は、**リポジトリの外のコピー**を叩いていた。

```text
["/opt/homebrew/bin/python3.11", "/Users/ny/scripts/weekly-blog-report.py"]
                                  ^^^^^^^^^^^^^^^^ リポジトリではない
```

**リポジトリ側をいくら直しても、出てくるレポートは変わらない構造だった。**

#### 直したこと

| | |
| --- | --- |
| t083 | クローンを `main` に戻した（origin と同 SHA を確認してから。未追跡ファイルは残した） |
| t084 | plist が叩く先を、リポジトリ版（811 行）に入れ替えた |
| t085 | 新しい版が Mac で動くことを確認（終了コード 0・95 行・**未展開の `${` なし**） |
| t086 | plist に `--slack` を足した（`bootout` → `bootstrap` → `launchctl list` で確認） |

#### まだ分かっていないこと

**`${ALL_VISITS}` の出どころは特定できていない。** 入れ替える前の 152 行版は
この文字列を 1 度も含んでおらず、GitHub Actions の `weekly-pv-report.yml` の
Slack 投稿部分にも無かった。Mac 全体の grep でも、新しい版と過去レポート以外は出ない。

**次の月曜 08:00 のレポートで確かめる。** 届くこと、そして未展開の変数が無いこと。

#### 途中で私が作った回帰（記録しておく）

811 行版は **`--slack` が無いと Slack へ投稿しない。** plist は引数なしで叩いていたので、
**入れ替えただけで終えていたら、次の月曜からレポートが静かに止まっていた。**
「直した」と言った直後に別の沈黙を作りかけている。**入れ替えたら、次の実物を見る。**

### 3 と 4 に入れた歯止め（2026-09-18）

| # | 直したこと | どこ |
| --- | --- | --- |
| 3 | **未インデックス率を「水準」でも鳴らす** | `scripts/seo-health-monitor.py` |
| — | **クローンが main から離れたら heartbeat に出る** | `scripts/ops-heartbeat.sh` |
| 4 | **週次レポートを定時を待たずに走らせて確かめる** | `ops/tasks/t087-kickstart-weekly.sh` |

#### 警報を「差分」から「水準」に変えた

前は**前回比 +10 ポイント悪化**でしか鳴らなかった。未登録率は 12% で安定していたので、
**9 本が未登録のまま一度も鳴らない。** 水準そのものでも鳴らすようにした。

```python
if scanned >= 10 and rate >= INDEX_BAD_RATE_ALERT:   # 既定 5%
    warns.append(f"未インデックス率が {rate*100:.0f}%（{bad}/{scanned} 本）…")
```

**未登録の URL を名指しで出す。** 率だけでは次の手が打てない。
閾値は環境変数 `INDEX_BAD_RATE_ALERT` で変えられる。

検証: 9/74 本（12%・前回も 12%）→ **鳴る**／2/74 本（2.7%）→ 鳴らない／
走査 5 本 → 鳴らない（サンプルが少なすぎる）。

#### クローンの遅れを常時 heartbeat に載せた

2 週間 気づかなかったのは、**誰も見ていなかったから**。30 分ごとの heartbeat に出す。

```json
"clone": { "branch": "main", "behind": 0, "dirty": 0 }
```

`branch` が `main` でない、`behind` が 0 でない、`dirty` が 0 でない——
**どれか 1 つでも当てはまったら、リポジトリのファイルに依存する ops タスクは信用できない。**

**残っているもの**は、3（水準で鳴らす警報）と 4（レポートの入れ替えと未登録節の追加）。
