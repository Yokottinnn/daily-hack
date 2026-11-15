# 相互でも「休眠・格下」なら そっと外すジョブを常駐化

**このレポートが作られた時刻: 2026-09-13 10:48:53 JST**

> フォロワー数をどんどん増やしていきたいので、お互いにフォローしている場合でも、
> 相手のアカウントがあまり活動していない場合とか、自分のアカウントと比べた時に
> 大したことない場合にはそっとアンフォローするジョブを常駐化してほしい。

**このタスクの実行は DRY_RUN。1 件も外さない。** 誰をどの理由で外すかだけ出す。
常駐ジョブは載せるが **`RunAtLoad` は false**。最初の自動実行は 12 時間後。

## 0. 前提

```
  CDP: 健全
  login ロック: 無い
  playwright-core: 在る
  既存の同種ジョブ:
    auto-detect-and-unfollow-inactive: plist はあるが未ロード
    reply-followers-cleanup: plist はあるが未ロード
    revenge-unfollow: plist はあるが未ロード
```

## 1. `mutual-prune.js` を置く

**x17 で実際に動いたコードをそのまま使う。** `playwright-core` ／ `connectOverCDP` ／
`data-testid` の `*-unfollow` を押して確認ダイアログを確定する流れは書き直さない。

```
  node --check: OK（283 行）
  既存を退避: mutual-prune.js.bak-20260913-104853
  置いた: /Users/ny/.openclaw/workspace/scripts/mutual-prune.js
```

## 2. 判定条件（**既定値は安全側**）

### 外す（どちらか 1 つでも満たせば候補）

| 条件 | 既定 | 意味 |
| --- | --- | --- |
| ① 休眠 | `INACTIVE_DAYS=30` | 最終投稿が 30 日 より前 |
| ② 格下 | `RATIO=0.20` **かつ** `ABS_MIN=300` | 自分の 20% 未満 **かつ** 300 未満 |

**② に「かつ」を入れているのが肝。** 比率だけだと、自分が伸びるほど基準が上がって
優良アカウントまで切ってしまう。**絶対値でも歯止めをかける。**

### 外さない（1 つでも当たれば見送る）

- ホワイトリストに居る（`data/mutual-prune-whitelist.json` / `data/unfollow-whitelist.json`）
- フォローしてから **14 日 未満**（`GRACE_DAYS`）＝ 様子見の期間
- **認証済み（青バッジ）**
- **フォロワー数が読めない** ／ **最終投稿が読めない**
  （**読めない ＝ 悪い、ではない。** 読めないものを 0 とみなすと全員 格下になる）

### 安全弁

- 1 回に外すのは **8 件**まで（`MAX_UNFOLLOW`）。12 時間ごとなので **1 日 最大 16 件**
- `/following` が **0 件**で読めたら何もしない（ページが壊れている合図）
- **ログインが切れていたら何もしない**

## 3. launchd に載せる（12 時間ごと・`RunAtLoad` は false）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>ai.openclaw.mutual-prune</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>/Users/ny/.openclaw/workspace/scripts/mutual-prune.js</string>
  </array>
  <key>StartInterval</key><integer>43200</integer>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>/Users/ny/.openclaw/workspace/logs/mutual-prune.out</string>
  <key>StandardErrorPath</key><string>/Users/ny/.openclaw/workspace/logs/mutual-prune.err</string>
  <key>WorkingDirectory</key><string>/Users/ny/.openclaw/workspace</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>/Users/ny</string>
    <key>OPS_WS</key><string>/Users/ny/.openclaw/workspace</string>
    <key>CDP_URL</key><string>http://127.0.0.1:18810</string>
    <key>MAX_UNFOLLOW</key><string>8</string>
    <key>INACTIVE_DAYS</key><string>30</string>
    <key>RATIO</key><string>0.20</string>
    <key>ABS_MIN</key><string>300</string>
    <key>GRACE_DAYS</key><string>14</string>
  </dict>
</dict>
</plist>
```

```
  plutil -lint: OK
  **載った（`launchctl list` に出た）** ← 最上位ルール 13: rc は見ない
```

## 4. **DRY_RUN で 1 回 走らせる（1 件も外さない）**

誰をどの理由で外すかだけ出す。**ここを見てから、しきい値を決める。**

```
