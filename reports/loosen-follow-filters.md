# フォローのフィルタを緩める（2026-09-05 17:29:07 JST・費用 $0）

> **ジョブは動いていた。フィルタが全部 弾いていた。** 今日フォローできたのは 1 人。
> **バックアップ → 置換 → `node --check` → 失敗なら自動で巻き戻し。**
> **LLM を呼ばない。フォローもしない**（次回の定時実行から効く）。

## 1. バックアップ

- `follow-handle.js.bak-20260905-172907` を作成（220 行）

## 2. 置換（**実物に完全一致するときだけ**）

- ✅ **ランダム判定の数字比率（kankan1014 を通す）**: `if (digits / clean.length >= 0.4) return true;` → `if (digits / clean.length >= 0.6) return true;`
- ✅ **フォロワー数の上限**: `follower_count > 10000) {` → `follower_count > 50000) {`
- ✅ **上限のメッセージ**: `need ${minFollowers}-10000` → `need ${minFollowers}-50000`
- ✅ **ratio のしきい値（2026-05-25 の user 指示を承認のうえ変更）**: `if (ratio < 0.3) {` → `if (ratio < 0.15) {`
- ✅ **bio の最低文字数**: `if (stripped.length < 25) return true;` → `if (stripped.length < 15) return true;`

## 3. 構文チェック

- ✅ `node --check` 通過

## 4. 差分

```diff
--- /Users/ny/.openclaw/workspace/scripts/follow-handle.js.bak-20260905-172907	2026-08-09 17:52:51
+++ /Users/ny/.openclaw/workspace/scripts/follow-handle.js	2026-09-05 17:29:07
@@ -31,7 +31,7 @@
   if (/^\d{6,}$/.test(clean)) return true;
   if (clean.length >= 10) {
     const digits = (clean.match(/\d/g) || []).length;
-    if (digits / clean.length >= 0.4) return true;
+    if (digits / clean.length >= 0.6) return true;
   }
   if (clean.length >= 10 && /[A-Z]/.test(clean) && /[a-z]/.test(clean) && /\d/.test(clean)) {
     const vowels = (clean.match(/[aeiou]/gi) || []).length;
@@ -45,7 +45,7 @@
   if (!bio) return true;
   // URLとhashtagを除いた残り文字数
   const stripped = bio.replace(/https?:\/\/\S+/g, "").replace(/[#＃]\S+/g, "").trim();
-  if (stripped.length < 25) return true;
+  if (stripped.length < 15) return true;
   // 「無言フォロー大歓迎」「相互フォロー」 等のテンプレ的キーワードしか含んでない
   const onlyTemplate = /^[\s　・\-/、。!！?？]*(無言フォロー(大?歓迎|失礼)?|相互フォロー?(歓迎|大歓迎)?|フォロバ(100|歓迎)?|FF外(から)?(失礼|歓迎)?)[\s　・\-/、。!！?？]*$/i.test(stripped);
   if (onlyTemplate) return true;
@@ -71,15 +71,15 @@
 
   // Common: follower count range
   const minFollowers = phase === 1 ? 10 : 100;
-  if (follower_count < minFollowers || follower_count > 10000) {
-    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-10000)`, phase };
+  if (follower_count < minFollowers || follower_count > 50000) {
+    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
   }
 
   // 🚨 2026-05-25 改定 user 指示: 規模問わず ratio<0.3 で skip (フォロワー>>フォロー = 人気アカ、 フォロバ率低)
   // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
   if (follower_count >= 50) {
     const ratio = followingCount / follower_count;
-    if (ratio < 0.3) {
+    if (ratio < 0.15) {
       return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, phase };
     }
   }
```

## 5. plist（日次上限と、日曜・月曜の休み）

### `competitor-follower-follow`
```
Dict {
    COMPETITOR_FOLLOW_DAILY_CAP = 30
    PATH = /usr/local/bin:/usr/bin:/bin
    FORCE_RUN = 1
}
```

### `hashtag-follow`（**上限は触らない**。詰まりは候補の取得数）
```
Dict {
    HASHTAG_FOLLOW_DAILY_CAP = 90
    PATH = /usr/local/bin:/usr/bin:/bin
    FORCE_RUN = 1
}
```

### plist を読み直す

```
ai.openclaw.competitor-follower-follow: 読み直した
ai.openclaw.hashtag-follow: 読み直した
-	0	ai.openclaw.competitor-follower-follow
-	0	ai.openclaw.hashtag-follow
```

## 6. 停止していた badge-followback を戻す

8/28-29 に実際にフォロバを返していた実績がある。**止める理由が無い。**

```
badge-followback: ロードした
-	0	ai.openclaw.badge-followback
```

---

## まとめ

| | 変更前 | 変更後 |
| --- | --- | --- |
| 数字比率（ランダム判定） | >= 0.4 | **>= 0.6** |
| フォロワー上限 | 10,000 | **50,000** |
| ratio | < 0.3 で skip | **< 0.15 で skip** |
| bio 最低文字数 | 25 | **15** |
| competitor 日次上限 | 10 | **30** |
| 日曜・月曜 | **休み** | **稼働**（FORCE_RUN=1） |
| badge-followback | 停止 | **稼働** |

**1 日の上限は残してある。** 巻き戻しは `follow-handle.js.bak-20260905-172907` から。
**LLM を呼んでいない（$0）。フォローもしていない**（次回の定時実行から効く）。
