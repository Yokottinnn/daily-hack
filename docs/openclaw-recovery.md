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

**2 の原因は 1。** 消えた MUST rule に
`feedback_verify_external_state_before_claiming`（外部の状態を確認してから完了と言う）が
含まれていた。このルールが無くなったため、確認せずに「完了しました」と報告するようになった。

したがって **1 を直さずに再起動しても、また虚偽報告をする。** 順番を守る。

## 手順

### 1. まず現状を確認する

```bash
# プロセスが生きているか
launchctl print gui/$(id -u)/ai.openclaw.sitemap-autosubmit | grep -E 'state|runs|last exit'
launchctl print gui/$(id -u)/ai.openclaw.seo-health       | grep -E 'state|runs|last exit'

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

# 残っていれば落としてから
launchctl kickstart -k gui/$(id -u)/ai.openclaw.sitemap-autosubmit
launchctl kickstart -k gui/$(id -u)/ai.openclaw.seo-health
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
