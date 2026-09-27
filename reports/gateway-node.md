# gateway と node は何をするジョブか（2026-09-28 00:18 JST・$0）

**このレポートが作られた時刻: 2026-09-28 00:18:33 JST**

> **載せない。消さない。リネームもしない。** 読んで判断材料を出すだけ。

## `gateway`

```
  **載っていない**
  plist: ai.openclaw.gateway.plist（1263 bytes・更新 2026-05-17 18:46）

  --- ProgramArguments ---
    Array {
        /Users/ny/.openclaw/service-env/ai.openclaw.gateway-env-wrapper.sh
        /Users/ny/.openclaw/service-env/ai.openclaw.gateway.env
        /Users/ny/.openclaw/tools/node-v22.22.0/bin/node
        /Users/ny/.openclaw/tools/node-v22.22.0/lib/node_modules/openclaw/dist/index.js
        gateway
        --port
        18789
    }
  --- 起動のしかた ---
    RunAtLoad              true
    KeepAlive              true
  --- EnvironmentVariables ---
    （無い）
```

### 何をするジョブか（スクリプトの冒頭）

```
  ai.openclaw.gateway-env-wrapper.sh（8 行・更新 2026-05-17 18:46）

    #!/bin/sh
    set -eu
    env_file="$1"
    shift
    if [ -f "$env_file" ]; then
      . "$env_file"
    fi
    exec "$@"

  --- LLM を呼ぶか（**載せ直すなら増額になる**）---
    anthropic 0 / claude 0 / openai 0 / sk-ant 0 / API_KEY 0
```

### 最後に動いたのはいつか

```
  **ログが 1 本も無い（一度も動いていない可能性）**
```

### ほかから呼ばれていないか（**消す前に見る**）

```
    fire-watchdog.js
```

## `node`

```
  **載っていない**
  plist: ai.openclaw.node.plist（1226 bytes・更新 2026-05-09 11:42）

  --- ProgramArguments ---
    Array {
        /Users/ny/.openclaw/service-env/ai.openclaw.node-env-wrapper.sh
        /Users/ny/.openclaw/service-env/ai.openclaw.node.env
        /usr/local/bin/node
        /Users/ny/.npm/_npx/87115a8ab6c363bd/node_modules/openclaw/dist/index.js
        node
        run
        --host
        127.0.0.1
        --port
        18789
    }
  --- 起動のしかた ---
    RunAtLoad              true
    KeepAlive              true
  --- EnvironmentVariables ---
    （無い）
```

### 何をするジョブか（スクリプトの冒頭）

```
  ai.openclaw.node-env-wrapper.sh（8 行・更新 2026-05-09 11:42）

    #!/bin/sh
    set -eu
    env_file="$1"
    shift
    if [ -f "$env_file" ]; then
      . "$env_file"
    fi
    exec "$@"

  --- LLM を呼ぶか（**載せ直すなら増額になる**）---
    anthropic 0 / claude 0 / openai 0 / sk-ant 0 / API_KEY 0
```

### 最後に動いたのはいつか

```
  **ログが 1 本も無い（一度も動いていない可能性）**
```

### ほかから呼ばれていないか（**消す前に見る**）

```
    fire-watchdog.js
```

---

## 判断のしかた

| 出方 | どうするか |
| --- | --- |
| plist が無い ／ ログが 1 本も無い | **期待一覧から外す。** 一度も動いていないものを警報の対象にしない |
| ログが在り、最近まで動いていた | **載せ直す。** 止まった理由を追う |
| LLM を呼ぶ | **載せ直しは増額。** 金額を出してから決める（最上位ルール 2-B） |
| ほかから参照されている | **消さない。** 依存が壊れる |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
