# 夜中の外す処理の結果（2026-10-31 09:14:25 JST・読むだけ・$0）

## ① reply-followers-cleanup.log の 2026-10-30T17:00Z 以降
```
行数 169
外した: 0
失敗: 146
打ち切り（timeout・ETIMEDOUT）: 146
--- 起動ごとの行
[2026-10-30T20:41:51.372Z] done
[2026-10-30T21:00:05.091Z] due 675 → 上限 20 件に絞る（残りは次回）
[2026-10-30T21:00:05.095Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,ha
[2026-10-30T21:41:48.181Z] done
[2026-10-30T22:00:04.286Z] due 675 → 上限 20 件に絞る（残りは次回）
[2026-10-30T22:00:04.290Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,ha
[2026-10-30T22:41:45.755Z] done
[2026-10-30T23:00:05.594Z] due 675 → 上限 20 件に絞る（残りは次回）
[2026-10-30T23:00:05.598Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,ha
[2026-10-30T23:41:51.525Z] done
[2026-10-31T00:00:05.084Z] due 675 → 上限 20 件に絞る（残りは次回）
[2026-10-31T00:00:05.086Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,ha
--- 最後の 8 行
[2026-10-31T00:00:05.084Z] due 675 → 上限 20 件に絞る（残りは次回）
[2026-10-31T00:00:05.086Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mon
[2026-10-31T00:02:59.677Z] @<伏せ>: unfollow exec error: spawnSync /bin/sh ETIMEDOUT
[2026-10-31T00:05:02.205Z] @<伏せ>: unfollow exec error: spawnSync /bin/sh ETIMEDOUT
[2026-10-31T00:07:04.742Z] @<伏せ>: unfollow exec error: spawnSync /bin/sh ETIMEDOUT
[2026-10-31T00:09:07.280Z] @<伏せ>: unfollow exec error: spawnSync /bin/sh ETIMEDOUT
[2026-10-31T00:11:09.809Z] @<伏せ>: unfollow exec error: spawnSync /bin/sh ETIMEDOUT
[2026-10-31T00:13:12.340Z] @<伏せ>: unfollow exec error: spawnSync /bin/sh ETIMEDOUT
```

## ② reply-followers.json の unfollowed_at（2026-10-30T17:00Z 以降）
```
外した 0 {} ／ まだ外す予定が残っている 214
```

## ③ 止まったままの node（30 分以上）
```
83453          14:20 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js
85241          01:11 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/unfollow-handle.js Kimama_FIRE
88055    01-04:10:51 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/tab-guard.js --watch
```

## ④ プロフィールのヘッダー
```
{"links":["437 フォロー中","666 フォロワー"]}
```
**読んだだけ（$0）。**
