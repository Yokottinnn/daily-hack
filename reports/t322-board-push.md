# 作戦室の元データが送られない理由（t322・**$0**）

生成: **2026-10-19T11:28:12+0900**・worktree: `/Users/ny/.openclaw/ops-heartbeat-wt`

## ① git の見え方

```text
--- status reports/board
 M reports/board/gsc-weekly.json
--- check-ignore
--- ls-files -v（h=assume-unchanged / S=skip-worktree）
H reports/board/asp-probe/a8partnered.json
H reports/board/asp-probe/a8partnered.md
H reports/board/asp-probe/others.json
H reports/board/asp-probe/others.md
H reports/board/gsc-weekly.json
H reports/board/mac-weekly-status.json
H reports/board/trend-words.json
H reports/board/trend/2026-10-15.json
H reports/board/trend/2026-10-16.json
H reports/board/trend/2026-10-17.json
H reports/board/trend/2026-10-18.json
H reports/board/trend/2026-10-19.json
H reports/board/x-numbers.json
H reports/board/x-weekly.json
--- 中身の generated（worktree）
"generated":"2026-10-19T11:25:06"
--- 中身の generated（HEAD）
"generated":"2026-10-12T18:41:03"
--- HEAD / origin
9c1b3c91 2026-10-19 11:28:11 +0900 ops: running t322-board-push-diag.sh
9c1b3c91 2026-10-19 11:28:11 +0900 ops: running t322-board-push-diag.sh
--- info/exclude
--- core.excludesFile
```

## ② 載せたもの

```text
 reports/board/gsc-weekly.json | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```
