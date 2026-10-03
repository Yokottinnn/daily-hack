# アンフォローは動いているか（2026-10-03 21:16 JST・$0）

**このレポートが作られた時刻: 2026-10-03 21:16:48 JST**

> **外さない。フォローしない。設定を変えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**

## ① launchd（`launchctl print` が証拠。`list` は使わない・最上位ルール 13）

```
  載っている  ai.openclaw.follow-balance                   state=not running runs=4 last_exit=0
  載っている  ai.openclaw.competitor-follower-follow       state=not running runs=6 last_exit=0
  **載っていない**  ai.openclaw.unfollow-daily              （plist は在る）
  **載っていない**  ai.openclaw.unfollow-cleanup-morning    （plist は在る）
  **載っていない**  ai.openclaw.unfollow-cleanup-evening    （plist は在る）
  無い        ai.openclaw.x-follower-unfollow
  **載っていない**  ai.openclaw.auto-detect-and-unfollow-inactive（plist は在る）
  **載っていない**  ai.openclaw.revenge-unfollow            （plist は在る）
  止めてある  ai.openclaw.follow-daily                    （.disabled）
  止めてある  ai.openclaw.follow-morning                  （.disabled）
  載っている  ai.openclaw.hashtag-follow                   state=not running runs=6 last_exit=0
  無い        ai.openclaw.x-follower-follow

  --- follow-balance の定時
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 11
      "Minute" => 45
    }
    1 => {
      "Hour" => 18
      "Minute" => 45
    }
  ]
  "WorkingDirectory" => "/Users/ny/.openclaw/workspace"
}
```

## ② follow-balance.log の直近（末尾 60 行）

```
  == follow-balance.log（113387 bytes・更新 10/03 18:49）
    [2026-10-03T02:49:24.927Z]   @<伏せ>: **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）
    [2026-10-03T02:49:24.927Z]   @<伏せ>: **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）
    [2026-10-03T02:49:24.928Z] === 外した: 0 件 / 候補 7 件（今日のフォロー 2 件） / **一覧に混ざっていた未フォロー 7 件** ===
    [2026-10-03T02:49:24.928Z] === 外した: 0 件 / 候補 7 件（今日のフォロー 2 件） / **一覧に混ざっていた未フォロー 7 件** ===
    [2026-10-03T09:45:05.395Z] === follow-balance start (dry=false min=20 max=20 grace=7d inactive=30d big=5000) ===
    [2026-10-03T09:45:05.395Z] === follow-balance start (dry=false min=20 max=20 grace=7d inactive=30d big=5000) ===
    [2026-10-03T09:45:41.517Z] フォロー中: 264 件（29 秒）
    [2026-10-03T09:45:41.517Z] フォロー中: 264 件（29 秒）
    [2026-10-03T09:46:13.076Z] フォロワー: 325 件（32 秒）
    [2026-10-03T09:46:13.076Z] フォロワー: 325 件（32 秒）
    [2026-10-03T09:46:13.081Z] 一覧を書いた: follow-balance-lists.json
    [2026-10-03T09:46:13.081Z] 一覧を書いた: follow-balance-lists.json
    [2026-10-03T09:46:13.086Z] 覚えている未フォロー: 42 件（今回は見ない）
    [2026-10-03T09:46:13.086Z] 覚えている未フォロー: 42 件（今回は見ない）
    [2026-10-03T09:46:13.098Z] ホワイトリスト 12 件 / 反応の記録 554 件 / フォロー日時の記録 205 件
    [2026-10-03T09:46:13.098Z] ホワイトリスト 12 件 / 反応の記録 554 件 / フォロー日時の記録 205 件
    [2026-10-03T09:46:17.964Z] 実数（ヘッダー）: フォロー中 244 / フォロワー 304 → 比率 0.803（目標 176 件 / 警戒 197 件 / 下限 136 件）
    [2026-10-03T09:46:17.964Z] 実数（ヘッダー）: フォロー中 244 / フォロワー 304 → 比率 0.803（目標 176 件 / 警戒 197 件 / 下限 136 件）
    [2026-10-03T09:46:17.965Z] 今日フォローした数: 2 件 → **今回の上限 20 件**（**警戒線 197 件 を超えている。目標 176 件 まで戻す（あと 68 件 / 今回 20 件）** / 絶対上限 20�
    [2026-10-03T09:46:17.965Z] 今日フォローした数: 2 件 → **今回の上限 20 件**（**警戒線 197 件 を超えている。目標 176 件 まで戻す（あと 68 件 / 今回 20 件）** / 絶対上限 20�
    [2026-10-03T09:46:17.965Z] 走査 264 件 から 未フォロー 16 件 を除いた → 248 件
    [2026-10-03T09:46:17.965Z] 走査 264 件 から 未フォロー 16 件 を除いた → 248 件
    [2026-10-03T09:46:17.965Z] 片思い: 69 件 / 相互: 182 件
    [2026-10-03T09:46:17.965Z] 片思い: 69 件 / 相互: 182 件
    [2026-10-03T09:46:17.966Z] ① 片思いから 7 件
    [2026-10-03T09:46:17.966Z] ① 片思いから 7 件
    [2026-10-03T09:48:09.754Z] プロフィールを開いた: 40 件 / **外す候補 合計 7 件**
    [2026-10-03T09:48:09.754Z] プロフィールを開いた: 40 件 / **外す候補 合計 7 件**
    [2026-10-03T09:48:09.756Z] 守った内訳: ホワイトリスト 1 / 反応をくれた人 55 / 猶予 66
    [2026-10-03T09:48:09.756Z] 守った内訳: ホワイトリスト 1 / 反応をくれた人 55 / 猶予 66
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:09.756Z]   ✂ @<伏せ> — 返していない（片思い）
    [2026-10-03T09:48:22.379Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/Nigorin9","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:48:22.379Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/Nigorin9","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:48:35.050Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/ichigoichie2025","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:48:35.050Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/ichigoichie2025","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:48:48.844Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/michiyosa_youth","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:48:48.844Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/michiyosa_youth","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:49:01.505Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/jtc_ojisan2","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:49:01.505Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/jtc_ojisan2","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:49:14.176Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/TK00800365","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:49:14.176Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/TK00800365","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:49:27.118Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/KMYY508","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:49:27.118Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/KMYY508","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:49:39.730Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/DelightingAll","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:49:39.730Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/DelightingAll","suspended":false,"notfound":false,"locked":false,"empty":true,"follow_btns":"(無し)"}
    [2026-10-03T09:49:39.733Z] === 外した: 0 件 / 候補 7 件（今日のフォロー 2 件） ===
    [2026-10-03T09:49:39.733Z] === 外した: 0 件 / 候補 7 件（今日のフォロー 2 件） ===
```

## ③ 状態ファイル

```
  == follow-balance-state.json（更新 10/03 18:49）
    {
     "noa0rz": {
      "unfollowed_at": "2026-09-27T13:47:22.353Z",
      "why": "返していない（片思い）",
      "rank": 1
     },
     "jun_01_": {
      "unfollowed_at": "2026-09-27T13:47:48.892Z",
      "why": "返していない（片思い）",
      "rank": 1
     },
     "alohamiler": {
      "unfollowed_at": "2026-10-01T02:48:03.498Z",
      "why": "返していない（片思い）",
      "rank": 1
     },
     "Umaane33": {
      "unfollowed_at": "2026-09-27T13:48:09.927Z",
      "why": "返していない（片思い）",
      "rank": 1
     },
     "uorokushoten": {
      "unfollowed_at": "2026-09-27T15:20:53.102Z",
      "why": "返していない（片思い）",
      "rank": 1
     },
     "isse501": {
      "unfollowed_at": "2026-09-27T15:21:01.401Z",
      "why": "返していない（片思い）",
      "rank": 1
     },
     "zaionline": {
      "unfollowed_at": "2026-09-27T15:21:09.277Z",
      "why": "返していない（片思い）",
      "rank": 1
     },
     "KS65616482": {
      "unfollowed_at": "2026-09-27T15:25:26.098Z",
      "why": "返していない（片思い）",
      "rank": 1
  == unfollow-cleanup-state.json（更新 09/09 20:31）
    {
     "version": 1,
     "phase": "A",
     "started_at": "2026-07-19T22:50:00+09:00",
     "target_ratio_phase_a": 2.44,
     "current_ratio": 1.26,
     "unfollow_log": "[配列 65 件]",
     "tier_snapshot": {
      "T1": 0,
      "T2": 46,
      "T3": 106,
      "T4": 47,
      "total": 199,
      "at": "2026-09-09T11:30:09.450Z"
     },
     "halt_flags": {},
     "note": "初期化 2026-07-19。 実 tier scrape は 初回 fire 時に実行。 明日 09:30 JST 初 fire。"
    }
```

## ④ 今日のフォロー（足す側）

```
  competitor-follower-follow.log           今日の行 68（更新 10/03 18:49）
  hashtag-follow.log                       今日の行 19（更新 10/03 17:03）
  reply-followback-check.log               今日の行 21（更新 10/03 13:15）
  （ここに出ていないログは、今日の行が無い）
```

## ⑤ いまのヘッダー

```
  フォロー中 247 / フォロワー 305 / 比率 0.810
  目標 0.58 なら フォロー中 177 件・上限 0.65 なら 198 件
```

**外していない。フォローしていない。設定を変えていない（$0／回・$0／日・$0／月）。**
