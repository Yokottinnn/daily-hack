# ratio フィルタを外して即実行（2026-09-05 18:53:25 JST・費用 $0）

> **緩和は効いている。** 今日のフォローは 1 件 → 5 件、誤判定は消えた。
> **残る最大の障壁が ratio。** 利用者の判断で完全に外す。
> **環境変数で戻せる形にする**（`FOLLOW_MIN_RATIO`）。**定時を待たず kickstart する。**

## 1. バックアップと置換

- `follow-handle.js.bak-20260905-185325` を作成
- ✅ 置換: `if (ratio < 0.15) {` → `if (ratio < Number(process.env.FOLLOW_MIN_RATIO || "0")) {`
- ✅ `node --check` 通過

```diff
--- /Users/ny/.openclaw/workspace/scripts/follow-handle.js.bak-20260905-185325	2026-09-05 17:29:07
+++ /Users/ny/.openclaw/workspace/scripts/follow-handle.js	2026-09-05 18:53:25
@@ -79,7 +79,7 @@
   // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
   if (follower_count >= 50) {
     const ratio = followingCount / follower_count;
-    if (ratio < 0.15) {
+    if (ratio < Number(process.env.FOLLOW_MIN_RATIO || "0")) {
       return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, phase };
     }
   }
```

**既定は 0 なので `ratio < 0` は成立せず、実質 無効。**
戻すときは plist に `FOLLOW_MIN_RATIO=0.15` を足すだけ。**コードは触らない。**

## 2. 即実行（定時を待たない）

```
ai.openclaw.competitor-follower-follow: kickstart した
ai.openclaw.hashtag-follow: kickstart した
```

/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t042-drop-ratio-filter.sh: line 120: [: 0
0: integer expression expected
- 見張った時間: **203 秒**

### competitor

```
（まだ終わっていない）
```

**通ったもの**

```
[2026-09-05T09:54:18.521Z]   @<伏せ>: ✅
  @<伏せ>: ✅
```

**弾いた理由**

```
   2 ❌ refollow blacklist
   2 ❌ off-niche bio
   2 ❌ inactive
   2 ❌ follower count out of range
   2 ❌ follow button click didn't change to unfollow
```

**ratio でまだ弾いていないか**（外したので 0 件のはず）

```
ratio で弾いた件数: 0
```

### hashtag

```
（まだ終わっていない）
```

**通ったもの**

```
（なし）
```

**弾いた理由**

```
   2 ❌ follower count out of range
```

**ratio でまだ弾いていないか**（外したので 0 件のはず）

```
ratio で弾いた件数: 0
```

## 3. 当日のフォロー実績

```
reply-followers.json: 今日 8 件 / 更新 18:54
followed.json: 今日 0 件 / 更新 00:50
```

---

**基準線: 今朝は競合 0/10・ハッシュタグ 1/5 ＝ 合計 1 人。緩和後は 5 件。**
巻き戻しは `follow-handle.js.bak-20260905-185325` から。**投稿していない。LLM も呼んでいない（$0）。**
