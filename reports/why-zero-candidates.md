# `trend-detect` が 0 件 になる段階を切り分ける

**このレポートが作られた時刻: 2026-09-13 14:55:20 JST**

> `{"ok":true,"count":0,"candidates":[]}`
>
> **`ok:true` で 0 件。** エラーではなく「探したが無かった」と言っている。
> 修理も禁止リストも、**候補が無ければ出番が来ない。**

**測るだけ。直さない。**

## 0. 前提

```
  CDP: 健全
  login ロック: 無い
  trend-detect.js: 在る（251 行）
```

## 1. 何を検索しているのか（**設定の実物**）

```
  --- 検索語・URL の組み立て ---
    10: *   - PER_ITEM_TIMEOUT_MS (default 12s) — hashtag/account 個別 scrape の hard cap
    122:      const social = a.querySelector('[data-testid="socialContext"]')?.textContent || "";
    124:      const ev = a.querySelector('time');
    126:      const text = a.querySelector('[data-testid="tweetText"]')?.innerText || "";
    127:      const link = a.querySelector('a[href*="/status/"]')?.getAttribute("href") || "";
    132:      const likeAria = a.querySelector('[data-testid="like"], [data-testid="unlike"]')?.getAttribute("aria-label") || "";
    133:      const replyAria = a.querySelector('[data-testid="reply"]')?.getAttribute("aria-label") || "";
    134:      const retweetAria = a.querySelector('[data-testid="retweet"], [data-testid="unretweet"]')?.getAttribute("aria-label") || "";
    155:async function scrapeHashtag(page, hashtag) {
    156:  const url = `https://x.com/search?q=${encodeURIComponent("#" + hashtag)}&f=live`;
    158:  return scrapeTimelinePage(page, `hashtag:${hashtag}`);
    179:    if (all.length >= EARLY_EXIT_COUNT) { console.error(`early exit: hashtag loop, all=${all.length}`); break; }
    181:      const items = await withTimeout(scrapeHashtag(page, tag), PER_ITEM_TIMEOUT_MS, `hashtag:${tag}`);
    189:      console.error(`hashtag ${tag} failed:`, e.message);

  --- 読み込んでいる設定ファイル ---
    trend-cache.json

  --- 除外・フィルタの条件 ---
    150:    }).filter(Boolean);
    182:      const filtered = items
    183:        .filter(x => x.like_count >= MIN_LIKES && ageHours(x.posted_at) <= MAX_AGE_HOURS)
    187:      all.push(...filtered);
    196:      const filtered = items
    197:        .filter(x => ageHours(x.posted_at) <= MAX_AGE_HOURS)
    201:      all.push(...filtered);
```

```
  --- 検索語の設定ファイルの中身と更新日 ---
  quick-reply-targets.json   最終更新 -1786789535-16777232 2026-08-15 19:25
    {
      "_note": "15分以内リプ施策の対象。docs/x-growth-play.md の条件（フォロワー2,000-5,000・節約/ポイ活/家計）で 2026-08-15 に実測して選定。",
      "_selected_at": "2026-08-15",
      "targets": [
        {
          "handle": "setuyakusufu",
          "followers_at_selection": 3629,
          "note": "旦那、子供４人と同居★好きなこと：節約・育児・お得・懸賞・無料などなど★３０代前半★みんなで明るい日本に！！！"
        },
        {
      

  --- data/ にある trend / search / keyword 系 ---
    grok-trending-state.json
    trend-cache.json
```

## 2. 走らせて、途中経過を全部 出す（**最大 4 分**）

前回は最後の 1 行しか見ていなかった。**全部 出す。**

```
  --- 出力 全文（先頭 60 行） ---
    {"ok":true,"count":5,"candidates":[{"tweet_url":"https://x.com/38bi___/status/2099004012305793385","text":"おかねください\n #乞食 #PayPay #PayPayください #PayPay乞食","author":"38bi___","like_count":9,"reply_count":2,"retweet_count":0,"posted_at

  --- 出力 末尾 20 行 ---
    {"ok":true,"count":5,"candidates":[{"tweet_url":"https://x.com/38bi___/status/2099004012305793385","text":"おかねください\n #乞食 #PayPay #PayPayください #PayPay乞食","author":"38bi___","like_count":9,"reply_count":2,"retweet_count":0,"posted_at

  --- 件数らしき行だけ ---
    {"ok":true,"count":5,"candidates":[{"tweet_url":"https://x.com/38bi___/status/2099004012305793385","text":"おかねください\n #乞食 #PayPay #PayPayください #PayPay乞食","author":"38bi___","like_count":9,"rep
```

## 3. いつから 0 件 になったのか

**前は候補が取れていた。** x41（02:14）では `from 2 candidates`、
9/09 には `from 15 candidates` だった。**減り方を見る。**

```
  trend-detect         ログ無し
  [comment-warmup] 最終更新 2026-09-13 12:03
    --- 候補の件数が出ている行（直近 20 件） ---
      picked 4 / max 4
      from 9 candidates
      picked 4 / max 4
      from 11 candidates
      picked 4 / max 4
      from 4 candidates
      picked 4 / max 4
      from 21 candidates
      picked 4 / max 4
      from 13 candidates
      picked 4 / max 4
      from 14 candidates
      picked 4 / max 4
      from 10 candidates
      picked 4 / max 4
      from 15 candidates
      picked 4 / max 4
      from 8 candidates
      picked 4 / max 4
      from 11 candidates

```

## 4. 候補プールの実体

```
  comment-state.json             58 件 / 最終更新 2026-07-06 08:00

  --- 直近 1 時間 に更新された data/ のファイル ---
```

## 5. 読み方

| §2 の出力 | 意味 | 直す場所 |
| --- | --- | --- |
| 検索ページを開けているが**ヒット 0** | **検索語が古い／狭い** | 検索語の設定 |
| 検索ページの**DOM が読めない**（scraped 0） | **セレクタが古い** | `trend-detect.js` |
| 生は取れているが**除外で全滅** | **フィルタが厳しすぎる** | NG ルール・cooldown |
| ログインに落ちている | **認証** | 再ログイン |

**どれか 1 つに絞れてから直す。** 推測で緩めない。

## 6. 費用

**LLM を一切 呼ばない。DOM を読むだけ。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

定時の返信ループは **推定** 1 回 $0.003 ／ 1 日 約 $0.19 ／ 1 か月 約 $5.8
（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。**候補が 0 件 の間は実額 $0。**
