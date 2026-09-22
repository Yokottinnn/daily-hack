# 公開済みの記事を定期的に更新する仕組み

**記事は書いた日から古くなっていく。** 価格は改定され、キャンペーンは終わり、
新しい制度が始まる。**直さないまま置いておくと、検索でもAIでも信用を落とす。**

ここは 3 層に分かれている。**費用がかかるのは C だけ。**

| 層 | 何をするか | 費用 |
| --- | --- | --- |
| **A. AIO** | 構造化データと `llms.txt`。AI に引用されるための形を整える | **$0** |
| **B. 素材** | X の実投稿・YouTube・公式ページの差分を取ってくる | **$0** |
| **C. リサーチ** | 古くなった数字を調べ、**更新案の PR を作る** | **約 $2.1/月** |

---

## A. AIO（AI Optimization）

**生成AIは「答えの形になっているもの」を引用する。** 記事に書いてあっても、
機械が読める形になっていないと拾われない。

| 出しているもの | どこから作るか | ファイル |
| --- | --- | --- |
| `Article` | フロントマター | `src/layouts/PostLayout.astro` |
| **`FAQPage`** | **本文の `faq-table`**（Q と A の表） | `src/lib/aio.ts` |
| **`HowTo`** | **① ② ③ が並ぶ手順の表** | 同上 |
| `articleSection` | 本文の h2 | 同上 |
| `BreadcrumbList` | パンくず | `src/components/Breadcrumb.astro` |
| **`/llms.txt`** | 全記事のタイトル・要約・**最終更新日** | `src/pages/llms.txt.ts` |

### 守っていること

- **取れなければ出さない。** 空の `FAQPage` は、かえって評価を落とす。
  FAQ が 3 件 未満なら出力しない
- **本文に書いてあるものだけを拾う。** 要約も言い換えもしない
- **`dateModified` は `updatedDate`。** 記事を直したらここが動く。
  C が本文を直したときは**自動で今日の日付に書き換わる**

### FAQ を表に直す

`FAQPage` の元になるのは `faq-table` クラスの表。**「`**Q. …**` ／ `A. …`」の形で
書かれた FAQ は、機械的に表へ直せる。**

```bash
python3 scripts/faq-to-table.py <slug> [<slug> ...]
```

**中身は足さない。** Q と A をそのまま 2 列に移すだけ。
スマホでは質問と答えが縦に積まれる（`faq-table` の CSS）。

---

## B. 素材の収集

`ops/tasks` で Mac に取らせる。**クラウドからは外部 HTTPS が塞がれている。**

| 取るもの | どこから | 実績 |
| --- | --- | --- |
| X の実投稿 | `cdn.syndication.twimg.com/tweet-result` | t106 |
| YouTube の題名照合 | `youtube.com/oembed` | blog-article スキル §2 |
| 写真 | Wikimedia Commons の検索 API | t137 |
| ロゴ | 公式のメディアキット → コモンズ → 公式サイト | t115 / t122 / t126 |

**取ってきたものは、必ず目で見てから入れる**（blog-article スキル）。

---

## C. リサーチと更新案（**ここだけ課金**）

### 動くもの

```text
launchd（毎日 05:30）
  → ~/.openclaw/bin/refresh-daily-boot.sh     ← **ディスクに置くのはこれだけ**
      → git show origin/main:scripts/refresh-daily.sh   ← **毎回 最新を取り出す**
          → scripts/refresh-article.mjs --apply
          → npm run build（落ちたら PR を作らない）
          → gh pr create（**マージは人**）
```

**Mac の作業ツリーは `origin/main` に追従していない。**
マージしてもディスク上にファイルは現れないので、plist から
作業ツリーのパスを直に呼ぶと動かない（t138 がそれで失敗した）。
`ops-run-tasks.sh` の自己更新と同じく、**`git show` で取り出して走らせる。**

**作業ツリーが汚れていたら、ジョブは何もせずに終わる。**
この先の `reset --hard` で人の書きかけを消さないため。

### 選び方

**3 段で決める**（2026-09-22 に 2 段目を足した）。

| 段 | 何を先に回すか | 根拠 |
| --- | --- | --- |
| 1 | **未インデックス**でまだ見ていないもの | `ops/data/unindexed.txt` |
| 2 | **期限切れの語を含む記事**。最終更新が古い順 | `ops/data/stale-words.txt` |
| 3 | いちばん放置されている記事 | `refresh-state.json` の `done[slug]` |

**放置日数だけで選ぶのをやめた理由。** 実際に古くて差し戻されたのは
**期限のあるもの**だった。東京湾大華火祭の節が「チケット発売は 7月予定」
「料金は 5,000〜10,000円の予定」のまま 3 か月 残っていて、
**実際には抽選が 3 回とも終わっていた**（2026-09-21）。
**放置日数順だと、これが 75 日 後まで回ってこない。**

語は `check-stale-wording.py` と**同じファイルを読む。** 2 箇所に書かない。

```bash
python3 scripts/check-stale-wording.py    # いま何が引っかかるかを見る
```

**75 本 あるので、期限切れが無くなれば約 75 日 で一周する。**

### 数字を創らせないための関門

**LLM の出力をそのまま信じない。** 3 段で落とす。

| 段 | 落とすもの |
| --- | --- |
| 1 | **出典 URL が無い指摘**（`https://` で始まらない） |
| 2 | **引用が本文に無い指摘**（`quote` が記事に一字一句 存在しない） |
| 3 | **確度が「高」でないもの**は本文に当てない。レポートに載せて人が選ぶ |

さらに **`npm run build` が落ちたら PR を作らない。**

### 費用

| 単位 | 金額 |
| --- | --- |
| 1 回あたり | **約 $0.07**（推定） |
| 1 日あたり | **約 $0.07** |
| 1 か月あたり | **約 $2.1** |

**推定の前提**: `claude-sonnet-5`（$2 / $10 per MTok）、入力 2 万トークン・出力 3 千トークン。
**実額は `ops/data/refresh-state.json` の `total_usd` に積まれる。**

```bash
jq '.total_usd, .last' ops/data/refresh-state.json
```

**web 検索ツールは従量課金が別にかかり、単価を確認できていない。**
既定では無効。`USE_WEB_SEARCH=1` を付けたときだけ有効になる。
**有効にする前に単価を確定させること。**

### 手で動かす

```bash
node scripts/refresh-article.mjs --dry-run            # 選定だけ見る。**API を呼ばない**
node scripts/refresh-article.mjs --slug <slug>        # 指定した記事を調べる（当てない）
node scripts/refresh-article.mjs --slug <slug> --apply # 確度「高」だけ当てる
```

### 量を増やすときは

**1 日 2 本にすれば単純に倍**（約 $4.2/月）。`REFRESH_MODEL=claude-opus-5` なら
**約 $10.5/月**。どちらも増額なので、**金額を出してから**変える
（CLAUDE.md 最上位ルール 2-B）。
