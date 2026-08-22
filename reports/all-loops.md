# 4 ループの立ち上げ（2026-08-22T13:07:46Z）

## 0. Chrome CDP の実際の待ち受けポートを探す

2026-08-09 に `*.bak18800` が一括作成されている＝**その日にポートを変えた疑い。**
18800 を決め打ちせず、実際に開いているポートを探す。

### スクリプトが持つ既定ポート
 125 18810

### 実際に待ち受けているポート（Chrome 系）
Google 127.0.0.1:18810
Google [::1]:7679

### /json/version に応答するポート
- **18810 → 応答あり**

### chrome-cdp ジョブ
- ai.openclaw.chrome-cdp.plist 更新=08-22 22:07 → 壊れている
- ai.openclaw.chrome-cdp.plist.bak.20260602-keepalive-off 更新=08-22 22:07 → 壊れている
- ai.openclaw.chrome-cdp.plist.bak.20260602-throttle 更新=08-22 22:07 → 壊れている
- launchctl: **未ロード** → 立ち上げる
  - ai.openclaw.chrome-cdp: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.chrome-cdp: **正常なバックアップが無い。当て推量で作らないので飛ばす**

## ① 会話の継続（返信への返信）
  - ai.openclaw.auto-thread-chainifier: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.auto-thread-chainifier: **正常なバックアップが無い。当て推量で作らないので飛ばす**

## ② フォロー返し
  - ai.openclaw.badge-followback: 既にロード済み

## ③ アンフォロー

### unfollow 系の plist をすべて見る
- ai.openclaw.revenge-unfollow 更新=08-22 20:07 → 壊れている / launchctl=なし
- ai.openclaw.unfollow-cleanup-evening 更新=08-22 22:07 → 正常 / launchctl=なし
- ai.openclaw.unfollow-cleanup-morning 更新=08-22 22:07 → 正常 / launchctl=なし
- ai.openclaw.unfollow-daily 更新=08-22 20:07 → 壊れている / launchctl=なし
- ai.openclaw.unfollow-evening 更新=08-22 20:07 → 壊れている / launchctl=なし
- ai.openclaw.unfollow-stats-monitor 更新=08-22 22:07 → 正常 / launchctl=なし

  - ai.openclaw.revenge-unfollow: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.revenge-unfollow: **正常なバックアップが無い。当て推量で作らないので飛ばす**
  - ai.openclaw.unfollow-cleanup-evening: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.unfollow-cleanup-evening: **正常なバックアップが無い。当て推量で作らないので飛ばす**
  - ai.openclaw.unfollow-cleanup-morning: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.unfollow-cleanup-morning: **正常なバックアップが無い。当て推量で作らないので飛ばす**
  - ai.openclaw.unfollow-daily: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.unfollow-daily: **正常なバックアップが無い。当て推量で作らないので飛ばす**
  - ai.openclaw.unfollow-evening: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.unfollow-evening: **正常なバックアップが無い。当て推量で作らないので飛ばす**
  - ai.openclaw.unfollow-stats-monitor: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.unfollow-stats-monitor: **正常なバックアップが無い。当て推量で作らないので飛ばす**

## ④ 能動フォロー
  - ai.openclaw.competitor-follower-follow: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.competitor-follower-follow: **正常なバックアップが無い。当て推量で作らないので飛ばす**
  - ai.openclaw.hashtag-follow: 現行 plist が正常でない（Label/ProgramArguments が読めない）
  - ai.openclaw.hashtag-follow: **正常なバックアップが無い。当て推量で作らないので飛ばす**

## 最終確認（自己申告ではなく launchctl の実体）

ジョブ                                     状態
ai.openclaw.auto-thread-chainifier            **未ロード**
ai.openclaw.badge-followback                  稼働
ai.openclaw.competitor-follower-follow        **未ロード**
ai.openclaw.hashtag-follow                    **未ロード**
ai.openclaw.chrome-cdp                        **未ロード**
ai.openclaw.revenge-unfollow                  **未ロード**
ai.openclaw.unfollow-cleanup-evening          **未ロード**
ai.openclaw.unfollow-cleanup-morning          **未ロード**
ai.openclaw.unfollow-daily                    **未ロード**
ai.openclaw.unfollow-evening                  **未ロード**
ai.openclaw.unfollow-stats-monitor            **未ロード**

## ai.openclaw のジョブ一覧（現在）
ai.openclaw.badge-followback
ai.openclaw.comment-warmup
ai.openclaw.follower-snapshot
ai.openclaw.gateway
ai.openclaw.import-manual-image
ai.openclaw.incoming-reply-watcher
ai.openclaw.node
ai.openclaw.seo-health
ai.openclaw.sitemap-autosubmit
ai.openclaw.slack-watchdog
ai.openclaw.tab-guard
