# 11/6 17:01 の全停止の原因（2026-11-07 14:50 JST・読むだけ・$0）

## 1. tab-guard・ensure-chrome・daily-supervisor（07:45〜08:09 UTC）
```
--- tab-guard
[2026-11-06T08:01:27.497Z] 🚨 Jordan のタブが 13 → 1 枚（一括破壊） → 自動化を全停止
[2026-11-06T08:01:27.851Z] 停止完了
[2026-11-06T08:01:27.854Z] 監視終了（要因を確認してください）
[2026-11-06T08:01:27.902Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
--- ensure-chrome
[2026-11-06T08:01:06Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
[2026-11-06T08:01:15Z] ensure-chrome: Chrome up and CDP responsive
--- daily-supervisor
[2026-11-06T08:00:05Z] === daily-supervisor start ===
[2026-11-06T08:00:31Z] 全部 走った
[2026-11-06T08:00:31Z] === daily-supervisor done ===
```

## 2. 同じ時間帯に行が出たほかのログ（Chrome を使うジョブ）
```
boost-watch-out: 8 行（最後: [2026-11-06T07:58:03.794Z] 2118600777250046289（comment-20261106-1605-4）: 表示 17 / 毎分 0.1（1 つ前 0.2・最初 1.0））
boost-watch: 8 行（最後: [2026-11-06T07:58:03.794Z] 2118600777250046289（comment-20261106-1605-4）: 表示 17 / 毎分 0.1（1 つ前 0.2・最初 1.0））
comment-orchestrator: 24 行（最後: [2026-11-06T08:05:44] === orchestrator done: 5 drafts, 1 reply-connected follows today ===）
comment-warmup: 24 行（最後: [2026-11-06T08:05:44] === orchestrator done: 5 drafts, 1 reply-connected follows today ===）
hashtag-follow: 1 行（最後: [2026-11-06T08:00:05.527Z] === hashtag-follow start (cap=90) ===）
incoming-reply-watcher: 12 行（最後: [2026-11-06T17:05:42.711Z] no new replies）
ops-heartbeat: 2 行（最後: ops-heartbeat: pushed 2026-11-06T16:54:58Z (27 jobs)）
reply-followers-cleanup: 5 行（最後: [2026-11-06T17:00:05.732Z] nothing due）
x-loop-guardian: 4 行（最後: [2026-11-06T17:01:24] unresolved: load-failed:comment-warmup load-failed:reply-followers-cleanup load-failed:incoming-reply-watcher load-fai）
```
