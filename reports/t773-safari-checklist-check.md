# Safari（WebKit）でチェックリストの崩れを測る（t773・$0）

**このレポートが作られた時刻: 2026-11-22 00:24:14 JST**

- macOS: 26.3.1 / Safari: 26.3.1 / safaridriver: /usr/bin/safaridriver
- WebKit（Playwright）: /Users/ny/Library/Caches/ms-playwright/webkit-2336 

node --check rc=0 
rc=0 / 5 秒

試して使えなかったもの: WebKit が入っていない: browserType.launch: Executable doesn't exist at /Users/ny/Library/Caches/ms-playwright/webkit-2203/pw_run.sh ／ safaridriver が使えない: {"error":"session not created","message":"Could not create a session: You must enable 'Allow remote automation' in the Developer section of Safari Settings to control Safari via WebDriver.","stacktrac

**測れなかった**
