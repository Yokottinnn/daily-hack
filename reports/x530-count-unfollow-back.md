# 外し返しを数える（2026-11-21 23:23:09 JST・読むだけ・$0）

## 1. mutual-prune が外した相互のうち、いまフォロワーに居ない人
```
フォロワーの一覧: 797 件（読んだ時刻 2026-11-21T11:24:03.401Z）・フォロー中の一覧: 607 件
外した相互: 145 人 ／ いまフォロワーに居ない: 33 人（22.8%）／ こちらがまたフォローしている: 22 人
11/16 より前に外した: 138 人 → 居ない 31（22.5%）
11/16 から外した: 7 人 → 居ない 2（28.6%）
-- 外してからの日数ごと（外した人 / 居ない人）
  0-1日: 1 / 0（0%）
  2-3日: 0 / 0（-）
  4-7日: 6 / 2（33.3%）
  8-14日: 6 / 1（16.7%）
  15日以上: 132 / 30（22.7%）
-- 外した日ごと（直近 21 日）
  2026-10-23: 1 / 0
  2026-10-25: 2 / 1
  2026-10-26: 3 / 0
  2026-10-27: 1 / 0
  2026-10-28: 8 / 3
  2026-10-29: 2 / 1
  2026-10-30: 5 / 1
  2026-10-31: 1 / 1
  2026-11-01: 1 / 0
  2026-11-02: 2 / 0
  2026-11-03: 1 / 0
  2026-11-04: 1 / 0
  2026-11-05: 4 / 0
  2026-11-06: 3 / 0
  2026-11-07: 3 / 0
  2026-11-08: 1 / 0
  2026-11-10: 1 / 1
  2026-11-11: 1 / 0
  2026-11-16: 3 / 2
  2026-11-17: 3 / 0
  2026-11-20: 1 / 0
-- 外した理由ごと
  休眠 30 日: 4 / 1（25%）
  休眠 41 日: 2 / 0（0%）
  休眠 71 日: 2 / 0（0%）
  休眠 47 日: 2 / 0（0%）
  休眠 31 日: 1 / 0（0%）
  休眠 40 日: 1 / 0（0%）
  休眠 64 日: 1 / 0（0%）
  休眠 93 日: 1 / 0（0%）
```

## 2. 比べるための数: こちらが外していない相互が、自然に外れる割合
```
前回の一覧 2026-11-21T11:24:08.338Z（797 件）→ 今回 2026-11-21T11:24:03.401Z（797 件）: 居なくなった 0 ／ 新しく増えた 0
```

## 3. follow-handle.js の相手のフォロワー数のふるい分け（80〜115 行目）
```
  console.log(JSON.stringify({ ok: false, error: "missing handle arg" }));
  process.exit(1);
}

// --- Filter logic (ported from follow-via-playwright.js + 2026-05-20 強化) ---
function decidePhase(followerCount) {
  if (followerCount < 100) return 1;
  if (followerCount < 300) return 2;
  return 3;
}

function passFilter(profile) {
  const { bio, follower_count, following_count, last_post_age_days } = profile;
  const phase = decidePhase(follower_count);
  const followingCount = following_count || 0;

  // 2026-10-12 x278: 呼び出し側が求めたときだけ、未認証を弾く（青バッジのアカウントに寄せる）
  if (process.env.FOLLOW_REQUIRE_VERIFIED === "1" && profile.verified === false) {
    return { ok: false, reason: "not verified (FOLLOW_REQUIRE_VERIFIED)", phase };
  }
  // Common: follower count range
  const minFollowers = phase === 1 ? 10 : 100;
  if (follower_count < minFollowers || follower_count > 50000) {
    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
  }

  // 🚨 2026-05-25 改定 user 指示: 規模問わず ratio<0.3 で skip (フォロワー>>フォロー = 人気アカ、 フォロバ率低)
  // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
  if (follower_count >= 50) {
    const ratio = followingCount / follower_count;
    if (ratio < Number(process.env.FOLLOW_MIN_RATIO || "0")) {
      return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, phase };
    }
  }

  // 🚨 2026-05-31 #96: refollow blacklist チェック (手動 unfollow 履歴あれば skip)
-- minFollowers を決めている行
101:  const minFollowers = phase === 1 ? 10 : 100;
102:  if (follower_count < minFollowers || follower_count > 50000) {
103:    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
```

**読むだけ。数だけを出した（ハンドルは出していない）。LLM 不使用（$0）。**
