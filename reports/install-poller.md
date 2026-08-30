# 1 分ポーラーを入れる（2026-08-31 00:44 JST）

> 死活監視（30 分）は触らない。**実行だけを別ジョブに切り出す。**
> 経緯: `docs/x-post-latency-postmortem.md`

## 0. もう入っていないか

- 現在の StartInterval: `無し` / ロード: `0` 件

## 1. 前提を確かめる

- `scripts/ops-run-tasks.sh` は origin/main にある
- python: `/opt/homebrew/bin/python3.11`
- heartbeat の plist を環境の見本にする

## 2. plist を書く

- 書いた: StartInterval=60 / 環境変数 4 件を heartbeat から写した
- 実行するもの: /bin/bash /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh

## 3. ロードする

> **触るのは `com.dailyhack.ops-poller` だけ。** 自分を動かしている `com.dailyhack.ops-heartbeat` には触らない
- **ロード成功**

## 4. 確認

- `com.dailyhack.ops-poller`: StartInterval=**60** 秒 / ロード=**1** 件
- `com.dailyhack.ops-heartbeat`: ロード=**1** 件（触っていない）

**これで `ops/tasks` にコミットしたものは最大 1 分で走る。**

> API 課金は **$0**。ポーラーがするのは `git fetch` と `ops/tasks` の実行だけで、
> **LLM を呼ばない。** 1,440 回/日 でも Anthropic 側の課金は発生しない。
