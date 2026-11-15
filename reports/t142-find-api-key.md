# API の鍵はどこから来ているのか（t142）

生成: **2026-09-21T02:08:12+0900**

**値は出さない。** 在処と変数名、値の長さだけ。

## 1) plist の EnvironmentVariables

- `com.bubblesnow.remote.daily-hack-blog.plist` → **ANTHROPIC_API_KEY **
- `com.bubblesnow.remote.daily-hack.plist` → **ANTHROPIC_API_KEY **
- `com.bubblesnow.remote.plist` → **ANTHROPIC_API_KEY **

## 2) 設定ファイル・シェルの初期化

- 該当なし

## 3) X 系のジョブは何を読んでいるか

- `~/.openclaw/workspace/scripts/anthropic-client.js`

## 4) いまのシェルに入っているか

- Anthropic 用: 無い
- Claude 用: 無い
- `launchctl getenv`（Anthropic 用）: **在る**（値は出さない）

## 5) どうつなぐか

- 見つかったファイルを `scripts/refresh-daily.sh` が読むようにする
- 変数名が Claude 用の綴りだった場合は、**そちらも見るように直す**
- **どこにも無ければ、利用者に新しい鍵を置いてもらう**
