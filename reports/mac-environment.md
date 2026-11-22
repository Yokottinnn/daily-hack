# Mac で使えるもの（実測）

**この一覧は `ops/tasks/x52-mac-environment-inventory.sh` が実測したもの。**
**推測で書かない。** タスクを書く前にここを読む（CLAUDE.md 最上位ルール 14）。

測った時刻: **2026-09-13 11:03:03 JST**

## 0. 素性

```
  OS       : macOS 26.3.1
  arch     : arm64
  shell    : /bin/zsh
  bash     : GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)
  ホーム   : /Users/ny
  ワークスペース: /Users/ny/.openclaw/workspace （在る）
```

## 1. コマンドの有無（**ここで転んだ**）

| コマンド | 状態 | 備考 |
| --- | --- | --- |
| `timeout` | **無い** | **無ければ素の bash で打ち切る** |
| `gtimeout` | **無い** | coreutils を入れていれば在る |
| `gnu-sed / gsed` | **無い** | macOS の `sed -i` は `-i ""` が要る |
| `pkill` | 在る（/usr/bin/pkill） | |
| `pgrep` | 在る（/usr/bin/pgrep） | |
| `plutil` | 在る（/usr/bin/plutil） | plist の検証に使う |
| `PlistBuddy` | 在る（/usr/libexec/PlistBuddy） | |
| `launchctl` | 在る（/bin/launchctl） | |
| `caffeinate` | 在る（/usr/bin/caffeinate） | スリープ抑止。**sudo 不要** |
| `pmset` | 在る（/usr/bin/pmset） | **変更には sudo が要る** |
| `jq` | 在る（/usr/bin/jq） | 無ければ node で JSON を扱う |
| `curl` | 在る（/usr/bin/curl） | |
| `git` | 在る（/usr/bin/git） | |
| `tmux` | 在る（/opt/homebrew/bin/tmux） | |
| `python3` | 在る（/usr/bin/python3） | |
| `perl` | 在る（/usr/bin/perl） | |
| `flock` | **無い** | 無ければ mkdir でロックする |

## 2. node

```
  /usr/local/bin/node          v24.14.0
  /opt/homebrew/bin/node       v26.0.0
  /opt/homebrew/bin/node       v26.0.0

  --- node --check は拡張子を見るか（**ここで転んだ**） ---
    .70904.js    通る
    .70904.js.new **弾く**
```

## 3. ワークスペースの node_modules（**推測しない**）

```
  --- playwright 系 ---
    playwright-core

  --- 主要なもの（先頭 25 件） ---
    agent-base
    base64-js
    bignumber.js
    buffer-equal-constant-time
    call-bind-apply-helpers
    call-bound
    data-uri-to-buffer
    debug
    dunder-proto
    ecdsa-sig-formatter
    es-define-property
    es-errors
    es-object-atoms
    extend
    fetch-blob
    formdata-polyfill
    function-bind
    gaxios
    gcp-metadata
    get-intrinsic
    get-proto
    google-auth-library
    google-logging-utils
    googleapis
    googleapis-common

  合計: 48 件
```

## 4. 稼働中スクリプトが実際に読んでいるパッケージ

**`require` 行を読む。** 2026-09-12 に `playwright` と書いて 4 回 連続で落とした。

```
  post-via-playwright.js     require("playwright-core") require("fs") 
  unfollow-handle.js         require("playwright-core") require("./lib/work-window.js") 
  post-comment.js            require("playwright-core") require("./lib/text-safety") 
  mutual-prune.js            require("playwright-core") require("fs") 
  cdp-health.js              require("net") require("playwright-core") 
  trend-detect.js            require("playwright-core") require("fs") 
  asuka-reply.cjs            require('fs') require('path') 
```

## 5. 日付・ファイル情報の方言（**Linux と違う**）

```
  stat -f '%Sm'  : 2026-09-13 09:43
  stat -c '%y'   : **使えない（macOS はこちら）**
  date -v-1d     : 2026-09-12
  date -d '1 day ago': **使えない（macOS はこちら）**
  TZ=Asia/Tokyo  : 2026-09-13 11:03:03
  grep -P        : **使えない**
  sed -i（引数なし）: **使えない（-i "" が要る）**
```

## 6. PATH（launchd から走るときは最小限になる）

```
  いまの PATH: /opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin

  **plist では明示すること:**
    /usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

## 7. 環境変数の**名前だけ**（値は出さない）

公開リポジトリに載るため、**値は絶対に出さない。**

```
    （秘密らしきもの）SSH_AUTH_SOCK
    ---
    DAILY_HACK_REPO
    HOME
    LOGNAME
    OPS_PUSH
    OPS_REPORT_DIR
    OPS_RUN_TASKS_SELF_UPDATED
    OSLogRateLimit
    PATH
    PWD
    SHELL
    SHLVL
    TMPDIR
    USER
    XPC_FLAGS
    XPC_SERVICE_NAME
    _
```

## 8. ディスクとメモリ

```
  Filesystem        Size    Used   Avail Capacity iused ifree %iused  Mounted on
  /dev/disk3s1s1   460Gi    17Gi    96Gi    15%    455k  1.0G    0%   /
  /dev/disk3s5     460Gi   325Gi    96Gi    78%    3.8M  1.0G    0%   /System/Volumes/Data

  ロードアベレージ:  3.21 2.82 2.63
```

## 使い方

**タスクを書く前にこの一覧を読む。** 載っていないものを使うなら、
タスクの先頭で `command -v` を確かめ、**無ければ代替に切り替えるか、理由を書いて止まる。**

この一覧が古くなったら、`x52` と同じ内容のタスクを番号を変えて置けば取り直せる。
