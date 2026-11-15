# 能動フォローの復旧（2026-08-22T12:07:31Z）

## 1. LLM を使っているか（ロードの唯一の条件）

### competitor-follower-follow.js
- 行数: 168
- SDK import: なし
- LLM CLI 起動: なし
- env 全部（キー名のみ）: process.env.CHROME_CDP_URL process.env.COMPETITOR_FOLLOW_DAILY_CAP process.env.FORCE_RUN 

### hashtag-follow.js
- 行数: 174
- SDK import: なし
- LLM CLI 起動: なし
- env 全部（キー名のみ）: process.env.FORCE_RUN process.env.HASHTAG_FOLLOW_DAILY_CAP 

**判定: LLM 呼び出し無し → 追加の API 費用は 1回 $0 / 1日 $0 / 1か月 $0。ロードしてよい。**

## 2. plist の中身（013 で StartInterval も Calendar も「無し」と出たので全キーを見る）

### ai.openclaw.competitor-follower-follow
{
  "<MASKED>" => "5"
  "PATH" => "/usr/local/bin:/usr/bin:/bin"
}

### ai.openclaw.hashtag-follow
{
  "<MASKED>" => "90"
  "PATH" => "/usr/local/bin:/usr/bin:/bin"
}

## 3. Chrome CDP の状態（ロードの条件にはしない。事実として記録するだけ）
→ **応答なし。** ジョブは載せる（載せておけば CDP 復活と同時に動く）。
   CDP 側の復旧は別途必要。

### chrome-cdp ジョブのロード状態
94216	0	application.com.google.chrome.for.testing.205381715.205381718.<MASKED>
436	0	application.com.google.Chrome.47492714.202750343

## 4. ロード
Bootstrap failed: 5: Input/output error
Try re-running the command as root for richer errors.
- ai.openclaw.competitor-follower-follow: **ロード失敗**
Bad request.
Could not find service "ai.openclaw.<MASKED>" in domain for user gui: 501
Bootstrap failed: 5: Input/output error
Try re-running the command as root for richer errors.
- ai.openclaw.hashtag-follow: **ロード失敗**
Bad request.
Could not find service "ai.openclaw.hashtag-follow" in domain for user gui: 501

## 5. 結果（follow 系すべて）
-	-9	com.apple.followupd
-	0	ai.openclaw.follower-snapshot
-	0	com.apple.FollowUpUI
-	0	ai.openclaw.badge-followback
