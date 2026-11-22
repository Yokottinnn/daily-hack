# 止まっていることが 30 分以内に分かるようにする

**このレポートが作られた時刻: 2026-09-12 22:21:19 JST**

> 2026-09-08〜12、`/tmp/x-login-in-progress` が刺さったまま
> **26 本のジョブがエラーを 1 行も出さずに空振りした。気づくまで 2 日。**
> `ensure-chrome.sh` は `exit 0` で返すので、**rc では検知できない。**

## 1. `ops-heartbeat.sh` はどこにあるか

```
  **見つからない。** launchd の plist から辿る:
      "EnvironmentVariables" => {
        "HOME" => "/Users/ny"
        "PATH" => "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      "Label" => "com.dailyhack.ops-heartbeat"
      "ProgramArguments" => [
        0 => "/bin/bash"
        1 => "/Users/ny/projects/anta-baka-x/blog/scripts/ops-heartbeat.sh"
      "RunAtLoad" => true
```

**本体が見つからないので何も変更しない。** 当て推量でファイルを作らない。
