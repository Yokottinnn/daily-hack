# 返信の数の設定と実績（2026-10-25 23:54:52 JST・読むだけ・$0）

## comment-warmup の plist（発火の時刻と環境変数）
```
{
  "EnvironmentVariables" => {
    "MAX_AGE_HOURS" => "18"
    "MAX_PICKS_PER_FIRE" => "6"
    "MIN_LIKES" => "2"
    "REPLY_FOLLOW_DAILY_CAP" => "30"
  }
  "Label" => "ai.openclaw.comment-warmup"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/comment-warmup-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/comment-warmup.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 16
      "Minute" => 0
    }
    1 => {
      "Hour" => 12
      "Minute" => 0
    }
    2 => {
      "Hour" => 22
      "Minute" => 0
    }
    3 => {
      "Hour" => 19
      "Minute" => 0
    }
  ]
}
```

## launchd に載っているか
```
	state = not running
	runs = 7
	last exit code = 0
		state = active
		state = active
```

## comment-orchestrator.sh の中の件数・上限の設定
```
3:# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
9:MAX_PICKS=${MAX_PICKS_PER_FIRE:-2}
10:REPLY_FOLLOW_DAILY_CAP=${REPLY_FOLLOW_DAILY_CAP:-10}
22:log "=== comment orchestrator start (max_picks=$MAX_PICKS, reply_follow_cap=$REPLY_FOLLOW_DAILY_CAP) ==="
53:PICKS_FILE=/tmp/orch-picks.$$.json
84:    if (picked.length >= $MAX_PICKS) break;
96:  fs.writeFileSync('$PICKS_FILE', JSON.stringify(picked));
99:N_PICKED=$(/usr/local/bin/node -e "console.log(require('$PICKS_FILE').length)")
100:log "picked $N_PICKED / max $MAX_PICKS (from $N candidates)"
103:  rm -f $PICKS_FILE
128:log "today's reply-connected follows: $REPLY_FOLLOW_COUNT / $REPLY_FOLLOW_DAILY_CAP"
131:  PICK=$(/usr/local/bin/node -e "console.log(JSON.stringify(require('$PICKS_FILE')[$i]))")
159:  if [ "$REPLY_FOLLOW_COUNT" -lt "$REPLY_FOLLOW_DAILY_CAP" ]; then
193:        log "  recorded in reply-followers.json (count now $REPLY_FOLLOW_COUNT/$REPLY_FOLLOW_DAILY_CAP)"
197:    log "  follow skipped: daily cap ($REPLY_FOLLOW_DAILY_CAP) reached"
201:rm -f $PICKS_FILE
```

## 直近 7 日、実際に出た返信の数（comment-warmup.log の ok:true・日付は entry_id の JST）
```
20261019 12件
20261020 21件
20261021 22件
20261022 20件
20261023 19件
20261024 19件
20261025 24件
--- 時刻ごと（直近 2 日）
   4 20261023 12時
   4 20261023 16時
   4 20261023 19時
   3 20261023 22時
   3 20261024 05時
   6 20261024 12時
   3 20261024 16時
   5 20261024 19時
   2 20261024 22時
   5 20261025 05時
   6 20261025 12時
   5 20261025 16時
   5 20261025 19時
   3 20261025 22時
```
**読んだだけ。LLM を呼んでいない（$0／回）。**
