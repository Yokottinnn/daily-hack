# `/tmp/x-login-in-progress` を外して Chrome を戻す

**このレポートが作られた時刻: 2026-09-12 21:48:36 JST**

> `x25` が `ensure-chrome.sh` の全文を出して、原因が確定した。
> **`/tmp/x-login-in-progress` があると Chrome を起動せず `exit 0` する。**
> rc=0 なので**呼び出し側からは成功に見える。26 本のジョブが静かに空振りする。**

## 1. 鍵は何時間 放置されているか

```
  **有る**: /tmp/x-login-in-progress
    更新  : 2026-09-12 21:48:35
    経過  : **0 時間**
    大きさ: 9 B
    中身  : tab-guard
```

## 2. 外してよいか判断する

**6 時間 より新しければ触らない。** 本当に手動ログイン中かもしれない。

```
  **0 時間しか経っていない。触らない。**
  手動ログインが進行中の可能性がある。
```

## 3. Chrome を起動する（**自動再ログインが動くはず**）

`ensure-chrome.sh` には `x-login.js` を呼ぶ経路が既にある。

```
  --- ensure-chrome.sh ---
    ensure-chrome: login-mode-guard active, skip launch
    (rc=0)

  --- ensure-chrome.log の末尾（再ログインの記録） ---
    [2026-08-09T23:32:08Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
    [2026-08-09T23:34:15Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
    [2026-08-09T23:37:09Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
    [2026-08-09T23:40:12Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
    [2026-08-09T23:42:28Z] ensure-chrome: CDP hang confirmed but auto-restart is DISABLED (Jordan のウィンドウを守るため)
    [2026-08-09T23:44:48Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
    [2026-08-09T23:47:55Z] ensure-chrome: Chrome failed to become CDP-responsive within 45s
    [2026-08-09T23:53:27Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
    [2026-08-09T23:54:50Z] ensure-chrome: peer repair did not finish within 150s
    [2026-08-09T23:55:56Z] ensure-chrome: Chrome up and CDP responsive
    [2026-08-09T23:55:56Z] ensure-chrome: logged out after restart — running x-login.js
    [2026-08-10T00:49:55Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
    [2026-08-10T00:50:58Z] ensure-chrome: Chrome failed to become CDP-responsive within 45s
    [2026-08-13T15:37:03Z] ensure-chrome: Chrome failed to become CDP-responsive within 45s
    [2026-08-15T04:41:51Z] ensure-chrome: Chrome up and CDP responsive
    [2026-09-07T14:59:29Z] ensure-chrome: Chrome up and CDP responsive
    [2026-09-07T14:59:37Z] ensure-chrome: logged out after restart — running x-login.js
    [2026-09-07T14:59:38Z] ensure-chrome: re-login FAILED — manual login required
    [2026-09-07T15:00:00Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
    [2026-09-07T15:00:13Z] ensure-chrome: Chrome up and CDP responsive
```

## 4. CDP は応答するか

```
  {"ok":false,"healthy":false,"reason":"port_closed","detail":"Chrome not running","port":18810}

  --- Chrome のプロセス ---
```

## 5. X にログインできているか

```
    CDP に繋がらない: browserType.connectOverCDP: Invalid URL
```

## 6. まだログアウトしている場合の材料

```
  --- cookie バックアップ ---
    2026-09-09.db           217088 B  2026-09-09 22:00
    2026-09-08.db           217088 B  2026-09-08 22:00
    2026-09-07.db           217088 B  2026-09-08 00:00
    2026-08-10.db           217088 B  2026-08-10 04:00

  --- 自動再ログインの本体はあるか ---
    有る  x-login.js                                   08-09 17:52
    有る  cookie-restore.sh                            08-09 17:52
    有る  restore-cookies-and-relaunch.sh              08-09 17:52

  --- 再ログインのスロットル状態 ---
```

---

## 判定

| 結果 | 意味 |
| --- | --- |
| ログイン **生きている** | **復旧完了。** 次の定時（12/16/19/22 時）から 3 ループが動く |
| ログイン **切れている** ＋ `re-login OK` のログ | 少し待てば入る。次の発火で確認 |
| ログイン **切れている** ＋ `manual login required` | **PC での再ログインが要る** |
| CDP が繋がらない | 鍵以外の理由。`ensure-chrome.log` を読む |

## 再発防止（**この鍵は消し忘れると全部 止まる**）

`/tmp/x-login-in-progress` があると **26 本のジョブが rc=0 のまま静かに空振りする。**
**エラーが出ないので気づけない。** 今回は 2 日 気づけなかった。
**heartbeat にこの鍵の有無を出すべき。**

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク**（LLM 不使用） | **$0** | **$0** | **$0** |
| フォロー・アンフォロー（DOM 操作） | **$0** | **$0** | **$0** |
| 返信（**実測** 9/8=5 件・9/9=3 件） | $0.003 | $0.009〜0.015 | 約 $0.27〜0.45 |

**投稿・返信・フォロー・アンフォローのいずれもしていない。cookie も消していない。**
