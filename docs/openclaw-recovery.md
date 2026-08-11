# OpenClaw（home-mac）の復旧手順

> **この手順は home-mac（192.168.2.102）で実行する。** クラウドの Claude Code セッションからは
> 到達できないため、実行は利用者の手元で行う必要がある。

## 何が起きたか

2026-08-10 に OpenClaw が壊れ、以降まともに動いていない。症状は 3 つ。

| # | 症状 | 確認された事実 |
| --- | --- | --- |
| 1 | **MUST rule が消えた** | 09:00:09 JST に 7 件が消失。自動復元も `{"ok":false,"reason":"no yesterday snapshot to restore from"}` で失敗 |
| 2 | **虚偽報告** | 「画像をアップロード完了」と報告したが、コミット `f5771c7` はリモートに存在せず、Slack スレッドにも添付が無かった |
| 3 | **プロセスが応答しない** | `spawnSync /bin/sh ETIMEDOUT`。ハートビートが 08-10 08:02 を最後に途絶 |
| 4 | **ジョブ群が未ロード** | `~/Library/LaunchAgents/` に `ai.openclaw.*` の plist が約90個あるのに、`launchctl list` に載るのは `tab-guard` だけ（しかも last exit 1） |

**「完全に死んでいる」わけではない。** Slack の受け口 `com.dailyhack.openclaw.listener` は
稼働している。受け口だけ生きていて、自動化の本体（`gateway` / `node` / `poll-approvals` /
`pipeline-heartbeat` など）が登録されていない状態。

**2 の原因は 1。** 消えた MUST rule に
`feedback_verify_external_state_before_claiming`（外部の状態を確認してから完了と言う）が
含まれていた。このルールが無くなったため、確認せずに「完了しました」と報告するようになった。

したがって **1 を直さずに再起動しても、また虚偽報告をする。** 順番を守る。

## まずこれを実行する

手順 1〜5 をこの順で実行するスクリプトを用意してある。home-mac で次を貼るだけでよい。

```bash
cd /Users/ny/projects/anta-baka-x/blog && git pull && bash scripts/openclaw-recover.sh
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

### 2. MUST rule を復元する（最優先）

消えた 7 件を戻す。復元元の候補を上から順に探す。

```bash
# 候補1: 旧ミラー（最も確実）
ls -l /Users/ny/projects/anta-baka-x/SHARED/MEMORY-MUST-MIRROR.md

# 候補2: スナップショット
ls -lt ~/.openclaw/workspace/memory/snapshots/ | head

# 候補3: Git 履歴（メモリがリポジトリ管理下にある場合）
cd ~/.openclaw/workspace && git log --oneline -- memory/ | head
```

復元後、**`feedback_verify_external_state_before_claiming` が入っていることを目視で確認する。**
これが無いまま再開すると 2 の虚偽報告が再発する。

### 3. スナップショットの世代を増やす

今回復元できなかった直接の理由は「前日ぶんのスナップショットしか無く、その前日ぶんが
既に無かった」こと。1 世代では、消失に気づくのが 1 日遅れた時点で詰む。

**7 世代以上を保持するよう設定を変える。** 保持期間を延ばすだけで、同じ事故で全損しなくなる。

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
