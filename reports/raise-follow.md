# フォロー量の引き上げ（2026-08-28 00:39 JST）

> フォロー系は LLM 不使用のため **API 費用は $0 のまま。**
> 増やしても Anthropic への課金は増えない。**気にするのは X のスパム判定。**

## 1. 先に歯止めを確認する（フォロー比）

- フォロワー: 214
- フォロー（followed.json）: 157
- 比率: 0.73 倍
- 安全域。cap を上げてよい。

## 2. 現在の設定と実績

### competitor-follower-follow
- 環境変数:
        "EnvironmentVariables" => {
          "COMPETITOR_FOLLOW_DAILY_CAP" => "5"
          "PATH" => "/usr/local/bin:/usr/bin:/bin"
        }
- 1 日の発火回数: 2 回
- 直近 3 日の行数:
      2026-08-28  0
0 行
      2026-08-27  18 行
      2026-08-26  18 行
- 直近 3 行:
        @AmeerYounu17486: ❌ low-density bio (空 or テンプレキーワードのみ)
      [2026-08-27T09:33:37.502Z] === end: 0/5 OK ===
      === end: 0/5 OK ===

### hashtag-follow
- 環境変数:
        "EnvironmentVariables" => {
          "HASHTAG_FOLLOW_DAILY_CAP" => "90"
          "PATH" => "/usr/local/bin:/usr/bin:/bin"
        }
- 1 日の発火回数: 2 回
- 直近 3 日の行数:
      2026-08-28  0
0 行
      2026-08-27  15 行
      2026-08-26  14 行
- 直近 3 行:
      picks: 0 authors
      [2026-08-27T08:03:05.353Z] === end: 0/0 OK ===
      === end: 0/0 OK ===

### badge-followback
- 環境変数:
- 1 日の発火回数: 1 回
- 直近 3 日の行数:
      2026-08-28  0
0 行
      2026-08-27  0
0 行
      2026-08-26  2 行
- 直近 3 行:
      [2026-08-26T15:50:26.280Z] followed back @AlinawazTrader
      followed back @AlinawazTrader
      {"ok":true,"scanned":208,"verified":65,"followed_back":1,"handles":["AlinawazTrader"]}


## 3. 引き上げ

- 退避: ai.openclaw.competitor-follower-follow.plist.pre030.20260827-153917
- cap を 5 → 10 に上げた（発火 2 回/日 なので 1 日あたり最大 20 件）
- **再ロード成功**

## 4. 日月の休止は切り替えられるか（今回は触らない）

competitor-follower-follow は日月を skip している。週 2 日 休むと機会が 28% 減る。
**環境変数で切り替えられるかだけ調べる。** スクリプトは書き換えない。
    111:  const todayDow = todayDate.getDay();
    113:    log(`=== competitor-follower SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
    参照している環境変数: process.env.CHROME_CDP_URL process.env.COMPETITOR_FOLLOW_DAILY_CAP process.env.FORCE_RUN 

## 5. 変更後の確認

- 現在の cap: 10
- 稼働: 稼働

次の発火（11:30 / 18:30 JST）のログで、実際に何件フォローしたかを確認すること。
