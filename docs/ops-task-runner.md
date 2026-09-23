# `ops/tasks` の実行モデル（守らないと詰む 4 つ）

`ops/tasks/*.sh` にコミットしたスクリプトは、Mac の `com.dailyhack.ops-heartbeat`
（launchd）が `scripts/ops-heartbeat.sh` 経由で実行する。**書く前にここを読む。**

```bash
for t in $(git ls-tree --name-only "origin/main:ops/tasks"); do
  [ -f "$WT/done/$t" ] && continue                       # ← 実行済みは飛ばす
  out="$(/bin/bash "$task_tmp/$t" 2>&1)"; rc=$?
  printf '%s rc=%s\n' "$(date -u ...)" "$rc" > "$WT/done/$t"   # ← 成否を問わず必ず書く
done
```

## 1. タスクは 1 回しか走らない。**「次の周回で」は無い**

`done/<task>.sh` は **rc に関係なく** 書かれる（`scripts/ops-heartbeat.sh:162`）。
`exit 1` でも `exit 0` でも同じ。**一度返ったら二度と走らない。**

したがってこれは成立しない。

```bash
# ❌ 動かない。次の周回は来ない
if [ -z "$PARENT_ID" ]; then
  echo "まだ条件が揃わない。次の周回で再確認する"
  exit 0
fi
```

条件を待つなら**自分の実行の中で待つ。**

```bash
# ✅ 自分の中で待つ。それでも駄目なら「別名で出し直せ」と報告に書く
for i in $(seq 1 18); do
  PARENT_ID="$(head_id)"; [ -n "$PARENT_ID" ] && break
  sleep 10
done
```

直せずに終わったら、**同じ名前では再実行されない。** 番号を変えて出し直すこと。

## 2. 実行順は**ファイル名順**。依存があるなら名前で並べる

`ls-tree --name-only` の出力順＝辞書順なので、`t004` は `t005` より先に走る。
**同じ周回の中で、前のタスクの結果を後のタスクが使える。**

逆に言うと、**先に走るタスクが失敗すると後続が巻き添えになる**設計は避ける。

## 3. **`$0` はリポジトリの中を指さない**（2026-09-06 に 2 本 潰した）

ランナーはタスクを **`/tmp/ops-tasks/` にコピーしてから実行する。**

```bash
out="$(/bin/bash "$task_tmp/$t" 2>&1)"   # ← コピーを叩いている
```

つまり `$0` は `/tmp/ops-tasks/t0NN-….sh`。

```bash
# ❌ cd / してしまう。git は fatal: not a git repository
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

# ✅ 場所は変数で受ける
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
```

**成果物は `$OPS_REPORT_DIR` に書くだけでよい。** 自分で `git add` も push も
しない。ランナーが `ops/heartbeat` へ運ぶ。

2026-09-06、`t052` と `t053` がこれで両方とも空振りした。`t053` は
`cd /` の状態で `python3 scripts/weekly-blog-report.py` を叩き、
**ファイルが無くて終了コード 2** で終わった。しかも**ランナーから見た rc は 0**
（最後のコマンドが成功したため）で、失敗が表に出なかった。
**1 回しか走らないので、直すには番号を振り直すしかない**（→ `t054` / `t055`）。

## 4. **自分を殺すタスクを書かない**（実際に踏みかけた）

タスクは heartbeat ジョブの子プロセスとして走る。だから次は**自殺**である。

```bash
# ❌ 走っている自分ごと SIGTERM される
launchctl bootout "gui/$UID/com.dailyhack.ops-heartbeat"
launchctl bootstrap "gui/$UID" "$PLIST"
```

起きることは 3 つ重なる。

| | 結果 |
| --- | --- |
| 自分 | `bootout` の行で殺される。**以降の行は走らない** |
| `done/` の印 | 162 行目まで到達しないので**書かれない** |
| 後続タスク | ループごと死ぬので**1 つも走らない** |

印が書かれない以上、**次の周回も同じことが起きる。** 永久に自殺し続け、
`ops/tasks` に何を積んでも実行されない状態になる。

**2026-08-30 に `t003-heartbeat-3min.sh` がこれに該当し、走る前に main から消した。**
（1 周回ぶん遅れて main へ入ったため、まだ 1 度も実行されていなかった）

### ハートビート自身の設定を変えたいときは

- **`bootout` を自分の中で呼ばない**
- 変えるだけ変えて、**再ロードは launchd 側の別の一発ジョブに任せる**
- 冒頭で「もう変わっているか」を見て、変わっていれば**何もせず `exit 0`**
  （印が付いて、以後の周回に巻き添えを出さない）

## 5. **JSON を `sed` で読まない**（2026-09-06 に誤った帰属を出しかけた）

`t065` はツイートの生死を確かめるのに、こう書いていた。

```bash
name=$(echo "$body" | sed -n 's/.*"screen_name":"\([^"]*\)".*/\1/p' | head -1)
```

**JSON の中で最初に出てくる `"screen_name"` を掴む。** 引用元・リプライ先・
メンションが混ざっていると、**別人の名前が出る。**

実際に `2042734632609943808` は投稿者が `@CryptoEggmen` なのに、
引用元の `@nikkei` を掴んで出した。**そのまま記事に反映していたら、
他人の発言を別の誰かの発言として公開していた。**

```bash
# 危ない: 構造を無視して最初の一致を拾う
sed -n 's/.*"screen_name":"\([^"]*\)".*/\1/p'

# 安全: 構造を辿る
python3 -c 'import sys,json; print(json.load(sys.stdin)["user"]["screen_name"])'
```

**「動いて、それらしい値が出た」は、正しさの証拠にならない。**
`t065` は ✅ を 9 個 並べて、そのうち 1 個が別人だった。

## 6. **`py_compile` が通っても、実行すると落ちる**（2026-09-14 に 1 周 無駄にした）

`t074` は Python の構文検査（`python3 -m py_compile`）を通したうえで Mac に送り、
**3 つのセクション全部が同じ例外で落ちて空のレポートになった。**

```text
UnboundLocalError: cannot access local variable 'L' where it is not associated with a value
```

関数の中で `L += [...]` と書いたのが原因。**代入なので `L` がローカル扱いになり、
モジュール側の `L` が見えなくなる。** `L.append()` は代入ではないので落ちない。
つまり**同じ関数の中で両方 書くと、片方だけが壊れる。**

```python
L = ["見出し"]

def block():
    global L          # ← **これが要る**
    L += ["行"]       # global が無いと L がローカルになり、読んだ時点で落ちる
```

**構文検査は「書き方が正しいか」しか見ない。** 名前解決・型・API の応答は実行時にしか出ない。
タスクは 1 回しか走らないので（ルール 1）、**落ちたら番号を振り直して 1 周 やり直しになる。**

### 送る前にやること

**ネットワークをスタブして、最後まで 1 回 通す。** 数分で済む。

```python
# urlopen と subprocess.run を差し替えて、本物の応答の形だけ返す
urllib.request.urlopen = fake_urlopen
subprocess.run = lambda *a, **k: types.SimpleNamespace(returncode=0, stdout="tok", stderr="")
exec(compile(src, "task.py", "exec"), {"__name__": "__main__"})
```

**通ったあとにレポートの `⚠️` の数を数える。** 0 でなければ、まだどこかが落ちている。

代入の漏れだけなら AST でも拾える（モジュール変数を `global` 無しで代入している関数を探す）が、
**スタブ実行のほうが確実で、API の応答の形が変わっているときも同時に見つかる。**

## 7. **同じ PR で足したファイルを、タスクから読まない**（2026-09-18 に空振りした）

`t088` は、同じ PR で追加した `ops/data/walk-poikatsu-apps.json` を読もうとして
こう出た。

```text
🚨 /Users/ny/projects/anta-baka-x/blog/ops/data/walk-poikatsu-apps.json が無い
```

**ランナー自身は常に最新だが、作業ツリーは別。**
`ops-heartbeat.sh` は `git show origin/main:scripts/ops-run-tasks.sh` で
ランナーを取り出すので、**ランナーのコードだけは必ず最新**になる。
だが**クローンの作業ツリーは誰も更新していなかった。**

これは `t067`（`weekly-blog-report.py` が無い）と同じ踏み方で、
**`t068` の冒頭に自分で書いた「リポジトリのファイルに依存しない」を破っている。**

### 守ること

- **タスクが要るデータは、タスクの中に焼き込む。** 一覧・URL・鍵の場所、すべて
- どうしても読むなら、**無かったときに何をするかを書く**（候補を挙げて `exit 1`）

### 仕組み側でも塞いだ（2026-09-18）

`ops-heartbeat.sh` が、**タスクを走らせる前にクローンを main へ早送りする。**

```bash
# main にいて、追跡ファイルに変更が無いときだけ
git -C "$MAIN_REPO" merge --ff-only origin/main
```

**安全側に倒してある。** 作業ブランチにいる／変更が残っているときは早送りせず、
その旨を標準エラーに出す。**未追跡ファイルには触らない**（`git clean` は打たない）。

クローンが離れていること自体は `heartbeat.json` の `clone` に毎回 出る。

```json
"clone": { "branch": "main", "behind": 0, "dirty": 0 }
```

## 8. **JS で描くページは「タグを落として読む」方式では取れない**（2026-09-19 に 2 度 踏んだ）

`t092` / `t098` は公式ページの本文から金額と一覧を拾うタスクだが、
**取れたのは共通のナビゲーション文だけ**という結果が何度も出た。

| ページ | 取れた行 | 実際 |
| --- | --- | --- |
| Spotify 学割 | **0 行** | 金額は JS で描画 |
| YouTube Premium 学割 | **0 行** | 同上 |
| 科博 大学パートナーシップ 入会校一覧 | 2 行（共通のナビ文） | **一覧そのものが JS** |

**「0 行 だった」は「その制度が無い」ではない。** ここを取り違えると、
**記事に「対象外」と書いてしまう。** 実際に科博は「放送大学が入っていない」と
書きかけて止めた。**読めなかっただけで、載っていないとは言えない。**

### 守ること

- **取れなかったページは「未確認」として扱う。** 記事にも「無い」と書かない
- 静的な HTML を出すのは**公的機関・大学・老舗のサイト**が多い。
  `ouj.ac.jp` / `tic-coop.com` / `nikkei.com` は読めた
- **一覧が JS なら、リンクを辿って別の URL を探す**（`t099` / `t100` のやり方）。
  アンカーテキストから引き、**URL は推測で組み立てない**
- それでも取れないなら、**その項目は記事に載せない。** 「取れなかった」と
  記事に書くのも禁止（`blog-article` スキル「制作の裏側を記事に書かない」）

## 9. **マージの `405 build is expected` は、CI の失敗ではない**（2026-09-23 に 3 回 詰まった）

`ops/tasks` は **`main` にマージされて初めて走る**（最上位ルール 12）ので、
マージできないことは「タスクが 1 本も届かない」ことと同じである。

**1 日で 3 回 同じところで止まった。** 毎回こう出る。

```
405 Required status check "build" is expected.
```

**文面は CI を指しているが、CI は成功している。**

| 見たもの | 出た値 |
| --- | --- |
| `check-runs` の `build` | **`completed` / `success`** |
| `commits/<sha>/status` | `pending` / statuses は **0 件** |
| **`pulls/<n>` の `mergeable_state`** | **`behind`** ← **これが真因** |

このリポジトリのブランチ保護は「**`main` に追いついていること**」を要求する。
**待っている間に `main` が進むと、CI が通っていてもマージできない。**
ロゴ取得の `t1xx` 系が並行して動いているので、**数分 待てばほぼ必ず進む。**

### 順番を間違えない

```bash
# ❌ CI を疑うところから始める（3 回 これをやった）
gh api .../check-runs

# ✅ 405 が出たら、まず状態を見る
curl -sS "https://api.github.com/repos/<owner>/<repo>/pulls/<n>" | jq -r .mergeable_state
#   behind → main に追いつかせる
#   dirty  → 衝突。解消する
#   clean  → 本当に CI 待ち
```

### 追いつかせ方（**`git checkout -B` を打たない**）

**squash マージされた後は、`git rebase origin/main` が
「もう main に入っている変更」を再適用しようとして衝突する。**
自分のコミットは squash で 1 個にまとめられており、
Git からは「未マージ」に見えるためである。実際に 4 連続で衝突した。

**先に、中身が本当に main に入っているかを見る。**

```bash
git fetch origin main
# **これが空なら、中身は全部 main に在る。** 安全に作り直せる
git diff --stat origin/main HEAD -- . ':(exclude)<今回 足したファイル>'

git reset --hard origin/main
git checkout <元のsha> -- <今回 足したファイル>   # 新しい分だけ拾い直す
```

**空でなければリセットしない**（最上位ルール 3）。`git rebase origin/main` で解く。

## 併せて読む

- 秘密を出さない・当て推量でファイルを作らない: `CLAUDE.md`「機械的な操作は `ops/tasks/` に置く」
- 実行結果の置き場: `$OPS_REPORT_DIR`（`reports/*.md`。**公開リポジトリに載る**）
