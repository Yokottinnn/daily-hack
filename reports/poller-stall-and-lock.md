# ポーラーが素通りしている理由（2026-08-31 02:14:55 JST）

> 16:44:33 UTC を最後に `ops: tasks` の push が無い。60 秒間隔なので**10 回以上 素通り**。

## 1. ロックの取り残し（**本命**）

- **ロックが残っている**: `/Users/ny/.openclaw/ops-heartbeat-wt/.tasks.lock`
  - 作られた時刻: 2026-08-31 02:14:55
  - 経過: **0 秒**（`OPS_TASK_STALE_SEC` は既定 1800 秒）

🚨 **これが原因。** 取り残しが 1800 秒に達するまで、毎分 黙って素通りする。
あと **1800 秒**で自動的に外れて再開する見込み。

> **設計の穴。** `ops-run-tasks.sh` はロックを取れないとき**何も出力しない**ので、
> 外から見て「止まっている」のか「譲っている」のか区別できない。
> 取り残しの閾値 1800 秒は、1 分間隔のポーラーに対して長すぎる。

## 2. ポーラーは生きているか

- ロード: **1** 件
- 実体 `/Users/ny/.openclaw/bin/ops-run-tasks.sh`: **ある**（5494 B）
```
	state = running
	program = /bin/bash
	runs = 60
	last exit code = 0
		state = active
		state = active
	properties = runatload | inferred program
```

### ポーラーのログ（末尾）
```
-- out (08-31 01:44) --
ops-run-tasks: 1 件 実行した
ops-run-tasks: pushed
ops-run-tasks: 1 件 実行した
ops-run-tasks: pushed
ops-run-tasks: 1 件 実行した
ops-run-tasks: pushed
-- err (08-31 02:14) --
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
ops-run-tasks: 1800 秒以上前のロックを外す
```

## 3. tab-guard の pkill に巻き込まれていないか

`haltAutomation()` は `pkill -f 'workspace/scripts/.*\.js'` を撃つ。
**ポーラーの実体は `~/.openclaw/bin/` にあり `workspace/scripts` の下ではない**ので、
巻き込まれないはず。**念のため tab-guard の直近ログを見る。**
```
[2026-08-13T15:34:17.635Z] 監視終了（要因を確認してください）
[2026-08-15T04:43:02.599Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-08-30T14:57:03.141Z] 🚨 Jordan のタブが 19 → 1 枚（一括破壊） → 自動化を全停止
[2026-08-30T14:57:04.531Z] 停止完了
[2026-08-30T14:57:04.534Z] 監視終了（要因を確認してください）
[2026-08-30T14:57:04.586Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
```

---

# ここから t015 の内容（停止ロックと、3 件が働いているか）

## 4. tab-guard の停止ロックは残っているか

```javascript
27:const LOCK = "/tmp/x-login-in-progress";
```
- 候補にロックは**見つからなかった**

## 5. Chrome とタブ

- Chrome プロセス: **生きている**
- **いま開いているタブ: 1 枚**（発火時は 19 → 1）
- ⚠️ **まだ 1 枚以下、または CDP に届かない。** この状態で解除しても再発火する

## 6. 戻した 3 件は働いたか

| ジョブ | ロード | ログの最終更新 |
| --- | --- | --- |
| `comment-warmup` | 1 | 08-30 22:05/Users/ny/.openclaw/workspace/logs/comment-warmup.log |
| `competitor-follower-follow` | 1 | 08-09 18:30/Users/ny/.openclaw/logs/competitor-follower-follow.log |
| `hashtag-follow` | 1 | 08-09 20:00/Users/ny/.openclaw/logs/hashtag-follow.log |

## 7. 直すなら（**このタスクは直さない**）

- ロックの取り残しが原因なら、`OPS_TASK_STALE_SEC` を **1800 → 300 秒**に縮める
  （1 分間隔のポーラーに 30 分の取り残し許容は長すぎる）
- あわせて、**譲ったときに 1 行 ログを出す。** いまは無言なので外から区別できない
