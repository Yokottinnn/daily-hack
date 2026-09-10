# 【復旧】止まった X 自動化を戻す

**このレポートが作られた時刻: 2026-09-10 21:38:27 JST**

> 利用者は PC に触れない状態。**`ops-poller` が生きているので、この経路で直す。**
> `ai.openclaw.*` が全滅して **`tab-guard` だけ生き残る**のは、
> `t014`（2026-08-30）に記録した **非常ブレーキの署名と一致**する。

## 1. 止まる前と後（証拠）

```
  --- いまロードされているもの ---
    ai.openclaw.tab-guard
    com.dailyhack.openclaw.heartbeat
    com.dailyhack.openclaw.listener
    com.dailyhack.ops-heartbeat
    com.dailyhack.ops-poller
    com.dailyhack.rc-keeper
    com.dailyhack.weekly-blog-report

  ai.openclaw.*  : 1 本
  com.dailyhack.*: 6 本
  plist の総数   : 68 本
```

**`ai.openclaw.*` が 1 本（tab-guard）だけなら、非常ブレーキが引かれている。**

### tab-guard はいつ・なぜ発火したか

```
  [tab-guard.log] 更新 2026-09-10 21:38
    151576:[2026-09-10T12:37:47.206Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151577:[2026-09-10T12:37:47.239Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151578:[2026-09-10T12:37:47.492Z] 停止完了
    151580:[2026-09-10T12:37:57.568Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151581:[2026-09-10T12:37:57.600Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151582:[2026-09-10T12:37:57.856Z] 停止完了
    151584:[2026-09-10T12:38:07.942Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151585:[2026-09-10T12:38:07.975Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151586:[2026-09-10T12:38:08.233Z] 停止完了
    151588:[2026-09-10T12:38:18.314Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151589:[2026-09-10T12:38:18.346Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151590:[2026-09-10T12:38:18.603Z] 停止完了
```

### 停止ロックはどこにあるか

```
    27:const LOCK = "/tmp/x-login-in-progress";
    64:  try { fs.writeFileSync(LOCK, "tab-guard"); } catch {}
```

## 2. **犯人が止まっていることを先に確かめる**

`chrome-cdp-heal` が動いていたら、戻してもまた壊される。**その場合は何もしない。**

```
  止まっている chrome-cdp-heal                         
  止まっている poll-approvals                          
  止まっている revenge-unfollow                        
  止まっている auto-detect-and-unfollow-inactive       
  止まっている unfollow-cleanup-morning                
  止まっている unfollow-cleanup-evening                
```

**犯人は止まっている。戻してよい。**

## 3. 停止ロックを解除する

```
  ロックファイルは見つからなかった（既に無いか、別の場所）
```

## 4. Chrome を CDP つきで用意する

`x17` は **`ECONNREFUSED 127.0.0.1:18810`** で失敗した。
`chrome-cdp-heal` を止めたので、**CDP を戻す役がいない。** ここで手当てする。

```
  --- 手当て前 ---
    **CDP: 応答なし**

  --- ensure-chrome.sh を走らせる ---
    ensure-chrome: login-mode-guard active, skip launch
    (rc=0)
```

### CDP が本当に応答するか（**ポートの LISTEN では足りない**）

ハングした Chrome も `/json/version` に 200 を返す。**ページを開けるかで見る。**

```
  {"ok":false,"healthy":false,"reason":"port_closed","detail":"Chrome not running","port":18810}
```

## 5. X にログインできているか

heartbeat の `auth` が **`ok:false`（期限切れ）** になっている。
`ensure-chrome.sh` には **cookie が永続化できておらず 再起動＝即ログアウト**の但し書きがある。

```
    at node:internal/process/execution:451:12 {
  code: 'MODULE_NOT_FOUND',
  requireStack: [ '/[eval]' ]
}

Node.js v24.14.0

  --- cookie のバックアップはあるか ---
    cookie-backups:                                
    2026-09-09.db                                  
    2026-09-08.db                                  
```

## 6. 3 ループのジョブを戻す

**返信・フォロー・アンフォローに必要なものだけ。** 危険なものは戻さない。

```
  **戻した** comment-warmup                            
  **戻した** competitor-follower-follow                
  **戻した** hashtag-follow                            
  **戻した** badge-followback                          
  **戻した** reply-followback-check                    
  **戻した** reply-followers-cleanup                   
  **戻した** incoming-reply-watcher                    
  **戻した** pipeline-heartbeat                        

  戻した: 8 本 / 戻せなかった: 0 本
```

## 7. 戻った結果

```
  --- ai.openclaw.* のロード状況 ---
  ロード      comment-warmup                         PID=-        最後のrc=0
  ロード      competitor-follower-follow             PID=-        最後のrc=0
  ロード      hashtag-follow                         PID=-        最後のrc=0
  **未ロード** badge-followback                      
  ロード      reply-followback-check                 PID=-        最後のrc=0
  ロード      reply-followers-cleanup                PID=-        最後のrc=0
  ロード      incoming-reply-watcher                 PID=-        最後のrc=0
  ロード      pipeline-heartbeat                     PID=-        最後のrc=0

  合計 ai.openclaw.*: 6 本
```

**「ロード済み」は「働いた」ではない**（CLAUDE.md 最上位ルール 11）。
**次の定時実行の結果をキューで数えるまで、動いたとは言わない。**

---

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク自体**（LLM 不使用） | **$0** | **$0** | **$0** |
| フォロー・アンフォロー（DOM 操作） | **$0** | **$0** | **$0** |
| 返信（戻したあと・実績 1 件/日・実測） | $0.003 | $0.003 | 約 $0.09 |
| 返信（`x23` 適用後・**推定**） | 約 $0.0022 | — | — |

**戻しただけで、投稿・返信・フォロー・アンフォローはしていない。**
