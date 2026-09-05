# アンフォローとフォロバ計測を戻す（2026-09-05 18:56:48 JST・費用 $0）

> 利用者の前提「フォローされなかったらすぐアンフォロー」が**成立していなかった。**
> アンフォロー系は 8 本すべて停止中だった。**ratio を外すならここが要る。**
> **アンフォローは kickstart しない**（一斉に外れるとそれ自体がスパム的）。
> 計測用の `reply-followback-check` だけ即実行する。

## 1. 何をやる設定になっているか（読むだけ）

### `reply-followback-check`
- 時刻指定: Hour = 1 Minute = 15 Hour = 13 Minute = 15
- スクリプト: `reply-followback-check.js`
```javascript
34:  const SEVEN_DAYS_MS = 7 * 86400 * 1000;
35:  const FOURTEEN_DAYS_MS = 14 * 86400 * 1000;
```

### `follow-watchdog`
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t043-restore-unfollow.sh: line 77: File: unbound variable
