# 収益化作戦室の週次ルーティン（毎週月曜 8:47 JST・クラウドの Claude）

> 作戦室: **https://claude.ai/artifact/9KWGybrAHF7LtbQdVpw9YN**（ソース `scripts/strategy-board/board.html`）
> 利用者の指示（2026-10-12）: 「今回の断面だけではなく定期的にアップデートして、その結果を踏まえてこのサイト自体の
> コンテンツが変更されていく仕組みを」「その場しのぎのタスクとして行わず、中長期的にこのウェブサイトを用いて
> ブログの成長戦略を考えていく前提で」

## 全体の流れ（毎週）

| いつ | どこで | 何をする | 出力 |
| --- | --- | --- | --- |
| 毎日 | GitHub Actions | Cloudflare の訪問を積む | `ops/pv-archive` の `data/<YYYY-MM>.json` |
| 月曜 6:12 | Mac `com.dailyhack.asp-sync` | 4 社に自動ログインし提携状況を読む | `ops/heartbeat` の `reports/asp-sync/status.json` |
| 月曜 6:40 | Mac `com.dailyhack.board-weekly`（`scripts/strategy-board/mac-weekly.sh`） | GSC 直近 28 日／前の 28 日／90 日、A8 の提携一覧 | `ops/heartbeat` の `reports/board/` |
| 月曜 8:47 | クラウドのルーティン（このファイルの手順） | スナップショット → サイトの db → コメント返信 → 本文の書き換え → 更新履歴 | サイトと PR |

**費用**: Mac 側は LLM 不使用で **$0／回・$0／日・$0／月**。クラウドのルーティンは
サブスクリプション枠のセッションで、**Console 課金は $0**（API キーを使わない）。

## ルーティンの手順（この順で、全部やる）

1. **最新にする**: `git fetch origin main && git checkout -B <作業ブランチ> origin/main`
   （作業ブランチに未マージのコミットが無いことを先に `git log origin/main..HEAD` で確かめる）
2. **スナップショットを作る**: `node scripts/strategy-board/build-snapshot.mjs --out /tmp/snap.json`
   - 末尾の行に `gsc=… pv=… a8=… findings=…` が出る。**`gsc=false` や `a8=0` なら、その事実を更新履歴に書く**（隠さない）
3. **サイトの db に書く**（`ArtifactData` の `batch`・1 回の承認）:
   - `snapshot/latest`（`set`。既存なので **先に `get` して `if_version`**）
   - `snapshots/<YYYY-MM-DD>`（`set`・新規）
4. **コメントを読む**: `ArtifactData list collection=feedback`。`reply` が空のものが未対応
   - `scope`: `site`（全体）／`block`（記載ごと。`cid` と `quote` で場所が分かる）
   - **指摘どおりに直せるものは直し**、何をしたかを `reply` に書く（`update` ＋ `if_version`）
   - 方針を変えるもの・アカウント操作（提携申請・登録）は直さず、`reply` で選択肢を示し、
     `board.html` の `DECISIONS` に項目を足す（最上位ルール 18・20：勝手に決めない）
5. **決定を読む**: `ArtifactData list collection=decisions`。`checked: true` で、まだ実行していないものを実行する
   （アカウント操作は `ops/tasks` で。チェックが付いたものだけ）
6. **本文を書き換える**（`scripts/strategy-board/board.html`）: 所見が計画とずれていれば戦略・12 週の予定を直す
   - 例：検索表示が 15% 以上落ちた → 予定の先頭に原因調べを入れる／ある型だけ伸びた → 後半をその型に寄せる
   - **データから言えることだけ書く**（最上位ルール 11）。数字は snapshot に任せ、本文に直書きしない
   - 記載の `data-cid` はページ側で本文の指紋から振っている。**文面を変えると、その記載に付いたコメントの位置札が外れる**。
     コメントの付いた記載を書き換えるときは、`reply` に「この記載は書き換えた」と残す
7. **更新履歴を書く**: `changelog/<YYYY-MM-DD>-weekly`（`kind`・`date`・`summary`・`items[]`）。
   数字の入れ替えだけの週も 1 行は残す（何も変わらなかったことも記録）
8. **publish し直す**（本文を変えたときだけ）: `board.html` を scratchpad の `strategy-board.html` に写し、
   `Artifact publish url=https://claude.ai/artifact/9KWGybrAHF7LtbQdVpw9YN`（初回 read が要る）
9. **commit → PR → CI → マージ**（`board.html`・`manual.json` などを変えたとき）。`npm run handoff` も
10. **利用者への報告は作戦室の URL と、変わった点 3 行まで**。詳細はサイトの更新履歴に

## db のコレクション

| コレクション | 中身 | 書く人 |
| --- | --- | --- |
| `snapshot/latest` | 最新の数字・表・所見（build-snapshot の出力そのまま） | ルーティン |
| `snapshots/<日付>` | 週ごとの履歴（推移の比較用） | ルーティン |
| `feedback/<自動 id>` | `scope`(site/block)・`page`・`cid`・`quote`・`body`・`createdAt`・`reply` | 利用者（`reply` は Claude） |
| `decisions/<id>` | `checked`・`title`・`updatedAt` | 利用者 |
| `changelog/<id>` | `date`・`kind`・`summary`・`items[]` | Claude |

## データから取れない事実

`ops/data/board/manual.json`（審査中の申請・ASP のメモ）。**審査が通った・登録したなど事実が変わったら更新する。**
公開リポジトリなので、自分の報酬額・会社名・氏名・口座・契約 ID は書かない。

## 所見の条件を足すとき

`build-snapshot.mjs` の所見は条件で出す（LLM 不使用）。足したら、作戦室の「計測と振り返り」の表も直す。
