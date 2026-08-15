# OpenClaw（home-mac）の復旧手順

> **この手順は home-mac（192.168.2.102）で実行する。** クラウドの Claude Code セッションからは
> 到達できないため、実行は利用者の手元で行う必要がある。

## 撤回された前提（先に読むこと）

**当初「MUST rule が 7 件消えたことが原因」と記録していたが、これは誤りだった。**
2026-08-11 に実機で確認したところ、ルールは消えていない。

| 当初の記録 | 実際 |
| --- | --- |
| MUST rule 7 件が消失した | **消えていない。**正しい場所に実在する |
| 8/10 09:00:09 に消失した | **消失ではなく検知**の時刻。`daily-must-rule-review` が定時に走った記録 |
| 復元元は `SHARED/MEMORY-MUST-MIRROR.md` | ミラーは slug の一覧にすぎない。実体は別 |

**ルールの実体はここにある。**

```text
~/.claude/projects/-Users-ny--openclaw-workspace/memory/
```

`~/.openclaw/workspace/memory/` でも `~/.openclaw/workspace/CLAUDE.md` でもない。
`daily-must-rule-review.js` の `MEMORY_DIR` がこの場所を指しており、実装が答えを持っていた。

同じ取り違えは過去にも起きている。`daily-must-rule-review.js` の 74 行目にこう残っている。

```js
// 本ワークスペースの memory に 1 つも存在しなかったのに 11/11 present と報告し続けていた。
```

**場所を間違えると、無いのに「有る」とも、有るのに「無い」とも報告しうる。**
残存を判定するコードを書くときは、必ず `daily-must-rule-review.js` の `MEMORY_DIR` に合わせる。

## 何が起きたか

2026-08-10 から OpenClaw の自動化が動いていない。確認された事実は次のとおり。

| # | 症状 | 確認された事実 |
| --- | --- | --- |
| 1 | **ジョブ群が未ロード** | `~/Library/LaunchAgents/` に `ai.openclaw.*` の plist が約90個あるのに、`launchctl list` に載るのは `tab-guard` だけ（last exit 1）。`print-disabled` は `0` で、無効化ではなく**アンロード**状態 |
| 2 | **ログが一斉に途絶** | ほぼ全ジョブのログが 8/10 09:44〜09:52 JST で止まっている |
| 3 | **握り潰された例外** | 停止の直前、`poll-approvals` が `blog-promo-20260810-lalaport-guide-2026` の処理で 4 回連続して失敗。**エラーメッセージが空**（`${e.message}` が空文字） |
| 4 | **虚偽報告** | 「画像をアップロード完了」と報告したが、コミット `f5771c7` はリモートに存在せず、Slack スレッドにも添付が無かった |

**「完全に死んでいる」わけではない。** Slack の受け口 `com.dailyhack.openclaw.listener` は
稼働している。受け口だけ生きていて、自動化の本体（`gateway` / `node` / `poll-approvals` /
`pipeline-heartbeat` など）が登録されていない状態。

**listener が生きているため、ログだけを見ると復活したように見えることがある。**
listener が同じスクリプトを呼ぶと `poll-approvals.log` に新しい行が増えるが、
それはジョブがロードされた証拠にならない。判定は必ず `launchctl list` で行う。

### 停止の引き金

3 が現時点で最も有力な引き金である。**今回の案件そのもの**（ららぽーとガイド 2026 の
告知投稿）を処理しようとして落ちており、時刻も 2 の途絶と一致する。

```text
[2026-08-10T00:49:45.541Z] Error processing blog-promo-20260810-lalaport-guide-2026:
[2026-08-10T00:50:45.800Z] Error processing blog-promo-20260810-lalaport-guide-2026:
[2026-08-10T00:51:46.060Z] Error processing blog-promo-20260810-lalaport-guide-2026:
[2026-08-10T00:52:46.311Z] Error processing blog-promo-20260810-lalaport-guide-2026:
```

`poll-approvals.js:232` は `${e.message}` を出しているので、**メッセージが空の例外**が
投げられている。`Error` 以外の値が throw されたか、メッセージ無しで生成されたかのどちらか。
ここを直さないと、同じエントリを処理するたびに同じ場所で落ちる。

## まずこれを実行する

止まっているジョブのうち、画像添付と 👍 検知が通る最小限だけを戻す。

```bash
cd /Users/ny/projects/anta-baka-x/blog && git pull && bash scripts/openclaw-load-minimal.sh
```

対象は `gateway` / `node` / `poll-approvals` / `slack-watchdog` / `import-manual-image` の 5 つ。
**X への自動投稿・フォロー操作のジョブは含めない。** 1 日以上滞留した処理が一斉に走ると、
意図しない投稿が発生するため。課金が無いことは `scripts/openclaw-audit-jobs.sh` で確認済み。

ロード後は**必ず外から確認する**。スクリプトの成功報告ではなく `launchctl list` で見る。

```bash
launchctl list | grep -iE 'openclaw|dailyhack'
```

環境が壊れている疑いがあるときは、次で全体を点検する。

```bash
bash scripts/openclaw-recover.sh
```

**リポジトリのディレクトリ名は `daily-hack` ではなく `blog`。** `daily-hack` で探しても
見つからない（2026-08-11 に実機で確認）。場所を見失ったら `~/.claude/projects/` の
ディレクトリ名から引ける。

```bash
ls ~/.claude/projects/ | tr '-' '/'
```

途中で MUST rule の復元だけ `[y/N]` の確認が入る。**上書き前に必ずバックアップを取る**ため、
復元に失敗しても元に戻せる。未解決の項目があれば一覧を出して `exit 1` で止まる。

以下は、そのスクリプトが何をしているかの説明。手動でやる場合もこの順で行う。

## 手順

### 1. まず現状を確認する

**ジョブ名は決め打ちにしない。** 実機には 2 系統が同居している（2026-08-11 に確認）。

| 系統 | 例 | 状態 |
| --- | --- | --- |
| `com.dailyhack.*` | `openclaw.listener` / `openclaw.heartbeat` / `rc-keeper` / `weekly-blog-report` | launchd に登録済み。listener は稼働中 |
| `ai.openclaw.*` | `gateway` / `node` / `seo-health` / `sitemap-autosubmit` ほか約 90 個 | **plist はあるが `launchctl list` にほぼ載っていない** |

`ai.openclaw.*` を名前で決め打ちすると、未ロードのジョブに対して
「エラーも出ないが実は何も起きていない」空振りになる。実在するものを列挙してから触る。

```bash
# まず実在するジョブを列挙する
launchctl list | grep -iE 'openclaw|dailyhack'

# それぞれの状態を見る
for job in $(launchctl list | grep -iE 'openclaw|dailyhack' | awk '{print $3}'); do
  echo "--- $job"
  launchctl print "gui/$(id -u)/$job" | grep -E 'state|runs|last exit'
done

# 直近のログ
tail -50 ~/.openclaw/workspace/logs/*.log
```

`last exit code` が 0 以外、または `state = not running` なら 3 の再起動まで進む。

### 2. MUST rule の残存を確認する

**正しい場所を見ること。** 場所を間違えると判定が両方向に狂う。

```bash
ls ~/.claude/projects/-Users-ny--openclaw-workspace/memory/ | grep '^feedback_'
```

ミラーに載っている絶対遵守ルールは 12 件。`scripts/openclaw-load-minimal.sh` が
この 12 件を数え、要の `feedback_verify_external_state_before_claiming` が欠けている場合のみ
ロードを止める。

一覧の正本はここにある（slug の一覧であって実体ではない）。

```bash
cat /Users/ny/projects/anta-baka-x/SHARED/MEMORY-MUST-MIRROR.md
```

### 3. スナップショットについて

`~/.openclaw/workspace/memory/snapshots/` は**存在しない**。当初「前日ぶんしか無かった」と
記録していたが、そもそもこの階層にスナップショット機構は無い。
`{"ok":false,"reason":"no yesterday snapshot to restore from"}` は、
存在しない場所を見に行った結果である可能性が高い。

### 4. `spawnSync ETIMEDOUT` を解消する

シェル呼び出しがタイムアウトしている。上から順に潰す。

```bash
# ゾンビ/多重起動が無いか
ps aux | grep -i openclaw | grep -v grep

# 実在するジョブを再起動する（名前は固定しない）
for job in $(launchctl list | grep -iE 'openclaw|dailyhack' | awk '{print $3}'); do
  launchctl kickstart -k "gui/$(id -u)/$job"
done
```

再発するなら spawn のタイムアウト値と、呼び出し先スクリプトが標準入力待ちで
止まっていないかを見る。

### 5. 生き返ったことを外部から確認する

**OpenClaw 自身の「復旧しました」という報告を信用しない。** それが今回の問題だった。

```bash
# ハートビートが今の時刻に更新されているか
tail -5 ~/.openclaw/workspace/logs/heartbeat.log

# Slack に実際に届くか（fieldbeside の C0A5FKU7T5M へ）
# OPENCLAW_BOT_TOKEN は ~/openclaw/config/.env
```

Slack に実際のメッセージが出たことを目で見るまで、復旧とみなさない。

## トリガーで起こしたセッションは Slack コネクタを持たない

**クラウドから `create_trigger` / `fire_trigger` で Mac のセッションを起こすと、
起こされたターンには `mcp__Slack__*` が存在しない。** 依頼した側にコネクタの
受け渡し権限が無いと、トリガーはコネクタを保存せずに作られる。

2026-08-15 に、これで **2 件の依頼が「無応答」に見えた。** Mac 側は実際には処理して
アイドルに戻っていたが、**書いた報告が外に出ない経路**になっていた。
トリガー作成時に次の警告が出ていた。

```text
warning: this trigger stores no MCP connectors, so the sessions it fires
will run without connector (mcp__<server>__*) tools.
```

**この警告を無視しない。** 出たら、依頼文の中で報告経路を `curl` に切り替える。

```bash
set -a; . ~/openclaw/config/.env; set +a
curl -sS -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $OPENCLAW_BOT_TOKEN" \
  -H 'Content-type: application/json; charset=utf-8' \
  -d "$(jq -n --arg c C0A5FKU7T5M --arg t "本文" '{channel:$c, text:$t}')"
```

**無応答を相手の怠慢と決めつけない。** まず `get_session` で状態を見る。
`SESSION_STATUS_IDLE` に戻っているなら、相手は処理を終えている。
**届いていないのは経路の問題であり、送り直しても直らない。**

## 復旧後にやること

画像の受け渡しが止まっているのはこの故障のため。復旧したら次の順で流す。

1. OpenClaw に `assets/social/lalaport-guide-2026/ranking-top10.png` を
   Slack スレッドへ**添付**させる（リンクではなくファイル添付）
2. Jordan の 👍 を待つ
3. 👍 の後に OpenClaw が X へ投稿する（`@OpenClaw tweet <slug>`）

**3 を 2 より先に実行しない。** CLAUDE.md 最上位ルール 4 のとおり。

## 関連

- [`docs/seo-monitoring.md`](./seo-monitoring.md) — launchd ジョブの定義とログの場所
- [`docs/session-handoff.md`](./session-handoff.md) — 調査の経緯
