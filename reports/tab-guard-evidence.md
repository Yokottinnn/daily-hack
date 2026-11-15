# tab-guard が犯人かを確かめる（2026-08-31 01:44:33 JST）

> **再起動ではない**（uptime 20 日）。何かが能動的に落とした。
> `tab-guard.js` が `ai.openclaw.*` を全部なめ、**自分だけ除外**している。
> 生き残ったのがちょうど `ai.openclaw.tab-guard` だけ＝**パターンが一致**。

## 1. どういう条件で落とすのか

```javascript
      let d = "";
      r.on("data", c => d += c);
      r.on("end", () => {
        try {
          const list = JSON.parse(d).filter(t => t.type === "page");
          resolve({ reachable: true, count: list.length });
        } catch { resolve({ reachable: false }); }
      });
    });
    req.on("timeout", () => { req.destroy(); resolve({ reachable: false }); });
    req.on("error", () => resolve({ reachable: false }));
  });
}

// Chrome プロセス自体が生きているか（CDP が重いだけの誤検知を避ける）
function chromeAlive() {
  try {
    execSync(`pgrep -f "remote-debugging-port=${USER_PORT}" >/dev/null 2>&1`, { shell: "/bin/bash" });
    return true;
  } catch { return false; }
}

function haltAutomation(reason) {
  log(`🚨 ${reason} → 自動化を全停止`);
  try { fs.writeFileSync(LOCK, "tab-guard"); } catch {}
  try {
    execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
      { shell: "/bin/bash", timeout: 60000 });
  } catch {}
  try { execSync(`pkill -f 'workspace/scripts/.*\\.js' 2>/dev/null || true`, { shell: "/bin/bash" }); } catch {}
  log("停止完了");
}

async function check() {
  const now = await getTabs(USER_PORT);
  let prev = {};
  try { prev = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch {}

  // A: Chrome プロセスが消えた = ウィンドウ全消滅。これが最も許容できない事象。
  if (!chromeAlive()) {
    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
    return { halted: true, reason: "chrome_process_gone" };
  }

  // CDP が一時的に重いだけなら判定しない（プロセスは生きている）
  if (!now.reachable) return { ok: true, skipped: "CDP 応答なし（プロセスは生存）" };

  const result = { count: now.count, prev: prev.count ?? null };

  // B: 実質全部消えた
  if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {
    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);
    result.halted = true;
  }
  // C: 一度に半分以上が消えた
  else if (prev.count >= 6 && now.count <= prev.count * CATASTROPHIC_RATIO) {
```

## 2. しきい値らしきもの

```javascript
```

## 3. いつ発火したか（ログ）

### `tab-guard.log`（更新: 08-30 23:57）
```
[2026-08-13T15:33:35.868Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-08-13T15:33:35.899Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
[2026-08-13T15:33:36.152Z] 停止完了
[2026-08-13T15:33:36.153Z] 監視終了（要因を確認してください）
[2026-08-13T15:33:46.231Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-08-13T15:33:46.262Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
[2026-08-13T15:33:46.512Z] 停止完了
[2026-08-13T15:33:46.512Z] 監視終了（要因を確認してください）
[2026-08-13T15:33:56.596Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-08-13T15:33:56.625Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
[2026-08-13T15:33:56.873Z] 停止完了
[2026-08-13T15:33:56.874Z] 監視終了（要因を確認してください）
[2026-08-13T15:34:06.961Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-08-13T15:34:06.991Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
[2026-08-13T15:34:07.240Z] 停止完了
[2026-08-13T15:34:07.240Z] 監視終了（要因を確認してください）
[2026-08-13T15:34:17.354Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-08-13T15:34:17.385Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
[2026-08-13T15:34:17.635Z] 停止完了
[2026-08-13T15:34:17.635Z] 監視終了（要因を確認してください）
[2026-08-15T04:43:02.599Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-08-30T14:57:03.141Z] 🚨 Jordan のタブが 19 → 1 枚（一括破壊） → 自動化を全停止
[2026-08-30T14:57:04.531Z] 停止完了
[2026-08-30T14:57:04.534Z] 監視終了（要因を確認してください）
[2026-08-30T14:57:04.586Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
```

（tab-guard のログが見つからない）

## 4. **戻した 3 件は、まだ生きているか**

> 同じ条件が続いていれば、`t012` で戻した 3 件も**また落とされているはず。**

- `ai.openclaw.comment-warmup`: 生きている（ロード=1）
- `ai.openclaw.competitor-follower-follow`: 生きている（ロード=1）
- `ai.openclaw.hashtag-follow`: 生きている（ロード=1）

### いま載っているもの（全体）
```
PID	Status	Label
60098	0	com.dailyhack.ops-poller
-	0	com.dailyhack.rc-keeper
-	0	ai.openclaw.comment-warmup
53365	1	ai.openclaw.tab-guard
-	0	com.dailyhack.openclaw.heartbeat
850	0	com.dailyhack.openclaw.listener
-	0	com.dailyhack.ops-heartbeat
-	0	ai.openclaw.competitor-follower-follow
-	0	com.dailyhack.weekly-blog-report
-	0	ai.openclaw.hashtag-follow
```

## 5. tab-guard 自身の状態

- ロード: **1** 件
```
  "KeepAlive" => true
  "Label" => "ai.openclaw.tab-guard"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/tab-guard.js"
    2 => "--watch"
  "RunAtLoad" => true
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/tab-guard-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/tab-guard.out"
  "WorkingDirectory" => "/Users/ny/.openclaw/workspace"
```

## 6. 判断の材料

**結論は書かない。** 上の 1〜5 から、人が次のどれかを選ぶこと。

- (A) **tab-guard が正しく作動した**（Chrome のタブ過多などの実害があった）
  → 戻すのではなく、**先に発火条件のほうを解消する。**
  無理に戻しても、また落とされるだけで消耗する
- (B) **tab-guard が過剰に反応した**（しきい値が厳しすぎる／誤検知）
  → しきい値を見直してから戻す
- (C) **落とす対象が広すぎる**（返信・フォローまで巻き込む必要は無いのでは）
  → 除外リストに本線を足すことを検討する
- (D) 判断できない → **戻さない。**さらに証拠を集める
