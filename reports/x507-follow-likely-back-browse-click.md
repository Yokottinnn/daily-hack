# 返ってきやすい相手に絞る・眺める・押し方をばらす（2026-11-15 23:42:43 JST・$0）

## ① FOLLOW_MIN_RATIO=0.7

### competitor-follower-follow
```
変える前: 未設定
載っている ←  FOLLOW_MIN_RATIO => 0.7
```

### hashtag-follow
```
変える前: 未設定
載っている ←  FOLLOW_MIN_RATIO => 0.7
```

## ② ③ follow-handle.js
```
入れた
node --check 通った（324 行）
235:async function _humanClick(page, el) {
249:async function _browseHomeIfSessionStart(page) {
269:    await _browseHomeIfSessionStart(page);
302:          if (await _lk.count()) { await _lk.first().scrollIntoViewIfNeeded(); await page.waitForTimeout(_
308:    await _humanClick(page, btn);
```

**LLM 不使用（$0）。**
