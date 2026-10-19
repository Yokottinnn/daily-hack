# 作戦室の取得結果を送る・X の数字を読み直す（t323・**$0**）

生成: **2026-10-19T11:31:36+0900**

## ① 起動スクリプト

```bash
#!/bin/bash
# 毎回 origin/main から本体を取り出して走らせる。作業ツリーには触らない（t280）。
set -uo pipefail
REPO="/Users/ny/projects/anta-baka-x/blog"
LOG="$HOME/.openclaw/logs/board-weekly.log"
echo "=== $(date '+%Y-%m-%dT%H:%M:%S%z') boot" >> "$LOG"
git -C "$REPO" fetch -q origin main >> "$LOG" 2>&1 || echo "fetch に失敗（続行する）" >> "$LOG"
LATEST="${TMPDIR:-/tmp}/board-weekly-latest.sh"
git -C "$REPO" show origin/main:scripts/strategy-board/mac-weekly.sh > "$LATEST" 2>>"$LOG" || { echo "本体を取り出せなかった" >> "$LOG"; exit 1; }
[ -s "$LATEST" ] || { echo "本体が空" >> "$LOG"; exit 1; }
DAILY_HACK_REPO="$REPO" exec /bin/bash "$LATEST" >> "$LOG" 2>&1
```

### いま mac-weekly が動いているか

```text
```

### reports/board

```text
/Users/ny/.openclaw/ops-heartbeat-wt/reports/board:
total 152
drwxr-xr-x    9 ny  staff    288 Oct 19 11:25 .
drwxr-xr-x  948 ny  staff  30336 Oct 19 11:31 ..
drwxr-xr-x    6 ny  staff    192 Oct 19 06:49 asp-probe
-rw-r--r--    1 ny  staff  45543 Oct 19 11:25 gsc-weekly.json
-rw-r--r--    1 ny  staff    168 Oct 19 11:30 mac-weekly-status.json
drwxr-xr-x    7 ny  staff    224 Oct 19 07:10 trend
-rw-r--r--    1 ny  staff   3612 Oct 19 07:19 trend-words.json
-rw-r--r--    1 ny  staff    513 Oct 19 11:30 x-numbers.json
-rw-r--r--    1 ny  staff  13530 Oct 19 11:29 x-weekly.json

/Users/ny/.openclaw/ops-heartbeat-wt/reports/board/asp-probe:
total 88
drwxr-xr-x  6 ny  staff    192 Oct 19 06:49 .
drwxr-xr-x  9 ny  staff    288 Oct 19 11:25 ..
-rw-r--r--  1 ny  staff  19419 Oct 19 11:28 a8partnered.json
-rw-r--r--  1 ny  staff  15078 Oct 19 11:28 a8partnered.md
-rw-r--r--  1 ny  staff   1381 Oct 19 11:29 others.json
-rw-r--r--  1 ny  staff    837 Oct 19 11:29 others.md
```

## ② X の数字

```json
{
 "generated": "2026-10-19T02:31:37.353Z",
 "handle": "heng_ji31590",
 "header": {
  "following": 305,
  "followers": 515,
  "raw": {
   "following": "305 フォロー中",
   "followers": "515 フォロワー"
  }
 },
 "d7": {
  "impressions": 16500,
  "profileVisits": 113,
  "engagements": 237,
  "verifiedFollowers": 267,
  "followersOnPage": 515
 },
 "d90": {
  "impressions": 173600,
  "profileVisits": 1400
 },
 "ocr": {
  "verifiedFollowers": 267,
  "verifiedImpressions90": 167,
  "eligible": false
 }
}
```

## ③ 載せたもの

```text
 reports/board/asp-probe/a8partnered.json |  30 +++++++-
 reports/board/asp-probe/a8partnered.md   |   7 +-
 reports/board/asp-probe/others.json      |  30 ++++++--
 reports/board/asp-probe/others.md        |  12 ++-
 reports/board/mac-weekly-status.json     |   2 +-
 reports/board/x-numbers.json             |   8 +-
 reports/board/x-weekly.json              | 126 +++++++++++++++++++++++++------
 7 files changed, 172 insertions(+), 43 deletions(-)
gsc-weekly.json: "generated":"2026-10-19T11:25:06"
asp-probe/a8partnered.json: "generated": "2026-10-19T02:28:25.661Z"
mac-weekly-status.json: "generated":"2026-10-19T11:30:27+0900"
x-numbers.json: "generated": "2026-10-19T02:31:37.353Z"
```
