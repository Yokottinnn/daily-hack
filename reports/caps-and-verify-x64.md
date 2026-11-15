# フォローの上限 ＋ x64 の書き込み確認 ＋ 入口却下の内訳

**このレポートが作られた時刻: 2026-09-13 20:33:13 JST**

> **rc=0 は「やった」証拠にならない**（ルール 13）。
> x64 は「置き換えた」と書いたが、**数字が入るのは次にフォローが走ってから。**

**測るだけ。上限は触らない。**

## 1. x64 の書き込み確認（**結果の状態を別の口で見る**）

```
  competitor-follower-follow.js    コード内の印: 1 箇所 / 最終更新 09-13 19:58
  hashtag-follow.js                コード内の印: 1 箇所 / 最終更新 09-13 19:58

  --- 退避（戻せる状態か） ---
    hashtag-follow.js.bak-20260913-195829
    competitor-follower-follow.js.bak-20260913-195829
    unfollow-handle.js.bak-20260913-152559
    mutual-prune.js.bak-20260913-104853

  --- 実際に数字が入ったか（reply-followers.json） ---
    全体: 346 件 / followers_at_follow を持つ: **0 件**
    → **まだ 0 件。** x64 を当てた後にフォローが走っていない

    今日フォローした件数: 9 件
```

**0 件 でも失敗とは限らない。** 次にフォローが走るまで入らない。
**下の「いつ回るか」と突き合わせて判断する。**

## 2. いまの上限と間隔（**実物**）

```
  ══ competitor-follower-follow.js
    8: * cap: COMPETITOR_FOLLOW_DAILY_CAP (default 10)
    19:const REPLY_FOLLOWERS_PATH = `${WS}/data/reply-followers.json`;
    27:const COMPETITORS = [
    33:const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);
    34:const FOLLOW_GAP_MS = 30 * 1000;
    62:  if (fs.existsSync(REPLY_FOLLOWERS_PATH)) {
    64:      const d = JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8"));
    111:  const todayDow = todayDate.getDay();
    112:  if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
    113:    log(`=== competitor-follower SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
    119:  log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITORS.length-1}) cap=${DAILY_CAP} ===`);
    132:  const targets = scrapedHandles.filter(h => !followed.has(h.toLowerCase())).slice(0, DAILY_CAP);

  ══ hashtag-follow.js
    13: * Daily cap: env HASHTAG_FOLLOW_DAILY_CAP (default 10)
    24:const REPLY_FOLLOWERS_PATH = `${WS}/data/reply-followers.json`;
    30:const DAILY_CAP = parseInt(process.env.HASHTAG_FOLLOW_DAILY_CAP || "10", 10);
    31:const FOLLOW_GAP_MS = 30 * 1000;
    75:  if (fs.existsSync(REPLY_FOLLOWERS_PATH)) {
    77:      const d = JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8"));
    86:  const todayDow = new Date().getDay(); // JST近似 (UTC+9 offset考慮)
    87:  if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
    88:    log(`=== hashtag-follow SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
    92:  log(`=== hashtag-follow start (cap=${DAILY_CAP}) ===`);
    127:  const alreadyTodayB = todayFollowCountFrom(REPLY_FOLLOWERS_PATH);
    129:  const remaining = Math.max(0, DAILY_CAP - usedToday);  // ※ Tier A 内の cap、他 source とは別計算がベターだがまず合算 conservative

  ══ comment-orchestrator.sh
    3:# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
    9:MAX_PICKS=${MAX_PICKS_PER_FIRE:-2}
    10:REPLY_FOLLOW_DAILY_CAP=${REPLY_FOLLOW_DAILY_CAP:-10}
    22:log "=== comment orchestrator start (max_picks=$MAX_PICKS, reply_follow_cap=$REPLY_FOLLOW_DAILY_CAP) ==="
    53:PICKS_FILE=/tmp/orch-picks.$$.json
    62:    if (picked.length >= $MAX_PICKS) break;
    69:  fs.writeFileSync('$PICKS_FILE', JSON.stringify(picked));
    72:N_PICKED=$(/usr/local/bin/node -e "console.log(require('$PICKS_FILE').length)")
    73:log "picked $N_PICKED / max $MAX_PICKS (from $N candidates)"
    76:  rm -f $PICKS_FILE
    90:REPLY_FOLLOW_COUNT=$(/usr/local/bin/node -e "
    101:log "today's reply-connected follows: $REPLY_FOLLOW_COUNT / $REPLY_FOLLOW_DAILY_CAP"

  --- 直近の実行（ログの最終行） ---
    competitor-follower-follow.log     09-13 18:46
        @<伏せ>: ✅
      [2026-09-13T09:46:43.495Z] === end: 1/30 OK ===
      === end: 1/30 OK ===

    hashtag-follow.log                 09-13 17:04
        @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
      [2026-09-13T08:04:12.815Z] === end: 1/2 OK ===
      === end: 1/2 OK ===

    comment-orchestrator.log           09-13 19:03
      [2026-09-13T19:03:35] --- processing #4/4 for @<伏せ> ---
      [2026-09-13T19:03:37] gen failed (#4): {"ok":false,"error":"生成側が skip: ティッシュの販売投稿。金銭・投資・節約の話題ではなく、商品売�
      [2026-09-13T19:03:37] === orchestrator done: 4 drafts, 9 reply-connected follows today ===

  --- plist の間隔 ---
    ══ ai.openclaw.competitor-follower-follow
      <key>StartCalendarInterval</key> <key>Hour</key> <integer>11</integer> <key>Minute</key> <integer>30</integer> <key>Hour</key> <integer>18</integer> <key>Minute</key> <integer>30</integer> 
    ══ ai.openclaw.hashtag-follow
      <key>StartCalendarInterval</key> <key>Hour</key> <integer>10</integer> <key>Minute</key> <integer>15</integer> <key>Hour</key> <integer>17</integer> <key>Minute</key> <integer>0</integer> 
    ══ ai.openclaw.comment-warmup
      <key>StartCalendarInterval</key> <key>Hour</key> <integer>16</integer> <key>Minute</key> <integer>0</integer> <key>Hour</key> <integer>12</integer> <key>Minute</key> <integer>0</integer> <key>Hour</key> <integer>22</integer> <key>Minute</key> <integer>0</integer> <key>Hour</key> <integer>19</integer> <key>Minute</key> <integer>0</integer> 
```

## 3. 候補のうち どれくらいが広告か（**picked の枠を無駄にしている分**）

```
  --- 日ごとの入口却下（LLM を呼ぶ前に落ちた数） ---
    日付        picked  広告 話題外     enq
    2026-08-31         8       0       0       6
    2026-09-01         8       0       0       8
    2026-09-02         2       0       0       2
    2026-09-06         4       1       1       1
    2026-09-07         0       0       0       0
    2026-09-08        20       2       8       6
    2026-09-09        16       4       4       3
    2026-09-13        16       4       3       9

  --- 入口で落ちた理由に出てきた語（上位 15） ---
      14 #PR
       6 r10.to
       4 詳細はこちら
       4 クーポン配布
       2 新規登録で
       2 拡散希望
       2 抽選で
       2 app.adjust.com
```

**この語の一覧が、いま何を掴んでいるかの実物。**
**探す段階（`trend-detect`）で落とせるものが在るかを、ここから決める。**

## 4. 費用

**ファイルを読むだけ。LLM を呼ばない。ブラウザも触らない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

返信ループの**実績**（2026-09-13・`docs/recurring-job-costs.md`）:
1 回 $0.003 ／ 1 日 **$0.027**（生成 9 件）／ 1 か月 **約 $0.81**。
上限に張り付いた場合は 1 日 $0.048 ／ 1 か月 $1.44 だが、**これは安全弁であって予想ではない。**
