# 高輪の告知を確かめて、出ていなければ出す（2026-11-10 00:27:42 JST・$0）

## 1. いまのキュー
```
{"status":"awaiting_approval","x_tweet_id":null,"t2":null,"last_result":{"ok":false,"step":"ensure-chrome","error":"Chrome failed to start"}}
```

## 2. 12:00 の予約のログ（末尾）
```
[2026-11-09 12:00:05] start
ensure-chrome: Chrome failed to become CDP-responsive within 45s
{"ok":false,"step":"ensure-chrome","error":"Chrome failed to start"}
[wb] t1=null t2=null ok=false
[2026-11-09 12:01:11] done rc=1
```

## 3. 出す
```
  まだ出ていない → いま出す
  runner rc=0
```

## 4. 出したあとのキュー
```
{"status":"awaiting_approval","x_tweet_id":null,"t2":null,"last_result":{"ok":false,"step":"thread-main-exec","error":"Command failed: /usr/local/bin/node scripts/post-via-playwright.js \"6auY6Lyq44Ky44O844OI44Km44Kn44Kk44Gr44CM5pydN+aZguOBi+OCiemWi+OBhOOBpuOCi+W6l+OAjeOBjOOBguOCi+OBruOAgeefpeOCieOBquOBi+OBo+OBn+OBp+OBl+OCh++8n/CfmI8KCuKYlSBWRVJWRSBDT0ZGRUUgUk9BU1RFUlMg44GoIE1JTVVSRSDjga7jg5njg7zjgqvjg6rjg7zjga83OjAw"}}
[2026-11-09 12:01:11] done rc=1
[2026-11-10 00:27:43] start
[run-publish] thread_chain mode
{"ok":false,"step":"thread-main-exec","error":"Command failed: /usr/local/bin/node scripts/post-via-playwright.js \"6auY6Lyq44Ky44O844OI44Km44Kn44Kk44Gr44CM5pydN+aZguOBi+OCiemWi+OBhOOBpuOCi+W6l+OAjeOBjOOBguOCi+OBruOAgeef
[wb] t1=null t2=null ok=false
[2026-11-10 00:28:19] done rc=0
```
