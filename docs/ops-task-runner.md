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

## 併せて読む

- 秘密を出さない・当て推量でファイルを作らない: `CLAUDE.md`「機械的な操作は `ops/tasks/` に置く」
- 実行結果の置き場: `$OPS_REPORT_DIR`（`reports/*.md`。**公開リポジトリに載る**）
