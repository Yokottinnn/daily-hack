# `follow-handle.js` の戻り値 ＋ source 別のフォロー返し率

**このレポートが作られた時刻: 2026-09-13 19:54:19 JST**

> x62 で場所が割れた。**フィルタは `follow-handle.js` の中。**
> 呼び出し側は `followed_at` しか書いていない。
>
> **戻り値に数字が入っているなら、呼び出し側に 1 行 足すだけで済む。**

**測るだけ。直さない。**

## 1. `follow-handle.js` は数字を返しているか

```
  220 行 / 最終更新 2026-09-05 18:53

  --- フォロワー数を取っている行 ---
    61:function decidePhase(followerCount) {
    62:  if (followerCount < 100) return 1;
    63:  if (followerCount < 300) return 2;
    68:  const { bio, follower_count, following_count, last_post_age_days } = profile;
    69:  const phase = decidePhase(follower_count);
    70:  const followingCount = following_count || 0;
    72:  // Common: follower count range
    73:  const minFollowers = phase === 1 ? 10 : 100;
    74:  if (follower_count < minFollowers || follower_count > 50000) {
    75:    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
    78:  // 🚨 2026-05-25 改定 user 指示: 規模問わず ratio<0.3 で skip (フォロワー>>フォロー = 人気アカ、 フォロバ率低)
    79:  // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
    80:  if (follower_count >= 50) {
    81:    const ratio = followingCount / follower_count;
    82:    if (ratio < Number(process.env.FOLLOW_MIN_RATIO || "0")) {
    83:      return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, phase };
    115:    const bioMatch = /フォロバ|フォローバック|フォロー返し|フォロー返却|フォロー返します|リフォロー|相互(フォロー)?|ふぉろば|フォロー(歓迎|welco
    117:      (followingCount >= follower_count * 0.8 && followingCount <= follower_count * 1.5) ||
    118:      (followingCount > follower_count && followingCount < 1000)
    122:    if (!bioMatch && !ratioMatch) return { ok: false, reason: `Phase 1: no mutual-intent keyword & ratio mismatch (fw=${followingCount}/fr=${follower_count})`, phase };
    129:  // Phase 3: just rely on common filters (already passed range + influencer + activity)
    138:    let followerCount = 0;

  --- 戻り値（return / ok: の形） ---
    56:  console.log(JSON.stringify({ ok: false, error: "missing handle arg" }));
    75:    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
    83:      return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, phase };
    89:    return { ok: false, reason: "refollow blacklist (manually unfollowed in past)", phase };
    94:    return { ok: false, reason: `random-looking handle (likely throwaway/spam): ${handle}`, phase };
    99:    return { ok: false, reason: `off-niche bio (ダイエット/オタ活/ペット等)`, phase };
    104:    return { ok: false, reason: `low-density bio (空 or テンプレキーワードのみ)`, phase };
    109:    return { ok: false, reason: `inactive (last post ${last_post_age_days}d ago)`, phase };
    121:    if (spamMatch) return { ok: false, reason: "Phase 1: spam pattern in bio", phase };
    122:    if (!bioMatch && !ratioMatch) return { ok: false, reason: `Phase 1: no mutual-intent keyword & ratio mismatch (fw=${followingCount}/fr=${follower_count})`, phase };
    126:      return { ok: false, reason: "Phase 2: no relevant topic in bio", phase };
    130:  return { ok: true, phase };
    164:    return {
    185:      console.log(JSON.stringify({ ok: true, status: "already_following", profile }));
    189:      console.log(JSON.stringify({ ok: false, status: "cannot_follow", reason: "no follow button (private/blocked/deleted)", profile }));
    197:        console.log(JSON.stringify({ ok: false, status: "filtered", reason: f.reason, phase: f.phase, profile }));
    208:      console.log(JSON.stringify({ ok: true, status: "followed", profile }));
    210:      console.log(JSON.stringify({ ok: false, status: "click_failed", reason: "follow button click didn't change to unfollow", profile }));
    213:    console.log(JSON.stringify({ ok: false, status: "error", reason: e.message }));

  --- しきい値の実物 ---
    62:  if (followerCount < 100) return 1;
    63:  if (followerCount < 300) return 2;
    73:  const minFollowers = phase === 1 ? 10 : 100;
    74:  if (follower_count < minFollowers || follower_count > 50000) {
    75:    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
    79:  // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
    80:  if (follower_count >= 50) {
    118:      (followingCount > follower_count && followingCount < 1000)
    142:      if (/万/.test(txt)) followerCount = Math.round(parseFloat(txt.replace(/万/g, "")) * 10000);
    143:      else if (/k/i.test(txt)) followerCount = Math.round(parseFloat(txt.replace(/k/i, "")) * 1000);
    144:      else followerCount = parseInt(txt, 10) || 0;
```

**戻り値に数字が在れば → 呼び出し側に 1 行。**
**無ければ → `follow-handle.js` 側で返すところから直す。** 次のタスクで分岐する。

## 2. 呼び出し側が state に書いているところ（**実物の前後**）

```javascript
// ══ competitor-follower-follow.js
 140|   const results = [];
 141|   for (const h of targets) {
 142|     try {
 143|       const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${h}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2*1024*1024 });
 144|       const r = JSON.parse(out.trim().split("\n").pop());
 145|       results.push({ handle: h, ok: r.ok, info: r });
 146|       log(`  @${h}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
 147|       if (r.ok) {
 148|         try {
 149|           const rf = fs.existsSync(REPLY_FOLLOWERS_PATH) ? JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8")) : {};
 150|           rf[h] = {
 151|             followed_at: new Date().toISOString(),
 152|             followback_status: "pending",
 153|             source: `competitor-follower:${competitor}`,
 154|           };
 155|           fs.writeFileSync(REPLY_FOLLOWERS_PATH, JSON.stringify(rf, null, 2));
 156|         } catch (e) { log(`    rf-write err: ${e.message}`); }
 157|       }
 158|     } catch (e) {
 159|       results.push({ handle: h, ok: false, error: e.message.slice(0, 200) });
 160|       log(`  @${h}: ❌ exec err`);
 161|     }
 162|     await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
 163|   }
 164| 
 165|   const ok = results.filter(r => r.ok).length;
 166|   await slackPost(`<@${OWNER_USER_ID}> 🌐 Tier B competitor-follower 完了: @${competitor} の follower から ${ok}/${results.length} follow OK (scraped=${scrapedHandles.
 167|   log(`=== end: ${ok}/${results.length} OK ===`);
 168| })();

// ══ hashtag-follow.js
 140| 
 141|   // 4. follow 実行
 142|   const results = [];
 143|   for (const p of picks) {
 144|     try {
 145|       const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2 * 1024 * 1024 });
 146|       const r = JSON.parse(out.trim().split("\n").pop());
 147|       results.push({ author: p.author, ok: r.ok, info: r });
 148|       log(`  @${p.author}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
 149| 
 150|       // 5. record in reply-followers.json (live-check safety net for future unfollow)
 151|       if (r.ok) {
 152|         try {
 153|           const rf = fs.existsSync(REPLY_FOLLOWERS_PATH) ? JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8")) : {};
 154|           rf[p.author] = {
 155|             followed_at: new Date().toISOString(),
 156|             followback_status: "pending",
 157|             source: "hashtag-follow",
 158|             seed_post_url: p.tweet_url || null,
 159|             seed_engagement: { likes: p.like_count, replies: p.reply_count, retweets: p.retweet_count },
 160|           };
 161|           fs.writeFileSync(REPLY_FOLLOWERS_PATH, JSON.stringify(rf, null, 2));
 162|         } catch (e) { log(`    rf-write err: ${e.message}`); }
 163|       }
 164|     } catch (e) {
 165|       results.push({ author: p.author, ok: false, error: e.message.slice(0, 200) });
 166|       log(`  @${p.author}: ❌ exec err: ${e.message.slice(0, 150)}`);
 167|     }
 168|     await new Promise(r => setTimeout(r, FOLLOW_GAP_MS));
 169|   }
 170| 

```

## 3. source 別のフォロー返し率（**全体 16.2%**（56 / 346）を割る）

```
    供給元                         件数   返し   返し率   いま中
    competitor-follower          168     20    11.9%      29
    comment-orchestrator         135     29    21.5%      23
    hashtag-follow                39      6    15.4%       6
    incoming-reply-watcher         4      1    25.0%       1

    合計: 346 件 / 返し 56 件 / 16.2% / いまフォロー中 59 件

    --- 供給元ごとの期間（いつ集めたか） ---
    competitor-follower        2026-05-19 〜 2026-09-13
    comment-orchestrator       2026-05-13 〜 2026-09-13
    hashtag-follow             2026-05-19 〜 2026-09-13
    incoming-reply-watcher     2026-05-23 〜 2026-08-27
```

**件数の少ない供給元の率は当てにならない。** 20 件 未満は参考値として扱う。
**期間も見る。** 最近フォローした分は、まだ返ってきていないだけのことがある。

## 4. 費用

**読むだけ。LLM を呼ばない。ブラウザを触らない。フォローもアンフォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

参考（**推定**・前提: Haiku 4.5・生成 64 回/日）: 定時の返信ループは
1 回 $0.003 ／ 1 日 約 $0.19 ／ 1 か月 約 $5.8。
**今日の実測の通過率は 56%**（picked 16 / enqueue 9）なので、
捨てる生成が減った分だけ 1 件あたりの単価は下がっている。
